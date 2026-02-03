# MCP Server Improvements Plan

## Issues Identified

### 1. Crash on MCP Server Connection Failure
**Problem**: When enabling an MCP server that fails to connect, the app crashes or doesn't handle errors gracefully.

**Root Causes**:
- `startServer()` throws errors but some call sites don't handle them properly
- Errors during connection/initialization can leave the app in an inconsistent state
- UI doesn't show error feedback to the user
- **State inconsistency**: If error occurs after adding to `serverProcesses` but before updating `enabledServers`, state is inconsistent
- **Force unwraps**: Lines 771, 774 have force unwraps that can crash if encoding fails
- **No cleanup on MainActor block errors**: If error occurs in MainActor block (lines 211-225), resources aren't cleaned up

**Current Error Points** (from error logs):
- "Invalid request parameters" - MCP protocol initialization failures
- "Tool 'X' not found or server not running" - Tools called but server connection lost/failed
- Command path resolution failure
- Process creation failure
- MCP protocol initialization failure
- Tool discovery failure

**Error Log Patterns Found**:
- Multiple "Invalid request parameters" errors for Huntress server
- "Tool 'list_time_entries<|channel|>commentary' not found" - suggests server disconnected or never connected properly
- Pattern: Tools being called but server connection lost/failed

**Additional Crash Points Identified**:
- **Line 771**: `String(data: data, encoding: .utf8)!` - Force unwrap can crash if encoding fails
- **Line 774**: `jsonString.data(using: .utf8)!` - Force unwrap can crash if encoding fails
- **State inconsistency**: If error occurs between adding to `serverProcesses` (line 213) and `enabledServers` (line 214), state is inconsistent
- **Tool cleanup**: If tools are added to `availableTools` but server fails, tools remain in list
- **Connection cleanup**: If `connection.start()` succeeds but `initialize()` fails, process might not be stopped

### 2. LLM Only Recognizing OpenProject Tools
**Problem**: When asked "what can you do", the LLM only mentions OpenProject capabilities, not recognizing it can use multiple different tools from different MCP servers.

**Root Causes**:
- No system prompt explaining available tools
- No guidance about using different tools from different servers
- LLM doesn't understand it can switch contexts between different tool sets
- Tool descriptions might be too specific to one domain

## Solutions

### 1. Graceful MCP Server Error Handling

#### A. Update `startServer()` Error Handling
- **Wrap entire function in proper error handling**
- **Clean up resources on ANY failure**:
  - Remove from `serverProcesses` if added
  - Remove from `enabledServers` if added
  - Remove tools from `availableTools` if added
  - Stop connection process
- **Fix force unwraps** (lines 771, 774):
  - Replace `String(data: data, encoding: .utf8)!` with safe unwrapping
  - Replace `jsonString.data(using: .utf8)!` with safe unwrapping
- **Ensure MainActor block is atomic**:
  - Wrap entire MainActor block in do-catch
  - Clean up on any error in MainActor block
- Return detailed error information
- Log errors appropriately with context

#### B. Update All Call Sites
- Ensure all `startServer()` calls are wrapped in proper error handling
- Show user-friendly error messages in UI
- Update UI state (remove from enabled set if failed)
- Don't crash the app on connection failure

#### C. Add Error State Tracking
- Track which servers failed to start
- Show error indicators in UI
- Allow retry functionality
- Track server connection health
- Detect when servers disconnect unexpectedly

#### D. Handle Tool Call Failures Gracefully
- When tool is called but server not running, provide clear error
- Remove tools from available list if server disconnects
- Detect server disconnection and update state
- Prevent tool calls to disconnected servers
- **Add disconnection detection**: When `readResponses()` detects process stopped (line 857), notify manager to clean up
- **Add connection health check**: Periodically check if processes are still running
- **Cleanup on process death**: When process dies unexpectedly, remove from `serverProcesses`, `enabledServers`, and `availableTools`

#### Implementation:
```swift
func startServer(_ server: MCPServer) async throws {
    var connection: MCPServerConnection?
    var toolsAdded: [MCPTool] = []
    
    do {
        // ... existing connection logic ...
        connection = try MCPServerConnection(...)
        try connection.start()
        try await connection.initialize()
        let tools = try await connection.listTools()
        
        // Atomic state update with cleanup on error
        await MainActor.run {
            do {
                self.serverProcesses[server.id] = connection
                self.enabledServers.insert(server.id)
                
                for tool in tools {
                    var prefixedTool = tool
                    prefixedTool.serverId = server.id
                    prefixedTool.serverName = server.name
                    self.availableTools.append(prefixedTool)
                    toolsAdded.append(prefixedTool)
                }
            } catch {
                // Cleanup if MainActor block fails
                self.serverProcesses.removeValue(forKey: server.id)
                self.enabledServers.remove(server.id)
                for tool in toolsAdded {
                    self.availableTools.removeAll { $0.id == tool.id }
                }
                throw error
            }
        }
    } catch {
        // Cleanup on any error
        connection?.stop()
        await MainActor.run {
            self.serverProcesses.removeValue(forKey: server.id)
            self.enabledServers.remove(server.id)
            for tool in toolsAdded {
                self.availableTools.removeAll { $0.id == tool.id }
            }
        }
        throw error
    }
}

// Fix force unwraps:
// OLD: var jsonString = String(data: data, encoding: .utf8)!
// NEW:
guard let jsonString = String(data: data, encoding: .utf8) else {
    throw NSError(domain: "MCPServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode JSON string"])
}

// OLD: stdinPipe.fileHandleForWriting.write(jsonString.data(using: .utf8)!)
// NEW:
guard let jsonData = jsonString.data(using: .utf8) else {
    throw NSError(domain: "MCPServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode JSON data"])
}
stdinPipe.fileHandleForWriting.write(jsonData)

// At call sites:
do {
    try await container.mcpManager.startServer(server)
} catch {
    // Show user-friendly error message
    // Update UI state (remove from enabled if failed)
    // Log error with full context
}
```

### 2. Enhanced System Prompt for Tool Awareness

#### A. Generate Dynamic System Prompt
- Build system prompt that lists all available tools
- Group tools by MCP server/category
- Explain that LLM can use tools from different servers
- Provide general capability overview

#### B. Tool Description Enhancement
- Ensure tool descriptions are clear and general
- Add context about when to use each tool
- Explain tool relationships

#### C. Context Switching Guidance
- Instruct LLM that it can use tools from different servers
- Explain that tools can be used together
- Guide on selecting appropriate tools for tasks

#### Implementation:
```swift
private func generateSystemPrompt(tools: [[String: Any]], mcpManager: MCPServerManager?) -> String {
    var prompt = """
    You are a helpful AI assistant with access to various tools and capabilities.
    
    You have access to the following tools from different sources:
    """
    
    // Group tools by server
    if let mcpManager = mcpManager {
        let toolsByServer = Dictionary(grouping: mcpManager.availableTools) { $0.serverName ?? "Unknown" }
        
        for (serverName, serverTools) in toolsByServer {
            prompt += "\n\n**\(serverName) Tools:**\n"
            for tool in serverTools {
                prompt += "- \(tool.name): \(tool.description)\n"
            }
        }
    }
    
    prompt += """
    
    **Important Guidelines:**
    - You can use tools from any of the available sources
    - Different tools may come from different MCP servers
    - Use the most appropriate tool for each task
    - You can chain multiple tool calls together to complete complex tasks
    - If a tool fails, try alternative approaches or explain the limitation
    
    When describing your capabilities, mention that you can help with various tasks using the available tools, not just one specific domain.
    """
    
    return prompt
}
```

#### D. Update LLMConfiguration
- Pass system prompt when tools are available
- Generate prompt dynamically based on available tools
- Update prompt when tools change

## Implementation Steps

### Phase 1: Error Handling & Crash Prevention
1. ✅ Fix force unwraps (lines 771, 774) - replace with safe unwrapping
2. ✅ Add comprehensive error handling to `startServer()` with proper cleanup
3. ✅ Track tools added during startup for cleanup on failure
4. ✅ Add disconnection detection callback in MCPServerConnection
5. ✅ Clean up state when server process dies unexpectedly
6. ✅ Update all call sites to handle errors gracefully with user feedback
7. ✅ Add error state tracking
8. ✅ Update UI to show error states
9. ✅ Add retry functionality

### Phase 2: System Prompt Enhancement
1. ✅ Create `generateSystemPrompt()` function
2. ✅ Group tools by server/category
3. ✅ Add tool awareness instructions
4. ✅ Update `streamMessageWithTools()` to use generated prompt
5. ✅ Test with multiple MCP servers

### Phase 3: Testing
1. ✅ Test with failing MCP server connections
2. ✅ Test with multiple MCP servers enabled
3. ✅ Test "what can you do" query
4. ✅ Verify LLM recognizes all available tools

## Benefits

- **Robustness**: App won't crash on MCP connection failures
- **User Experience**: Clear error messages and retry options
- **Tool Awareness**: LLM understands all available capabilities
- **Flexibility**: LLM can use tools from different servers appropriately
- **Better Responses**: More accurate capability descriptions
