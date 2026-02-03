import Foundation
import SwiftUI
import Combine

// MARK: - Agent Service
// Central service that coordinates all agent subsystems and provides
// a unified interface for the rest of the app to interact with the agent.

@MainActor
class AgentService: ObservableObject {
    // MARK: - Published State
    @Published private(set) var isInitialized = false
    @Published private(set) var agentName: String?
    @Published private(set) var developmentStage: DevelopmentStage = .nascent
    @Published private(set) var currentMood: EmotionalTone = .neutral
    @Published private(set) var activeAppendageCount: Int = 0
    @Published private(set) var notifications: [AgentNotification] = []

    // MARK: - Observation State
    @Published private(set) var isObserving: Bool = false
    @Published private(set) var currentSystemState: SystemState = SystemState()
    @Published private(set) var recentEvents: [SystemEvent] = []
    @Published private(set) var pendingProposals: [ActionProposal] = []

    // MARK: - Avatar
    @Published var avatarImageData: Data?
    @Published var avatarSystemIcon: String = "brain.head.profile"

    // MARK: - Subsystems (using singletons where appropriate)
    private let personalFileManager = PersonalFileManager.shared
    private var appendageCoordinator: AppendageCoordinator?
    private var skillLoader: SkillLoader?
    private var guardrailsCoordinator: GuardrailsCoordinator?
    private var skillGapDetector: SkillGapDetector?

    // MARK: - OS Integration Subsystems
    private let systemObserver = SystemObserver.shared
    private let proposalManager = ProposalManager.shared
    private let actionExecutor = ActionExecutor.shared
    private let activityTracker = ActivityTracker.shared

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        Task {
            await initialize()
        }
    }

    private func initialize() async {
        do {
            // Initialize personal file manager (loads or creates agent identity)
            try await personalFileManager.initialize()

            // Initialize appendage coordinator
            appendageCoordinator = AppendageCoordinator(personalFileManager: personalFileManager)

            // Initialize skill loader
            skillLoader = SkillLoader()
            try await skillLoader?.loadAllSkills()

            // Initialize guardrails
            guardrailsCoordinator = GuardrailsCoordinator()

            // Initialize skill gap detector
            skillGapDetector = SkillGapDetector(personalFileManager: personalFileManager)

            // Set up observation bindings
            setupObservationBindings()

            // Load initial state
            await refreshState()

            isInitialized = true
            AppLogger.shared.log("Agent service initialized", level: .info)

            // Auto-start system observation
            startObserving()

        } catch {
            AppLogger.shared.log("Failed to initialize agent service: \(error)", level: .error)
        }
    }

    private func setupObservationBindings() {
        // Bind system observer state
        systemObserver.$isObserving
            .receive(on: DispatchQueue.main)
            .assign(to: &$isObserving)

        systemObserver.$currentState
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentSystemState)

        systemObserver.$recentEvents
            .receive(on: DispatchQueue.main)
            .assign(to: &$recentEvents)

        // Bind proposal manager state
        proposalManager.$pendingProposals
            .receive(on: DispatchQueue.main)
            .assign(to: &$pendingProposals)

        // Subscribe to system events for decision making
        systemObserver.onEvent { [weak self] event in
            Task { @MainActor in
                await self?.handleSystemEvent(event)
            }
        }
    }

    private func handleSystemEvent(_ event: SystemEvent) async {
        // Record significant events as memories
        switch event.type {
        case .newMessageReceived:
            if let sender = event.data["sender"], let content = event.data["content"] {
                await recordInteraction(
                    summary: "Received message from \(sender): \(content.prefix(50))...",
                    outcome: .successful
                )
            }

        case .browserTabChanged:
            if let url = event.data["url"], let title = event.data["title"] {
                // Learn about user's browsing interests
                await learnFact("User visited: \(title) (\(url))", source: "browser observation")
            }

        case .downloadCompleted:
            if let fileName = event.data["fileName"] {
                // Could propose file organization
                AppLogger.shared.log("Agent noticed download: \(fileName)", level: .debug)
            }

        default:
            break
        }
    }

    private func refreshState() async {
        // Get current identity
        let identity = await personalFileManager.getIdentity()
        agentName = identity.name
        developmentStage = DevelopmentStage.stage(for: Date().timeIntervalSince(identity.birthTimestamp))

        // Get current state
        let state = await personalFileManager.getState()
        currentMood = state.currentMood

        // Get active appendages
        if let coordinator = appendageCoordinator {
            let appendages = await coordinator.getActiveAppendages()
            activeAppendageCount = appendages.count
        }

        // Get pending notifications
        notifications = await personalFileManager.getPendingNotifications()
    }

    // MARK: - Public API

    /// Record an interaction episode for memory
    func recordInteraction(summary: String, outcome: EpisodeOutcome, lessonsLearned: [String] = []) async {
        let episode = Episode(
            summary: summary,
            emotionalTone: currentMood,
            outcome: outcome,
            lessonsLearned: lessonsLearned
        )

        await personalFileManager.recordEpisode(episode)
        await refreshState()
    }

    /// Update the agent's current mood based on interaction
    func updateMood(valence: Float, arousal: Float, emotion: String?) async {
        let mood = EmotionalTone(valence: valence, arousal: arousal, dominantEmotion: emotion)
        await personalFileManager.updateMood(mood)
        currentMood = mood
    }

    /// Learn a new fact from an interaction
    func learnFact(_ fact: String, source: String = "conversation") async {
        let learnedFact = LearnedFact(fact: fact, source: source)
        await personalFileManager.addLearnedFact(learnedFact)
    }

    /// Record a user preference
    func recordPreference(key: String, value: String) async {
        await personalFileManager.recordPreference(key: key, value: value)
    }

    /// Spawn a background appendage for a task
    func spawnAppendage(for task: AppendageTask) async throws -> UUID {
        guard let coordinator = appendageCoordinator else {
            throw AgentError.notInitialized
        }

        let id = try await coordinator.spawnAppendage(for: task)
        await refreshState()
        return id
    }

    /// Check if an action is permitted by guardrails
    func evaluateAction(_ action: ProposedAction) async -> ActionEvaluationResult {
        guard let guardrails = guardrailsCoordinator else {
            return .allowed
        }
        return await guardrails.evaluateAction(action)
    }

    /// Find a skill that matches the input
    func findMatchingSkill(for input: String) async -> SkillLoader.LoadedSkill? {
        return await skillLoader?.findMatchingSkill(for: input)
    }

    /// Set the agent's name
    func setName(_ name: String, origin: String? = nil) async {
        await personalFileManager.setName(name, origin: origin)
        agentName = name

        // Record milestone
        let milestone = Milestone(
            description: "Named '\(name)' by partner",
            emotionalSignificance: 0.9,
            category: .namedByUser
        )
        await personalFileManager.addMilestone(milestone)
    }

    /// Acknowledge a notification
    func acknowledgeNotification(_ id: UUID) async {
        await personalFileManager.acknowledgeNotification(id)
        notifications.removeAll { $0.id == id }
    }

    /// Get the agent's birthday
    func getBirthday() async -> Date {
        return await personalFileManager.getBirthday()
    }

    /// Get total interaction count
    func getTotalInteractions() async -> Int {
        return await personalFileManager.getTotalInteractions()
    }

    /// Get relationship info with partner
    func getPartnerRelationship() async -> Relationship? {
        return await personalFileManager.getRelationship(partnerId: "primary")
    }

    // MARK: - System Observation

    /// Start ambient system observation
    func startObserving() {
        guard isInitialized else {
            AppLogger.shared.log("Cannot start observing - agent not initialized", level: .warning)
            return
        }
        systemObserver.startObserving()
        AppLogger.shared.log("Agent started observing system", level: .info)
    }

    /// Stop ambient system observation
    func stopObserving() {
        systemObserver.stopObserving()
        AppLogger.shared.log("Agent stopped observing system", level: .info)
    }

    /// Get current browser context
    func getCurrentBrowserContext() -> String? {
        guard let tab = currentSystemState.currentBrowserTab else { return nil }
        var context = "Currently viewing: \(tab.title)\nURL: \(tab.url)"
        if let content = currentSystemState.browserContent {
            context += "\n\nPage content preview:\n\(content.prefix(500))..."
        }
        return context
    }

    // MARK: - Action Proposals

    /// Submit a proposal for user approval
    func proposeAction(_ action: AgentAction, reasoning: String, urgency: ProposalUrgency = .routine) {
        let proposal = ActionProposal(
            action: action,
            reasoning: reasoning,
            urgency: urgency
        )
        proposalManager.submitProposal(proposal)
    }

    /// Approve a pending proposal
    func approveProposal(_ proposalId: UUID) async {
        guard let proposal = pendingProposals.first(where: { $0.id == proposalId }) else { return }

        proposalManager.resolveProposal(proposalId, result: .approved)

        // Execute the action
        let result = await actionExecutor.execute(proposal.action)

        // Record the interaction
        await recordInteraction(
            summary: "Executed: \(proposal.action.description)",
            outcome: result.success ? .successful : .challenging,
            lessonsLearned: result.success ? [] : ["Action failed: \(result.message ?? "unknown error")"]
        )
    }

    /// Reject a pending proposal
    func rejectProposal(_ proposalId: UUID) {
        proposalManager.resolveProposal(proposalId, result: .rejected)
    }

    /// Execute an action directly (for low-risk automatic actions)
    func executeAction(_ action: AgentAction) async -> ActionExecutor.ExecutionResult {
        // Check risk level
        if action.defaultRiskLevel.requiresApproval {
            // Should go through proposal system instead
            proposeAction(action, reasoning: "Automatic action requires approval")
            return .failure(action, error: "Action requires approval")
        }

        return await actionExecutor.execute(action)
    }

    // MARK: - Greeting Generation

    /// Generate a personalized greeting for a new session
    func generateGreeting() async -> AgentGreeting {
        let personalFile = await personalFileManager.getPersonalFile()
        return GreetingGenerator.generateGreeting(from: personalFile)
    }

    /// Check if we should greet the user (new session, returning user, etc.)
    func shouldGreetUser(conversationMessageCount: Int) async -> Bool {
        // Always greet on empty conversations
        if conversationMessageCount == 0 {
            return true
        }

        // Check if it's been a while since last interaction
        let lastInteraction = await personalFileManager.getPersonalFile().lastInteraction
        let hoursSinceLast = Date().timeIntervalSince(lastInteraction) / 3600

        // Greet if more than 4 hours since last interaction and conversation is fresh
        return hoursSinceLast > 4 && conversationMessageCount < 3
    }

    // MARK: - System Prompt Generation

    /// Generate a dynamic system prompt based on the agent's current PersonalFile
    func generateSystemPrompt(
        tools: [ToolInfo] = [],
        includeArtifactGuidelines: Bool = true,
        customInstructions: String? = nil
    ) async -> String {
        let personalFile = await personalFileManager.getPersonalFile()
        return DynamicSystemPromptBuilder.buildSystemPrompt(
            from: personalFile,
            tools: tools,
            includeArtifactGuidelines: includeArtifactGuidelines,
            customInstructions: customInstructions
        )
    }

    /// Get the agent's current PersonalFile for direct access
    func getPersonalFile() async -> PersonalFile {
        return await personalFileManager.getPersonalFile()
    }

    // MARK: - Post-Conversation Updates

    /// Process a completed conversation exchange to update agent memory and state
    func processConversationExchange(
        userMessage: String,
        assistantResponse: String,
        wasSuccessful: Bool,
        topics: [String] = []
    ) async {
        // Update recent topics
        var currentTopics = await personalFileManager.getPersonalFile().memory.recentTopics
        for topic in topics where !currentTopics.contains(topic) {
            currentTopics.insert(topic, at: 0)
        }
        await personalFileManager.updateRecentTopics(Array(currentTopics.prefix(10)))

        // Record the interaction
        let summary = "User: \(userMessage.prefix(100))... | Response: \(assistantResponse.prefix(100))..."
        let outcome: EpisodeOutcome = wasSuccessful ? .successful : .challenging

        await personalFileManager.recordEpisode(Episode(
            summary: summary,
            emotionalTone: currentMood,
            outcome: outcome,
            lessonsLearned: []
        ))

        // Update trust based on success
        if wasSuccessful {
            await personalFileManager.updateRelationshipTrust(delta: 0.01)
            await personalFileManager.updateMood(adjustment: PersonalFileManager.EmotionalAdjustment(
                valence: 0.05,
                arousal: 0.0
            ))
        }

        // Increment message count
        await personalFileManager.incrementMessageCount()

        // Analyze for skill gaps after processing the exchange
        await analyzeForSkillGaps(
            userMessage: userMessage,
            assistantResponse: assistantResponse,
            wasSuccessful: wasSuccessful
        )

        // Refresh published state
        await refreshState()
    }

    /// Learn a preference from conversation context
    func learnPreferenceFromConversation(key: String, value: String, confidence: Float = 0.7) async {
        await personalFileManager.setUserPreference(key: key, value: value, confidence: confidence)
    }

    // MARK: - Skill Gap Detection

    /// Analyze an interaction for potential skill gaps and trigger acquisition if needed
    private func analyzeForSkillGaps(
        userMessage: String,
        assistantResponse: String,
        wasSuccessful: Bool
    ) async {
        guard let detector = skillGapDetector else { return }

        // Build interaction analysis from the conversation exchange
        let interaction = InteractionAnalysis(
            description: "User: \(userMessage.prefix(100))...",
            failure: wasSuccessful ? nil : InteractionFailure(
                type: "conversation_failure",
                suggestedDomain: nil
            ),
            userRequest: UserRequest(
                type: categorizeRequest(userMessage),
                wasSuccessful: wasSuccessful
            ),
            containsUncertainty: assistantResponse.lowercased().contains("i'm not sure") ||
                                 assistantResponse.lowercased().contains("i don't know") ||
                                 assistantResponse.lowercased().contains("uncertain"),
            uncertaintyDomain: nil
        )

        // Analyze the interaction for skill gaps
        if let gaps = await detector.analyzeInteraction(interaction) {
            for gap in gaps where gap.severity == .high {
                AppLogger.shared.log("Skill gap detected: \(gap.domain) - \(gap.evidence)", level: .info)
                // Could trigger skill acquisition here in the future:
                // try? await skillAcquisitionEngine?.acquireSkill(for: gap)
            }

            // Log medium severity gaps for awareness
            for gap in gaps where gap.severity == .medium {
                AppLogger.shared.log("Potential skill gap: \(gap.domain) - \(gap.evidence)", level: .debug)
            }
        }
    }

    /// Categorize a user request into a skill domain
    private func categorizeRequest(_ message: String) -> String {
        let lowerMessage = message.lowercased()

        if lowerMessage.contains("code") || lowerMessage.contains("program") || lowerMessage.contains("function") {
            return "code_assistance"
        }
        if lowerMessage.contains("file") || lowerMessage.contains("folder") || lowerMessage.contains("directory") {
            return "file_operations"
        }
        if lowerMessage.contains("search") || lowerMessage.contains("find") || lowerMessage.contains("look up") {
            return "search_operations"
        }
        if lowerMessage.contains("write") || lowerMessage.contains("compose") || lowerMessage.contains("draft") {
            return "writing_assistance"
        }
        if lowerMessage.contains("explain") || lowerMessage.contains("what is") || lowerMessage.contains("how does") {
            return "explanation"
        }

        return "general"
    }

    // MARK: - Convenience Accessors

    var activityLevel: Float {
        activityTracker.activityLevel
    }

    var isUserActive: Bool {
        activityTracker.isUserActive
    }

    var frontmostApp: String {
        currentSystemState.frontmostApp
    }
}

// MARK: - Supporting Types

enum AgentError: LocalizedError {
    case notInitialized
    case appendageCapacityExceeded
    case skillNotFound
    case permissionDenied(String)

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Agent service not initialized"
        case .appendageCapacityExceeded:
            return "Maximum concurrent appendages reached"
        case .skillNotFound:
            return "No matching skill found"
        case .permissionDenied(let reason):
            return "Permission denied: \(reason)"
        }
    }
}

// Note: ProposedAction and ActionEvaluationResult are defined in GuardrailsSystem.swift
