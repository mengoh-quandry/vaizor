# Sequential Tool Calling Implementation Plan

## Overview
Implement intelligent sequential tool calling where the LLM can:
1. Assess which tools are needed to complete a task
2. Execute multiple tool calls sequentially
3. Know when to stop (success, failure, or max iterations)
4. Report issues back to the user instead of spinning endlessly
5. Show real-time thinking status updates

## Architecture

### 1. Core Loop Structure
```
while (not complete && not stopped) {
  1. Check if LLM wants to make tool calls
  2. If yes:
     - Update thinking status: "Using [tool_name] to [action]"
     - Execute tool call(s)
     - Collect results
     - Add results to conversation history
     - Continue loop
  3. If no:
     - Stream final response
     - Exit loop
  4. Check stopping conditions
}
```

### 2. Stopping Conditions

#### Success Conditions:
- LLM returns a final response without tool calls
- Task is explicitly marked as complete

#### Failure Conditions (stop and report):
- **Max Iterations**: Reached maximum tool call iterations (default: 10)
- **Consecutive Errors**: 3 consecutive tool call errors
- **LLM Explicit Stop**: LLM explicitly says it cannot complete the task
- **Timeout**: Total operation exceeds time limit (e.g., 2 minutes)
- **Invalid Tool**: Tool doesn't exist or is unavailable

#### Error Recovery:
- Single tool call error: Continue, let LLM decide next step
- Multiple errors: Stop and report to user

### 3. Thinking Status Updates (Intelligent Sentence Generation)

#### Status Flow:
1. **Initial**: "Analyzing request..."
2. **Tool Selection**: "Selecting appropriate tools..."
3. **Tool Execution**: Generate intelligible sentence via async LLM call
   - Example: "Looking up user information in the database"
   - Example: "Searching the web for current weather data"
   - Example: "Reading configuration file to understand system settings"
4. **Processing Results**: "Processing tool results..."
5. **Final Response**: "Formulating response..."

#### Implementation:
- Add `onThinkingStatusUpdate: (String) -> Void` callback to `streamMessage`
- When tool calls are detected:
  1. Extract tool name and arguments
  2. Make quick async LLM call to generate intelligible status sentence
  3. Display generated status for duration of tool execution
  4. Update status when tool completes or next step begins

#### Status Generation Prompt:
```
Given this tool call:
Tool: [tool_name]
Arguments: [arguments]

Generate a single, clear, natural sentence (max 10 words) describing what this action is doing from the user's perspective. 
Examples:
- "Looking up user information in the database"
- "Searching the web for current weather data"
- "Reading configuration file to understand system settings"

Only return the sentence, nothing else.
```

#### Tool Name Formatting:
- Convert tool names to Title Case
- Replace underscores with spaces
- Examples:
  - `lookup_tool` → "Lookup Tool"
  - `file_read` → "File Read"
  - `database_query` → "Database Query"

### 4. Intelligent Tool Selection

#### System Prompt Enhancement:
Add guidance to system prompt:
```
You have access to the following tools: [list tools]
- Use tools sequentially when needed to complete the task
- If a tool call fails, try alternative approaches
- If you cannot complete the task after reasonable attempts, explain why to the user
- Stop making tool calls when you have enough information to answer
```

#### Tool Call Strategy:
- LLM decides which tools to call
- Can call multiple tools in one iteration
- Can call tools sequentially across iterations
- Should adapt based on previous results

### 5. Implementation Details

#### Modified Function Signatures:
```swift
func streamMessage(
    _ text: String,
    configuration: LLMConfiguration,
    conversationHistory: [Message],
    onChunk: @escaping (String) -> Void,
    onThinkingStatusUpdate: @escaping (String) -> Void  // NEW
) async throws

private func executeToolCallsAndContinue(
    toolCalls: [[String: Any]],
    accumulatedContent: String,
    originalUserPrompt: String,
    configuration: LLMConfiguration,
    conversationHistory: [Message],
    tools: [[String: Any]],  // Keep tools available
    onChunk: @escaping (String) -> Void,
    onThinkingStatusUpdate: @escaping (String) -> Void,  // NEW
    iteration: Int = 0,
    maxIterations: Int = 10,
    consecutiveErrors: Int = 0,
    maxConsecutiveErrors: Int = 3
) async throws

// NEW: Generate intelligible status message
private func generateStatusMessage(
    toolName: String,
    arguments: [String: Any],
    configuration: LLMConfiguration,
    onThinkingStatusUpdate: @escaping (String) -> Void
) async -> String

// NEW: Format tool name for display
private func formatToolName(_ name: String) -> String
```

#### State Tracking:
- `iteration`: Current iteration count
- `consecutiveErrors`: Number of consecutive tool call errors
- `totalToolCalls`: Total number of tool calls made
- `startTime`: Operation start time for timeout

#### Error Handling:
```swift
enum ToolCallError: Error {
    case maxIterationsReached
    case tooManyConsecutiveErrors
    case timeout
    case toolUnavailable(String)
}

// When stopping due to error:
onChunk("\n\n[Unable to complete task: \(reason)]")
onThinkingStatusUpdate("Stopped: \(reason)")
```

### 6. Thinking Status Messages

#### Status Generation Flow:
1. **When tool call detected**:
   - Format tool name: `lookup_tool` → "Lookup Tool"
   - Extract arguments
   - Make quick LLM call: "Generate sentence for: Tool=Lookup Tool, Args={user_id: 123}"
   - Display generated sentence: "Looking up user information in the database"
   - Keep displayed until tool completes

2. **Generic Messages** (fallback if LLM call fails):
   - "Analyzing request..."
   - "Selecting appropriate tools..."
   - "Using [formatted_tool_name]..."
   - "Processing tool results..."
   - "Formulating final response..."

3. **Error Messages**:
   - "Tool [formatted_name] failed, trying alternative approach..."
   - "Unable to complete task: [reason]"

#### Status Generation Implementation:
```swift
private func generateStatusMessage(
    toolName: String,
    arguments: [String: Any],
    configuration: LLMConfiguration
) async -> String {
    let formattedName = formatToolName(toolName)
    let prompt = """
    Given this tool call:
    Tool: \(formattedName)
    Arguments: \(formatArguments(arguments))
    
    Generate a single, clear, natural sentence (max 10 words) describing what this action is doing from the user's perspective.
    Only return the sentence, nothing else.
    """
    
    // Quick LLM call (non-streaming, fast model)
    // Use same provider but with minimal tokens
    // Return fallback if call fails or times out
}
```

#### Tool Name Formatting Function:
```swift
private func formatToolName(_ name: String) -> String {
    return name
        .replacingOccurrences(of: "_", with: " ")
        .split(separator: " ")
        .map { $0.capitalized }
        .joined(separator: " ")
}
```

### 7. Integration Points

#### ChatViewModel Changes:
- Add `onThinkingStatusUpdate` callback
- Update `thinkingStatus` when callback is invoked
- Handle status updates during tool execution

#### OllamaProviderWithMCP Changes:
- Implement recursive tool calling loop
- Add status update callbacks
- Implement stopping conditions
- Track iteration and error counts

### 8. Testing Scenarios

1. **Single Tool Call**: LLM makes one tool call, gets result, responds
2. **Multiple Sequential Calls**: LLM makes 3-4 tool calls in sequence
3. **Error Recovery**: Tool fails, LLM tries alternative approach
4. **Max Iterations**: Reaches max iterations, stops gracefully
5. **Consecutive Errors**: 3 errors in a row, stops and reports
6. **Timeout**: Operation takes too long, stops gracefully
7. **No Tools Needed**: LLM responds without tool calls

## Implementation Steps

1. ✅ Add `onThinkingStatusUpdate` callback to protocol and implementations
2. ✅ Create `formatToolName()` helper function
3. ✅ Create `generateStatusMessage()` async function for LLM-based status generation
4. ✅ Modify `executeToolCallsAndContinue` to support recursive calls
5. ✅ Add stopping condition checks
6. ✅ Implement thinking status updates:
   - Call `generateStatusMessage()` when tool calls detected
   - Display generated status during tool execution
   - Fallback to formatted tool name if LLM call fails
7. ✅ Add error tracking and recovery logic
8. ✅ Update ChatViewModel to handle status updates
9. ✅ Test with various scenarios
10. ✅ Add logging for debugging

## Status Generation Details

### LLM Call for Status:
- **Model**: Use same model as main request (or fast fallback)
- **Max Tokens**: 20 (just need one sentence)
- **Timeout**: 2 seconds (fail fast, use fallback)
- **Prompt**: Simple instruction to generate status sentence
- **Fallback**: If call fails/timeout, use formatted tool name

### Example Flow:
1. Tool call detected: `lookup_tool` with `{user_id: 123}`
2. Format name: "Lookup Tool"
3. Generate status: Async LLM call → "Looking up user information in the database"
4. Display: "Looking up user information in the database"
5. Execute tool
6. Update status: "Processing tool results..."

## Benefits

- **Intelligent**: LLM can reason about which tools to use
- **Resilient**: Handles errors gracefully
- **Transparent**: User sees what's happening
- **Efficient**: Stops when appropriate instead of spinning
- **User-Friendly**: Clear error messages when tasks can't be completed
