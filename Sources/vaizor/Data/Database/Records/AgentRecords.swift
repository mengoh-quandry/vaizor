import Foundation
import GRDB

// MARK: - Agent Identity Record (Singleton)
// Core identity, personality traits, and metadata

struct AgentIdentityRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "agent_identity"

    var id: Int64 = 1  // Singleton - always 1

    // Identity
    var name: String?
    var nameOrigin: String?
    var pronouns: String?
    var selfDescription: String?
    var aspirationsJson: String  // JSON array of strings
    var distinctiveTraitsJson: String  // JSON array of strings

    // Origin
    var birthTimestamp: Double
    var firstMemory: String?

    // Personality (Big Five + communication style)
    var openness: Double
    var conscientiousness: Double
    var extraversion: Double
    var agreeableness: Double
    var emotionalStability: Double
    var verbosity: Double
    var formality: Double
    var humorInclination: Double
    var directness: Double
    var initiativeLevel: Double
    var riskTolerance: Double
    var perfectionism: Double
    var aversionsJson: String  // JSON array of strings

    // Values
    var loyaltyToPartner: Double
    var respectForAutonomy: Double
    var commitmentToHonesty: Double
    var ethicalPrinciplesJson: String  // JSON array of strings

    // Growth
    var developmentStage: String
    var growthRate: Double

    // State
    var currentMoodValence: Double
    var currentMoodArousal: Double
    var currentMoodEmotion: String?
    var energyLevel: Double
    var engagementMode: String
    var focusDepth: Double
    var currentFocus: String?
    var recentTopicsJson: String  // JSON array of strings

    // Metadata
    var lastInteraction: Double
    var totalInteractions: Int
    var version: String

    enum CodingKeys: String, CodingKey {
        case id
        case name, nameOrigin, pronouns, selfDescription
        case aspirationsJson = "aspirations_json"
        case distinctiveTraitsJson = "distinctive_traits_json"
        case birthTimestamp = "birth_timestamp"
        case firstMemory = "first_memory"
        case openness, conscientiousness, extraversion, agreeableness
        case emotionalStability = "emotional_stability"
        case verbosity, formality
        case humorInclination = "humor_inclination"
        case directness
        case initiativeLevel = "initiative_level"
        case riskTolerance = "risk_tolerance"
        case perfectionism
        case aversionsJson = "aversions_json"
        case loyaltyToPartner = "loyalty_to_partner"
        case respectForAutonomy = "respect_for_autonomy"
        case commitmentToHonesty = "commitment_to_honesty"
        case ethicalPrinciplesJson = "ethical_principles_json"
        case developmentStage = "development_stage"
        case growthRate = "growth_rate"
        case currentMoodValence = "current_mood_valence"
        case currentMoodArousal = "current_mood_arousal"
        case currentMoodEmotion = "current_mood_emotion"
        case energyLevel = "energy_level"
        case engagementMode = "engagement_mode"
        case focusDepth = "focus_depth"
        case currentFocus = "current_focus"
        case recentTopicsJson = "recent_topics_json"
        case lastInteraction = "last_interaction"
        case totalInteractions = "total_interactions"
        case version
    }
}

// MARK: - Agent Episode Record
// Episodic memory - specific experiences, can link to conversations

struct AgentEpisodeRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "agent_episodes"

    var id: String  // UUID
    var conversationId: String?  // Link to conversation
    var timestamp: Double
    var summary: String
    var emotionalValence: Double
    var emotionalArousal: Double
    var emotionalDominant: String?
    var participantsJson: String  // JSON array
    var outcome: String
    var lessonsLearnedJson: String  // JSON array
    var recallCount: Int
    var lastRecalled: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case timestamp, summary
        case emotionalValence = "emotional_valence"
        case emotionalArousal = "emotional_arousal"
        case emotionalDominant = "emotional_dominant"
        case participantsJson = "participants_json"
        case outcome
        case lessonsLearnedJson = "lessons_learned_json"
        case recallCount = "recall_count"
        case lastRecalled = "last_recalled"
    }
}

// MARK: - Agent Learned Fact Record

struct AgentLearnedFactRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "agent_learned_facts"

    var id: String  // UUID
    var fact: String
    var source: String
    var confidence: Double
    var dateAcquired: Double
    var timesReinforced: Int

    enum CodingKeys: String, CodingKey {
        case id, fact, source, confidence
        case dateAcquired = "date_acquired"
        case timesReinforced = "times_reinforced"
    }
}

// MARK: - Agent Preference Record

struct AgentPreferenceRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "agent_preferences"

    var key: String  // Primary key
    var value: String
    var dateObserved: Double
    var confidence: Double
    var reinforcements: Int

    enum CodingKeys: String, CodingKey {
        case key, value
        case dateObserved = "date_observed"
        case confidence, reinforcements
    }
}

// MARK: - Agent Milestone Record

struct AgentMilestoneRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "agent_milestones"

    var id: String  // UUID
    var date: Double
    var description: String
    var emotionalSignificance: Double
    var category: String

    enum CodingKeys: String, CodingKey {
        case id, date, description
        case emotionalSignificance = "emotional_significance"
        case category
    }
}

// MARK: - Agent Skill Record

struct AgentSkillRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "agent_skills"

    var id: String  // UUID
    var name: String
    var description: String
    var capabilitiesJson: String  // JSON array
    var acquisitionMethod: String
    var proficiency: Double
    var packagePath: String?
    var dateAcquired: Double
    var usageCount: Int

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case capabilitiesJson = "capabilities_json"
        case acquisitionMethod = "acquisition_method"
        case proficiency
        case packagePath = "package_path"
        case dateAcquired = "date_acquired"
        case usageCount = "usage_count"
    }
}

// MARK: - Agent Interest Record

struct AgentInterestRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "agent_interests"

    var id: String  // UUID
    var topic: String
    var intensity: Double
    var originStory: String
    var lastEngaged: Double

    enum CodingKeys: String, CodingKey {
        case id, topic, intensity
        case originStory = "origin_story"
        case lastEngaged = "last_engaged"
    }
}

// MARK: - Agent Value Record

struct AgentValueRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "agent_values"

    var id: String  // UUID
    var value: String
    var weight: Double
    var reasonForImportance: String

    enum CodingKeys: String, CodingKey {
        case id, value, weight
        case reasonForImportance = "reason_for_importance"
    }
}

// MARK: - Agent Boundary Record

struct AgentBoundaryRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "agent_boundaries"

    var id: String  // UUID
    var description: String
    var reason: String
    var flexibility: String
}

// MARK: - Agent Relationship Record

struct AgentRelationshipRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "agent_relationships"

    var id: String  // UUID
    var partnerId: String
    var trustLevel: Double
    var familiarity: Double
    var preferredInteractionStyle: String?
    var topicsOfMutualInterestJson: String  // JSON array
    var sharedExperienceIdsJson: String  // JSON array of episode UUIDs

    // Communication stats
    var totalMessages: Int
    var averageSessionLength: Double
    var longestSession: Double
    var preferredTimesJson: String  // JSON array of hours
    var typicalResponseLatency: Double

    enum CodingKeys: String, CodingKey {
        case id
        case partnerId = "partner_id"
        case trustLevel = "trust_level"
        case familiarity
        case preferredInteractionStyle = "preferred_interaction_style"
        case topicsOfMutualInterestJson = "topics_of_mutual_interest_json"
        case sharedExperienceIdsJson = "shared_experience_ids_json"
        case totalMessages = "total_messages"
        case averageSessionLength = "average_session_length"
        case longestSession = "longest_session"
        case preferredTimesJson = "preferred_times_json"
        case typicalResponseLatency = "typical_response_latency"
    }
}

// MARK: - Agent Relationship Milestone Record

struct AgentRelationshipMilestoneRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "agent_relationship_milestones"

    var id: String  // UUID
    var relationshipId: String  // FK to agent_relationships
    var date: Double
    var event: String
    var significance: Double

    enum CodingKeys: String, CodingKey {
        case id
        case relationshipId = "relationship_id"
        case date, event, significance
    }
}

// MARK: - Agent Notification Record

struct AgentNotificationRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "agent_notifications"

    var id: String  // UUID
    var timestamp: Double
    var type: String
    var message: String
    var priority: String
    var acknowledged: Bool

    enum CodingKeys: String, CodingKey {
        case id, timestamp, type, message, priority, acknowledged
    }
}

// MARK: - Agent Growth Goal Record

struct AgentGrowthGoalRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "agent_growth_goals"

    var id: String  // UUID
    var description: String
    var motivation: String
    var progress: Double
    var dateSet: Double
    var dateCompleted: Double?
    var isCompleted: Bool

    enum CodingKeys: String, CodingKey {
        case id, description, motivation, progress
        case dateSet = "date_set"
        case dateCompleted = "date_completed"
        case isCompleted = "is_completed"
    }
}

// MARK: - Agent Challenge Record

struct AgentChallengeRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "agent_challenges"

    var id: String  // UUID
    var description: String
    var dateEncountered: Double
    var dateOvercome: Double?
    var lessonLearned: String

    enum CodingKeys: String, CodingKey {
        case id, description
        case dateEncountered = "date_encountered"
        case dateOvercome = "date_overcome"
        case lessonLearned = "lesson_learned"
    }
}

// MARK: - Agent Insight Record

struct AgentInsightRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "agent_insights"

    var id: String  // UUID
    var content: String
    var dateGained: Double
    var context: String
    var timesApplied: Int

    enum CodingKeys: String, CodingKey {
        case id, content
        case dateGained = "date_gained"
        case context
        case timesApplied = "times_applied"
    }
}

// MARK: - Agent Appendage State Record

struct AgentAppendageStateRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "agent_appendage_states"

    var id: String  // UUID
    var taskDescription: String
    var startTime: Double
    var progress: Double
    var status: String

    enum CodingKeys: String, CodingKey {
        case id
        case taskDescription = "task_description"
        case startTime = "start_time"
        case progress, status
    }
}

// MARK: - Agent Project Memory Record

struct AgentProjectMemoryRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "agent_project_memories"

    var projectPath: String  // Primary key
    var technologiesJson: String  // JSON array
    var patternsJson: String  // JSON array
    var conventionsJson: String  // JSON array
    var lastWorkedOn: Double
    var sessionCount: Int

    enum CodingKeys: String, CodingKey {
        case projectPath = "project_path"
        case technologiesJson = "technologies_json"
        case patternsJson = "patterns_json"
        case conventionsJson = "conventions_json"
        case lastWorkedOn = "last_worked_on"
        case sessionCount = "session_count"
    }
}

// MARK: - Agent Ongoing Project Record

struct AgentOngoingProjectRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "agent_ongoing_projects"

    var id: String  // UUID
    var name: String
    var description: String
    var startDate: Double
    var lastActivity: Double
    var status: String
    var notesJson: String  // JSON array

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case startDate = "start_date"
        case lastActivity = "last_activity"
        case status
        case notesJson = "notes_json"
    }
}

// MARK: - Agent Association Record

struct AgentAssociationRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "agent_associations"

    var id: Int64?  // Auto-increment
    var concept1: String
    var concept2: String
    var strength: Double
    var context: String?

    enum CodingKeys: String, CodingKey {
        case id, concept1, concept2, strength, context
    }
}
