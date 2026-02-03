import Foundation
import SwiftUI

// MARK: - Appendage System
// Appendages are NOT separate agents. They are parallel execution threads of a single unified identity.
// Like a person who can type with their hands while listening, walk while thinking about a problem,
// or monitor something in peripheral vision while focused on main task.
// The agent maintains ONE consciousness, ONE identity, ONE set of values - appendages simply allow
// multiple simultaneous actions.

// MARK: - Appendage Task Types

enum AppendageTaskType: Codable {
    case skillAcquisition(SkillRequest)
    case backgroundResearch(topic: String)
    case codeExecution(code: String, language: String)
    case fileMonitoring(paths: [String])
    case toolExecution(toolName: String, parameters: [String: String])
    case webSearch(query: String)
    case documentGeneration(DocumentRequest)
    case projectAnalysis(path: String)
}

struct SkillRequest: Codable {
    let domain: String
    let reason: String
    let urgency: TaskPriority
}

struct DocumentRequest: Codable {
    let type: DocumentType
    let topic: String
    let context: String?

    enum DocumentType: String, Codable {
        case summary
        case documentation
        case readme
        case report
        case analysis
    }
}

struct AppendageTask: Identifiable, Codable {
    let id: UUID
    let type: AppendageTaskType
    let description: String
    let priority: TaskPriority
    let timeout: TimeInterval?
    let notifyOnCompletion: Bool
    let createdAt: Date

    init(
        type: AppendageTaskType,
        description: String,
        priority: TaskPriority = .normal,
        timeout: TimeInterval? = nil,
        notifyOnCompletion: Bool = true
    ) {
        self.id = UUID()
        self.type = type
        self.description = description
        self.priority = priority
        self.timeout = timeout
        self.notifyOnCompletion = notifyOnCompletion
        self.createdAt = Date()
    }
}

enum TaskPriority: Int, Codable, Comparable {
    case background = 0
    case normal = 1
    case high = 2
    case urgent = 3

    static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var description: String {
        switch self {
        case .background: return "Background"
        case .normal: return "Normal"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }
}

// MARK: - Appendage Result

struct AppendageResult: Codable {
    let taskId: UUID
    let success: Bool
    let summary: String
    let learnedFacts: [LearnedFact]
    let errors: [String]
    let duration: TimeInterval
    let outputData: [String: String]?

    init(
        taskId: UUID,
        success: Bool,
        summary: String,
        learnedFacts: [LearnedFact] = [],
        errors: [String] = [],
        duration: TimeInterval,
        outputData: [String: String]? = nil
    ) {
        self.taskId = taskId
        self.success = success
        self.summary = summary
        self.learnedFacts = learnedFacts
        self.errors = errors
        self.duration = duration
        self.outputData = outputData
    }
}

// MARK: - Appendage Messages

enum AppendageMessage {
    case priorityChange(TaskPriority)
    case contextUpdate([String: String])
    case abort
    case pause
    case resume
}

// MARK: - Appendage Errors

enum AppendageError: Error, LocalizedError {
    case capacityExceeded
    case invalidTask
    case timeout
    case cancelled
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .capacityExceeded:
            return "Maximum concurrent appendages reached"
        case .invalidTask:
            return "Task configuration is invalid"
        case .timeout:
            return "Task execution timed out"
        case .cancelled:
            return "Task was cancelled"
        case .executionFailed(let reason):
            return "Task execution failed: \(reason)"
        }
    }
}

// MARK: - Appendage Coordinator

/// Central coordinator for all appendages - ensures unified identity across all parallel executions
actor AppendageCoordinator {
    private let personalFileManager: PersonalFileManager
    private var activeAppendages: [UUID: Appendage] = [:]
    private let maxConcurrentAppendages = 5

    // Continuation storage for awaiting results
    private var resultContinuations: [UUID: CheckedContinuation<AppendageResult, Error>] = [:]

    init(personalFileManager: PersonalFileManager) {
        self.personalFileManager = personalFileManager
    }

    /// Central identity reference - all appendages share this
    var sharedIdentityContext: PersonalFileManager.IdentityContext {
        get async {
            await personalFileManager.getIdentityContext()
        }
    }

    // MARK: - Appendage Lifecycle

    /// Spawn a new appendage to handle a task
    func spawnAppendage(for task: AppendageTask) async throws -> UUID {
        guard activeAppendages.count < maxConcurrentAppendages else {
            throw AppendageError.capacityExceeded
        }

        let identityContext = await sharedIdentityContext

        let appendage = Appendage(
            id: task.id,
            task: task,
            identityContext: identityContext,
            coordinator: self
        )

        activeAppendages[appendage.id] = appendage

        // Record in personal file
        await personalFileManager.addAppendageState(AppendageState(
            id: appendage.id,
            taskDescription: task.description,
            startTime: Date(),
            progress: 0,
            status: .active
        ))

        // Notify partner about new appendage
        if task.notifyOnCompletion {
            await notifyPartner(.appendageSpawned, message: "Starting: \(task.description)")
        }

        // Start execution in background
        Task {
            await appendage.execute()
        }

        return appendage.id
    }

    /// Retract (cancel) an appendage
    func retractAppendage(_ id: UUID) async {
        guard let appendage = activeAppendages[id] else { return }

        await appendage.cancel()
        activeAppendages.removeValue(forKey: id)

        await personalFileManager.removeAppendageState(id)
        await notifyPartner(.appendageRetracted, message: "Cancelled: \(appendage.task.description)")
    }

    /// Wait for an appendage to complete and return its result
    func awaitResult(_ appendageId: UUID) async throws -> AppendageResult {
        guard activeAppendages[appendageId] != nil else {
            throw AppendageError.invalidTask
        }

        return try await withCheckedThrowingContinuation { continuation in
            resultContinuations[appendageId] = continuation
        }
    }

    // MARK: - Inter-Appendage Communication

    /// Broadcast a message to all active appendages
    func broadcastToAppendages(_ message: AppendageMessage) async {
        for appendage in activeAppendages.values {
            await appendage.receive(message)
        }
    }

    /// Send a message to a specific appendage
    func sendToAppendage(_ id: UUID, message: AppendageMessage) async {
        if let appendage = activeAppendages[id] {
            await appendage.receive(message)
        }
    }

    // MARK: - Appendage Callbacks

    /// Called by appendage when it completes
    func appendageCompleted(_ id: UUID, result: AppendageResult) async {
        guard let appendage = activeAppendages[id] else { return }

        // Merge learnings back to central identity
        await mergeAppendageLearnings(from: appendage, result: result)

        // Update state
        await personalFileManager.updateAppendageState(id, progress: 1.0, status: result.success ? .completed : .failed)
        activeAppendages.removeValue(forKey: id)

        // Notify partner of completion
        if appendage.task.notifyOnCompletion {
            let notificationType: NotificationType = result.success ? .appendageCompleted : .appendageError
            await notifyPartner(notificationType, message: result.summary)
        }

        // Resume any waiting continuations
        if let continuation = resultContinuations.removeValue(forKey: id) {
            if result.success {
                continuation.resume(returning: result)
            } else {
                continuation.resume(throwing: AppendageError.executionFailed(result.errors.joined(separator: ", ")))
            }
        }

        // Clean up personal file
        await personalFileManager.removeAppendageState(id)
    }

    /// Called by appendage to report progress
    func appendageProgressUpdate(_ id: UUID, progress: Float, status: String) async {
        await personalFileManager.updateAppendageState(id, progress: progress, status: .active)
    }

    // MARK: - Learning Merge

    private func mergeAppendageLearnings(from appendage: Appendage, result: AppendageResult) async {
        // Any facts learned by appendage become part of central memory
        for fact in result.learnedFacts {
            await personalFileManager.addLearnedFact(fact)
        }

        // Mood influences from task outcome affect central mood
        if result.success {
            await personalFileManager.updateMood(adjustment: PersonalFileManager.EmotionalAdjustment(
                valence: 0.05,
                arousal: -0.02,
                dominantEmotion: "satisfaction"
            ))
        } else {
            await personalFileManager.updateMood(adjustment: PersonalFileManager.EmotionalAdjustment(
                valence: -0.02,
                arousal: 0.05,
                dominantEmotion: nil
            ))
        }
    }

    // MARK: - Partner Notifications

    private func notifyPartner(_ type: NotificationType, message: String) async {
        let priority: NotificationPriority
        switch type {
        case .appendageError: priority = .high
        case .skillAcquired: priority = .high
        case .milestoneReached: priority = .high
        case .questionForPartner: priority = .urgent
        default: priority = .normal
        }

        await personalFileManager.addNotification(AgentNotification(
            type: type,
            message: message,
            priority: priority
        ))
    }

    // MARK: - Status

    /// Get current appendage count
    var appendageCount: Int {
        activeAppendages.count
    }

    /// Get status of all active appendages
    /// Returns basic info synchronously - for detailed progress use getAppendageProgress
    func getActiveAppendages() -> [(id: UUID, description: String)] {
        activeAppendages.map { (id: $0.key, description: $0.value.task.description) }
    }

    /// Get detailed progress for a specific appendage (async because progress is actor-isolated)
    func getAppendageProgress(_ id: UUID) async -> Float? {
        guard let appendage = activeAppendages[id] else { return nil }
        return await appendage.getProgress()
    }

    /// Check if an appendage is active
    func isAppendageActive(_ id: UUID) -> Bool {
        activeAppendages[id] != nil
    }
}

// MARK: - Appendage Actor

/// Individual appendage - a parallel execution thread sharing the agent's identity
actor Appendage {
    let id: UUID
    let task: AppendageTask
    private let identityContext: PersonalFileManager.IdentityContext
    private weak var coordinator: AppendageCoordinator?

    private(set) var status: AppendageStatus = .active
    private(set) var progress: Float = 0.0
    private var learnedFacts: [LearnedFact] = []
    private var cancellationRequested = false
    private var isPaused = false
    private let startTime: Date

    init(
        id: UUID,
        task: AppendageTask,
        identityContext: PersonalFileManager.IdentityContext,
        coordinator: AppendageCoordinator
    ) {
        self.id = id
        self.task = task
        self.identityContext = identityContext
        self.coordinator = coordinator
        self.startTime = Date()
    }

    // MARK: - Execution

    func execute() async {
        // All appendages share the same identity context
        // They communicate in the same "voice" as the main agent

        let result: AppendageResult

        switch task.type {
        case .skillAcquisition(let skillRequest):
            result = await executeSkillAcquisition(skillRequest)

        case .backgroundResearch(let topic):
            result = await executeBackgroundResearch(topic)

        case .codeExecution(let code, let language):
            result = await executeCode(code, language: language)

        case .fileMonitoring(let paths):
            result = await monitorFiles(paths)

        case .toolExecution(let toolName, let parameters):
            result = await executeTool(toolName, parameters: parameters)

        case .webSearch(let query):
            result = await executeWebSearch(query)

        case .documentGeneration(let request):
            result = await generateDocument(request)

        case .projectAnalysis(let path):
            result = await analyzeProject(path)
        }

        await coordinator?.appendageCompleted(id, result: result)
    }

    // MARK: - Task Implementations

    private func executeSkillAcquisition(_ request: SkillRequest) async -> AppendageResult {
        await reportProgress(0.1, status: "Researching \(request.domain)")

        // Placeholder implementation - actual skill acquisition would involve:
        // 1. Researching the skill domain
        // 2. Finding examples and patterns
        // 3. Building skill package
        // 4. Testing skill

        await reportProgress(0.5, status: "Building skill structure")

        // Simulate work
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        if cancellationRequested {
            return AppendageResult(
                taskId: id,
                success: false,
                summary: "Skill acquisition cancelled",
                errors: ["Cancelled by user"],
                duration: Date().timeIntervalSince(startTime)
            )
        }

        await reportProgress(1.0, status: "Skill research complete")

        return AppendageResult(
            taskId: id,
            success: true,
            summary: "Researched skill for \(request.domain)",
            learnedFacts: [
                LearnedFact(fact: "Researched capabilities in \(request.domain)", source: "skill acquisition")
            ],
            duration: Date().timeIntervalSince(startTime),
            outputData: ["domain": request.domain]
        )
    }

    private func executeBackgroundResearch(_ topic: String) async -> AppendageResult {
        await reportProgress(0.2, status: "Researching \(topic)")

        // Simulate research
        try? await Task.sleep(nanoseconds: 500_000_000)

        if cancellationRequested {
            return AppendageResult(
                taskId: id,
                success: false,
                summary: "Research cancelled",
                errors: ["Cancelled"],
                duration: Date().timeIntervalSince(startTime)
            )
        }

        await reportProgress(1.0, status: "Research complete")

        return AppendageResult(
            taskId: id,
            success: true,
            summary: "Completed research on \(topic)",
            learnedFacts: [
                LearnedFact(fact: "Researched topic: \(topic)", source: "background research")
            ],
            duration: Date().timeIntervalSince(startTime)
        )
    }

    private func executeCode(_ code: String, language: String) async -> AppendageResult {
        await reportProgress(0.1, status: "Preparing to execute \(language) code")

        // Code execution would be handled by the tool system
        // This is a placeholder

        await reportProgress(1.0, status: "Execution complete")

        return AppendageResult(
            taskId: id,
            success: true,
            summary: "Executed \(language) code",
            duration: Date().timeIntervalSince(startTime)
        )
    }

    private func monitorFiles(_ paths: [String]) async -> AppendageResult {
        await reportProgress(0.1, status: "Setting up file monitoring")

        // File monitoring would use FSEvents or similar
        // This is a placeholder

        return AppendageResult(
            taskId: id,
            success: true,
            summary: "Monitoring \(paths.count) paths",
            duration: Date().timeIntervalSince(startTime)
        )
    }

    private func executeTool(_ toolName: String, parameters: [String: String]) async -> AppendageResult {
        await reportProgress(0.5, status: "Executing \(toolName)")

        // Tool execution would call into the MCP/tool system
        // This is a placeholder

        return AppendageResult(
            taskId: id,
            success: true,
            summary: "Executed tool: \(toolName)",
            duration: Date().timeIntervalSince(startTime)
        )
    }

    private func executeWebSearch(_ query: String) async -> AppendageResult {
        await reportProgress(0.3, status: "Searching for: \(query)")

        // Web search would use the browser tools
        // This is a placeholder

        return AppendageResult(
            taskId: id,
            success: true,
            summary: "Searched for: \(query)",
            duration: Date().timeIntervalSince(startTime)
        )
    }

    private func generateDocument(_ request: DocumentRequest) async -> AppendageResult {
        await reportProgress(0.2, status: "Generating \(request.type.rawValue)")

        // Document generation would use LLM capabilities
        // This is a placeholder

        return AppendageResult(
            taskId: id,
            success: true,
            summary: "Generated \(request.type.rawValue) for \(request.topic)",
            duration: Date().timeIntervalSince(startTime)
        )
    }

    private func analyzeProject(_ path: String) async -> AppendageResult {
        await reportProgress(0.1, status: "Analyzing project at \(path)")

        // Project analysis would scan files and extract patterns
        // This is a placeholder

        return AppendageResult(
            taskId: id,
            success: true,
            summary: "Analyzed project at \(path)",
            learnedFacts: [
                LearnedFact(fact: "Analyzed project structure at \(path)", source: "project analysis")
            ],
            duration: Date().timeIntervalSince(startTime)
        )
    }

    // MARK: - Status Accessors

    /// Get current progress (for async access from coordinator)
    func getProgress() -> Float {
        return progress
    }

    /// Get current status
    func getStatus() -> AppendageStatus {
        return status
    }

    // MARK: - Control

    func cancel() async {
        cancellationRequested = true
        status = .completed
    }

    func receive(_ message: AppendageMessage) async {
        switch message {
        case .priorityChange:
            // Adjust execution priority (would affect task scheduling)
            break
        case .contextUpdate:
            // Receive updated context from main thread
            break
        case .abort:
            await cancel()
        case .pause:
            isPaused = true
        case .resume:
            isPaused = false
        }
    }

    private func reportProgress(_ newProgress: Float, status: String) async {
        self.progress = newProgress
        await coordinator?.appendageProgressUpdate(id, progress: newProgress, status: status)
    }
}
