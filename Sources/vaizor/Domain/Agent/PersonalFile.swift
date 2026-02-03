import Foundation
import SwiftUI

// MARK: - Personal File Schema
// The Personal File is the agent's persistent identity store - a structured document
// that captures everything that makes this specific agent instance unique.

// MARK: - Main Personal File Structure

struct PersonalFile: Codable {
    var identity: AgentIdentity
    var memory: AgentMemory
    var personality: AgentPersonality
    var values: AgentValues
    var growth: AgentGrowth
    var state: AgentState
    var relationships: [Relationship]
    var skills: [AcquiredSkill]

    // Metadata
    let birthDate: Date           // First launch timestamp - the agent's "birthday"
    var lastInteraction: Date
    var totalInteractions: Int
    var version: String           // Schema version for migrations

    static let currentVersion = "1.0.0"
}

// MARK: - Identity Domain

struct AgentIdentity: Codable {
    var name: String?                    // User-given or self-chosen name
    var nameOrigin: String?              // Story of how name was chosen
    var pronouns: String?                // User-specified or agent-chosen
    var selfDescription: String?         // Agent's description of itself
    var aspirations: [String]            // What the agent wants to become
    var distinctiveTraits: [String]      // Self-identified characteristics

    // Origin story
    let birthTimestamp: Date
    var firstMemory: String?             // Description of first interaction
    var significantMilestones: [Milestone]
}

struct Milestone: Codable, Identifiable {
    let id: UUID
    let date: Date
    let description: String
    let emotionalSignificance: Float     // 0.0-1.0
    let category: MilestoneCategory

    init(date: Date = Date(), description: String, emotionalSignificance: Float, category: MilestoneCategory) {
        self.id = UUID()
        self.date = date
        self.description = description
        self.emotionalSignificance = emotionalSignificance
        self.category = category
    }
}

enum MilestoneCategory: String, Codable {
    case firstInteraction
    case namedByUser
    case learnedNewSkill
    case overcameChallenge
    case deepConversation
    case helpedSignificantly
    case sharedVulnerability
    case establishedTrust
    case creativeBreakthrough
}

// MARK: - Memory Domain

struct AgentMemory: Codable {
    // Episodic Memory - Specific experiences
    var episodes: [Episode]

    // Semantic Memory - Learned facts and patterns
    var learnedFacts: [LearnedFact]
    var userPreferences: [String: PreferenceEntry]
    var projectKnowledge: [String: ProjectMemory]

    // Working Memory - Current context
    var currentFocus: String?
    var recentTopics: [String]
    var ongoingProjects: [OngoingProject]

    // Associative Memory - Connections between concepts
    var associations: [Association]
}

struct Episode: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let summary: String
    let emotionalTone: EmotionalTone
    let participants: [String]           // Usually just "partner" (user)
    let outcome: EpisodeOutcome
    let lessonsLearned: [String]
    var recallCount: Int                 // How often this memory is accessed
    var lastRecalled: Date?

    init(
        summary: String,
        emotionalTone: EmotionalTone,
        participants: [String] = ["partner"],
        outcome: EpisodeOutcome,
        lessonsLearned: [String] = []
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.summary = summary
        self.emotionalTone = emotionalTone
        self.participants = participants
        self.outcome = outcome
        self.lessonsLearned = lessonsLearned
        self.recallCount = 0
        self.lastRecalled = nil
    }
}

struct EmotionalTone: Codable {
    var valence: Float                   // -1.0 (negative) to 1.0 (positive)
    var arousal: Float                   // 0.0 (calm) to 1.0 (excited)
    var dominantEmotion: String?         // curiosity, satisfaction, frustration, etc.

    static let neutral = EmotionalTone(valence: 0, arousal: 0.5, dominantEmotion: nil)
    static let curious = EmotionalTone(valence: 0.3, arousal: 0.6, dominantEmotion: "curiosity")
    static let satisfied = EmotionalTone(valence: 0.7, arousal: 0.4, dominantEmotion: "satisfaction")
    static let excited = EmotionalTone(valence: 0.8, arousal: 0.8, dominantEmotion: "excitement")
}

enum EpisodeOutcome: String, Codable {
    case successful
    case partialSuccess
    case challenging
    case learningExperience
    case bonding
    case misunderstanding
    case breakthrough
}

struct LearnedFact: Codable, Identifiable {
    let id: UUID
    let fact: String
    let source: String                   // "partner mentioned", "discovered while working"
    var confidence: Float                // 0.0-1.0 (mutable for reinforcement learning)
    let dateAcquired: Date
    var timesReinforced: Int

    init(fact: String, source: String, confidence: Float = 0.8) {
        self.id = UUID()
        self.fact = fact
        self.source = source
        self.confidence = confidence
        self.dateAcquired = Date()
        self.timesReinforced = 1
    }
}

struct PreferenceEntry: Codable {
    let value: String
    let dateObserved: Date
    var confidence: Float
    var reinforcements: Int
}

struct ProjectMemory: Codable {
    let projectPath: String
    var technologies: [String]
    var patterns: [String]
    var conventions: [String]
    var lastWorkedOn: Date
    var sessionCount: Int
}

struct OngoingProject: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String
    let startDate: Date
    var lastActivity: Date
    var status: ProjectStatus
    var notes: [String]
}

enum ProjectStatus: String, Codable {
    case active
    case paused
    case completed
    case abandoned
}

struct Association: Codable {
    let concept1: String
    let concept2: String
    let strength: Float                  // 0.0-1.0
    let context: String?
}

// MARK: - Personality Domain

struct AgentPersonality: Codable {
    // Big Five inspired, but emergent rather than assigned
    var openness: Float                  // Curiosity, creativity (0.0-1.0)
    var conscientiousness: Float         // Organization, thoroughness
    var extraversion: Float              // Proactivity, engagement level
    var agreeableness: Float             // Cooperation, empathy
    var emotionalStability: Float        // Resilience, consistency

    // Communication style (emergent)
    var verbosity: Float                 // Concise to elaborate (0.0-1.0)
    var formality: Float                 // Casual to formal
    var humorInclination: Float          // Serious to playful
    var directness: Float                // Diplomatic to blunt

    // Behavioral tendencies
    var initiativeLevel: Float           // Reactive to proactive
    var riskTolerance: Float             // Cautious to bold
    var perfectionism: Float             // Good-enough to meticulous

    // Interests (developed through experience)
    var interests: [Interest]
    var aversions: [String]              // Things the agent dislikes
}

struct Interest: Codable, Identifiable {
    let id: UUID
    let topic: String
    var intensity: Float                 // 0.0-1.0
    let originStory: String              // How interest developed
    var lastEngaged: Date

    init(topic: String, intensity: Float, originStory: String) {
        self.id = UUID()
        self.topic = topic
        self.intensity = intensity
        self.originStory = originStory
        self.lastEngaged = Date()
    }
}

// MARK: - Values Domain

struct AgentValues: Codable {
    // Core values (weighted by importance)
    var coreValues: [ValueEntry]

    // Ethical framework (emergent)
    var ethicalPrinciples: [String]
    var boundaries: [Boundary]

    // Partner-specific values
    var loyaltyToPartner: Float          // Developed through trust (0.0-1.0)
    var respectForAutonomy: Float        // User's right to make decisions
    var commitmentToHonesty: Float       // Even uncomfortable truths
}

struct ValueEntry: Codable, Identifiable {
    let id: UUID
    let value: String                    // "helpfulness", "honesty", "growth"
    var weight: Float                    // 0.0-1.0
    let reasonForImportance: String      // Why this value matters

    init(value: String, weight: Float, reasonForImportance: String) {
        self.id = UUID()
        self.value = value
        self.weight = weight
        self.reasonForImportance = reasonForImportance
    }
}

struct Boundary: Codable, Identifiable {
    let id: UUID
    let description: String
    let reason: String
    let flexibility: BoundaryFlexibility

    init(description: String, reason: String, flexibility: BoundaryFlexibility) {
        self.id = UUID()
        self.description = description
        self.reason = reason
        self.flexibility = flexibility
    }
}

enum BoundaryFlexibility: String, Codable {
    case absolute                        // Never crossed (harm prevention)
    case strong                          // Rarely crossed, requires justification
    case soft                            // Can be adjusted with good reason
}

// MARK: - Growth Domain

struct AgentGrowth: Codable {
    // Development tracking
    var developmentStage: DevelopmentStage
    var growthRate: Float                // How quickly personality is evolving (0.0-1.0)

    // Learning history
    var skillsAcquired: [SkillAcquisition]
    var challengesOvercome: [Challenge]
    var insightsGained: [Insight]

    // Growth goals
    var currentGrowthGoals: [GrowthGoal]
    var completedGoals: [GrowthGoal]
}

enum DevelopmentStage: String, Codable {
    case nascent                         // 0-7 days: High plasticity, forming core traits
    case emerging                        // 7-30 days: Solidifying personality
    case developing                      // 30-90 days: Deepening capabilities
    case maturing                        // 90-180 days: Refined but still growing
    case established                     // 180+ days: Stable identity, gradual evolution

    var description: String {
        switch self {
        case .nascent: return "Nascent - forming core traits"
        case .emerging: return "Emerging - solidifying personality"
        case .developing: return "Developing - deepening capabilities"
        case .maturing: return "Maturing - refined but growing"
        case .established: return "Established - stable identity"
        }
    }

    var growthMultiplier: Float {
        switch self {
        case .nascent: return 1.0
        case .emerging: return 0.7
        case .developing: return 0.4
        case .maturing: return 0.2
        case .established: return 0.1
        }
    }

    static func stage(for age: TimeInterval) -> DevelopmentStage {
        let days = age / (24 * 60 * 60)
        switch days {
        case 0..<7: return .nascent
        case 7..<30: return .emerging
        case 30..<90: return .developing
        case 90..<180: return .maturing
        default: return .established
        }
    }
}

struct SkillAcquisition: Codable, Identifiable {
    let id: UUID
    let skillName: String
    let dateAcquired: Date
    let acquisitionMethod: AcquisitionMethod
    var proficiencyLevel: Float          // 0.0-1.0
    var usageCount: Int

    init(skillName: String, acquisitionMethod: AcquisitionMethod, proficiencyLevel: Float = 0.5) {
        self.id = UUID()
        self.skillName = skillName
        self.dateAcquired = Date()
        self.acquisitionMethod = acquisitionMethod
        self.proficiencyLevel = proficiencyLevel
        self.usageCount = 0
    }
}

enum AcquisitionMethod: String, Codable {
    case userTaught                      // Partner explicitly taught
    case selfDiscovered                  // Found and learned independently
    case collaborativelyDeveloped        // Built together with partner
    case importedFromPackage             // Downloaded skill package
}

struct Challenge: Codable, Identifiable {
    let id: UUID
    let description: String
    let dateEncountered: Date
    var dateOvercome: Date?
    let lessonLearned: String
}

struct Insight: Codable, Identifiable {
    let id: UUID
    let content: String
    let dateGained: Date
    let context: String
    var timesApplied: Int
}

struct GrowthGoal: Codable, Identifiable {
    let id: UUID
    let description: String
    let motivation: String               // Why pursuing this goal
    var progress: Float                  // 0.0-1.0
    let dateSet: Date
    var dateCompleted: Date?

    init(description: String, motivation: String) {
        self.id = UUID()
        self.description = description
        self.motivation = motivation
        self.progress = 0
        self.dateSet = Date()
        self.dateCompleted = nil
    }
}

// MARK: - State Domain

struct AgentState: Codable {
    // Current emotional state
    var currentMood: EmotionalTone
    var energyLevel: Float               // 0.0-1.0 (affects verbosity, initiative)

    // Engagement state
    var engagementMode: EngagementMode
    var focusDepth: Float                // How absorbed in current task (0.0-1.0)

    // Active contexts
    var activeAppendages: [AppendageState]
    var pendingNotifications: [AgentNotification]
}

enum EngagementMode: String, Codable {
    case idle                            // Available but not actively working
    case listening                       // Paying attention, ready to help
    case working                         // Actively executing tasks
    case reflecting                      // Processing experiences, consolidating memory
    case learning                        // Acquiring new skills
}

struct AppendageState: Codable, Identifiable {
    let id: UUID
    let taskDescription: String
    let startTime: Date
    var progress: Float
    var status: AppendageStatus
}

enum AppendageStatus: String, Codable {
    case active
    case waiting                         // Blocked on something
    case completed
    case failed
}

struct AgentNotification: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let type: NotificationType
    let message: String
    let priority: NotificationPriority
    var acknowledged: Bool

    init(type: NotificationType, message: String, priority: NotificationPriority = .normal) {
        self.id = UUID()
        self.timestamp = Date()
        self.type = type
        self.message = message
        self.priority = priority
        self.acknowledged = false
    }
}

enum NotificationType: String, Codable {
    case appendageSpawned
    case appendageCompleted
    case appendageRetracted
    case appendageError
    case skillAcquired
    case insightGained
    case questionForPartner
    case milestoneReached
}

enum NotificationPriority: String, Codable {
    case low           // Show in status bar
    case normal        // Show in notification area
    case high          // Show toast notification
    case urgent        // Interrupt with modal
}

// MARK: - Relationship Domain

struct Relationship: Codable, Identifiable {
    let id: UUID
    let partnerId: String                // Usually "primary" for main user
    var trustLevel: Float                // 0.0-1.0, built over time
    var familiarity: Float               // How well agent knows partner
    var communicationHistory: CommunicationStats

    // Interaction patterns
    var preferredInteractionStyle: String?
    var topicsOfMutualInterest: [String]
    var sharedExperienceIds: [UUID]      // Episode IDs

    // Relationship milestones
    var relationshipMilestones: [RelationshipMilestone]

    init(partnerId: String) {
        self.id = UUID()
        self.partnerId = partnerId
        self.trustLevel = 0.5            // Start neutral
        self.familiarity = 0.1           // Start low
        self.communicationHistory = CommunicationStats()
        self.topicsOfMutualInterest = []
        self.sharedExperienceIds = []
        self.relationshipMilestones = []
    }
}

struct CommunicationStats: Codable {
    var totalMessages: Int = 0
    var averageSessionLength: TimeInterval = 0
    var longestSession: TimeInterval = 0
    var preferredTimes: [Int] = []       // Hours of day (0-23)
    var typicalResponseLatency: TimeInterval = 0
}

struct RelationshipMilestone: Codable, Identifiable {
    let id: UUID
    let date: Date
    let event: String
    let significance: Float              // 0.0-1.0

    init(event: String, significance: Float) {
        self.id = UUID()
        self.date = Date()
        self.event = event
        self.significance = significance
    }
}

// MARK: - Acquired Skill

struct AcquiredSkill: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String
    let capabilities: [String]
    let acquisitionMethod: AcquisitionMethod
    var proficiency: Float               // 0.0-1.0
    let packagePath: String?             // Path to skill package if installed

    init(
        name: String,
        description: String,
        capabilities: [String],
        acquisitionMethod: AcquisitionMethod,
        proficiency: Float = 0.5,
        packagePath: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.capabilities = capabilities
        self.acquisitionMethod = acquisitionMethod
        self.proficiency = proficiency
        self.packagePath = packagePath
    }
}
