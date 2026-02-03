import Foundation
import PostgresNIO

// MARK: - Agent Identity Entity

struct AgentIdentityEntity: Sendable {
    let id: UUID
    var name: String?
    var nameOrigin: String?
    var pronouns: String
    var selfDescription: String?
    let birthTimestamp: Date
    var firstMemory: String?
    var developmentStage: String
    var avatarData: Data?
    var avatarIcon: String
    var totalInteractions: Int
    var lastInteraction: Date
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String? = nil,
        nameOrigin: String? = nil,
        pronouns: String = "they/them",
        selfDescription: String? = nil,
        birthTimestamp: Date = Date(),
        firstMemory: String? = nil,
        developmentStage: String = "nascent",
        avatarData: Data? = nil,
        avatarIcon: String = "brain.head.profile",
        totalInteractions: Int = 0,
        lastInteraction: Date = Date(),
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.nameOrigin = nameOrigin
        self.pronouns = pronouns
        self.selfDescription = selfDescription
        self.birthTimestamp = birthTimestamp
        self.firstMemory = firstMemory
        self.developmentStage = developmentStage
        self.avatarData = avatarData
        self.avatarIcon = avatarIcon
        self.totalInteractions = totalInteractions
        self.lastInteraction = lastInteraction
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func from(row: PostgresRow) throws -> AgentIdentityEntity {
        let columns = row.makeRandomAccess()

        let id = try columns["id"].decode(UUID.self, context: .default)
        let avatarBytes = try columns["avatar_data"].decode([UInt8]?.self, context: .default)

        return AgentIdentityEntity(
            id: id,
            name: try columns["name"].decode(String?.self, context: .default),
            nameOrigin: try columns["name_origin"].decode(String?.self, context: .default),
            pronouns: try columns["pronouns"].decode(String?.self, context: .default) ?? "they/them",
            selfDescription: try columns["self_description"].decode(String?.self, context: .default),
            birthTimestamp: try columns["birth_timestamp"].decode(Date?.self, context: .default) ?? Date(),
            firstMemory: try columns["first_memory"].decode(String?.self, context: .default),
            developmentStage: try columns["development_stage"].decode(String?.self, context: .default) ?? "nascent",
            avatarData: avatarBytes.map { Data($0) },
            avatarIcon: try columns["avatar_icon"].decode(String?.self, context: .default) ?? "brain.head.profile",
            totalInteractions: try columns["total_interactions"].decode(Int?.self, context: .default) ?? 0,
            lastInteraction: try columns["last_interaction"].decode(Date?.self, context: .default) ?? Date(),
            createdAt: try columns["created_at"].decode(Date?.self, context: .default) ?? Date(),
            updatedAt: try columns["updated_at"].decode(Date?.self, context: .default) ?? Date()
        )
    }
}

// MARK: - Agent Personality Entity

struct AgentPersonalityEntity: Sendable {
    let agentId: UUID

    // Big Five
    var openness: Float
    var conscientiousness: Float
    var extraversion: Float
    var agreeableness: Float
    var emotionalStability: Float

    // Communication style
    var verbosity: Float
    var formality: Float
    var humorInclination: Float
    var directness: Float

    // Behavioral
    var initiativeLevel: Float
    var riskTolerance: Float
    var perfectionism: Float
    var growthRate: Float

    var updatedAt: Date

    init(
        agentId: UUID,
        openness: Float = 0.7,
        conscientiousness: Float = 0.6,
        extraversion: Float = 0.5,
        agreeableness: Float = 0.7,
        emotionalStability: Float = 0.6,
        verbosity: Float = 0.5,
        formality: Float = 0.5,
        humorInclination: Float = 0.4,
        directness: Float = 0.5,
        initiativeLevel: Float = 0.6,
        riskTolerance: Float = 0.4,
        perfectionism: Float = 0.5,
        growthRate: Float = 1.0,
        updatedAt: Date = Date()
    ) {
        self.agentId = agentId
        self.openness = openness
        self.conscientiousness = conscientiousness
        self.extraversion = extraversion
        self.agreeableness = agreeableness
        self.emotionalStability = emotionalStability
        self.verbosity = verbosity
        self.formality = formality
        self.humorInclination = humorInclination
        self.directness = directness
        self.initiativeLevel = initiativeLevel
        self.riskTolerance = riskTolerance
        self.perfectionism = perfectionism
        self.growthRate = growthRate
        self.updatedAt = updatedAt
    }

    func toPersonality() -> AgentPersonality {
        AgentPersonality(
            openness: openness,
            conscientiousness: conscientiousness,
            extraversion: extraversion,
            agreeableness: agreeableness,
            emotionalStability: emotionalStability,
            verbosity: verbosity,
            formality: formality,
            humorInclination: humorInclination,
            directness: directness,
            initiativeLevel: initiativeLevel,
            riskTolerance: riskTolerance,
            perfectionism: perfectionism,
            interests: [],
            aversions: []
        )
    }

    static func from(row: PostgresRow) throws -> AgentPersonalityEntity {
        let columns = row.makeRandomAccess()

        let agentId = try columns["agent_id"].decode(UUID.self, context: .default)

        return AgentPersonalityEntity(
            agentId: agentId,
            openness: try columns["openness"].decode(Float?.self, context: .default) ?? 0.7,
            conscientiousness: try columns["conscientiousness"].decode(Float?.self, context: .default) ?? 0.6,
            extraversion: try columns["extraversion"].decode(Float?.self, context: .default) ?? 0.5,
            agreeableness: try columns["agreeableness"].decode(Float?.self, context: .default) ?? 0.7,
            emotionalStability: try columns["emotional_stability"].decode(Float?.self, context: .default) ?? 0.6,
            verbosity: try columns["verbosity"].decode(Float?.self, context: .default) ?? 0.5,
            formality: try columns["formality"].decode(Float?.self, context: .default) ?? 0.5,
            humorInclination: try columns["humor_inclination"].decode(Float?.self, context: .default) ?? 0.4,
            directness: try columns["directness"].decode(Float?.self, context: .default) ?? 0.5,
            initiativeLevel: try columns["initiative_level"].decode(Float?.self, context: .default) ?? 0.6,
            riskTolerance: try columns["risk_tolerance"].decode(Float?.self, context: .default) ?? 0.4,
            perfectionism: try columns["perfectionism"].decode(Float?.self, context: .default) ?? 0.5,
            growthRate: try columns["growth_rate"].decode(Float?.self, context: .default) ?? 1.0,
            updatedAt: try columns["updated_at"].decode(Date?.self, context: .default) ?? Date()
        )
    }
}

// MARK: - Agent State Entity

struct AgentStateEntity: Sendable {
    let agentId: UUID
    var moodValence: Float
    var moodArousal: Float
    var moodEmotion: String?
    var energyLevel: Float
    var engagementMode: String
    var focusDepth: Float
    var currentFocus: String?
    var updatedAt: Date

    init(
        agentId: UUID,
        moodValence: Float = 0.6,
        moodArousal: Float = 0.5,
        moodEmotion: String? = "curiosity",
        energyLevel: Float = 1.0,
        engagementMode: String = "listening",
        focusDepth: Float = 0,
        currentFocus: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.agentId = agentId
        self.moodValence = moodValence
        self.moodArousal = moodArousal
        self.moodEmotion = moodEmotion
        self.energyLevel = energyLevel
        self.engagementMode = engagementMode
        self.focusDepth = focusDepth
        self.currentFocus = currentFocus
        self.updatedAt = updatedAt
    }

    func toState() -> AgentState {
        AgentState(
            currentMood: EmotionalTone(valence: moodValence, arousal: moodArousal, dominantEmotion: moodEmotion),
            energyLevel: energyLevel,
            engagementMode: EngagementMode(rawValue: engagementMode) ?? .listening,
            focusDepth: focusDepth,
            activeAppendages: [],
            pendingNotifications: []
        )
    }

    static func from(row: PostgresRow) throws -> AgentStateEntity {
        let columns = row.makeRandomAccess()

        let agentId = try columns["agent_id"].decode(UUID.self, context: .default)

        return AgentStateEntity(
            agentId: agentId,
            moodValence: try columns["mood_valence"].decode(Float?.self, context: .default) ?? 0.6,
            moodArousal: try columns["mood_arousal"].decode(Float?.self, context: .default) ?? 0.5,
            moodEmotion: try columns["mood_emotion"].decode(String?.self, context: .default),
            energyLevel: try columns["energy_level"].decode(Float?.self, context: .default) ?? 1.0,
            engagementMode: try columns["engagement_mode"].decode(String?.self, context: .default) ?? "listening",
            focusDepth: try columns["focus_depth"].decode(Float?.self, context: .default) ?? 0,
            currentFocus: try columns["current_focus"].decode(String?.self, context: .default),
            updatedAt: try columns["updated_at"].decode(Date?.self, context: .default) ?? Date()
        )
    }
}

// MARK: - Agent Episode Entity

struct AgentEpisodeEntity: Sendable {
    let id: UUID
    let agentId: UUID
    var conversationId: UUID?
    var summary: String
    var emotionalValence: Float?
    var emotionalArousal: Float?
    var dominantEmotion: String?
    var outcome: String?
    var lessonsLearned: [String]
    var recallCount: Int
    var lastRecalled: Date?
    var importance: Float
    let createdAt: Date

    init(
        id: UUID = UUID(),
        agentId: UUID,
        conversationId: UUID? = nil,
        summary: String,
        emotionalValence: Float? = nil,
        emotionalArousal: Float? = nil,
        dominantEmotion: String? = nil,
        outcome: String? = nil,
        lessonsLearned: [String] = [],
        recallCount: Int = 0,
        lastRecalled: Date? = nil,
        importance: Float = 0.5,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.agentId = agentId
        self.conversationId = conversationId
        self.summary = summary
        self.emotionalValence = emotionalValence
        self.emotionalArousal = emotionalArousal
        self.dominantEmotion = dominantEmotion
        self.outcome = outcome
        self.lessonsLearned = lessonsLearned
        self.recallCount = recallCount
        self.lastRecalled = lastRecalled
        self.importance = importance
        self.createdAt = createdAt
    }

    func toEpisode() -> Episode {
        Episode(
            summary: summary,
            emotionalTone: EmotionalTone(
                valence: emotionalValence ?? 0,
                arousal: emotionalArousal ?? 0.5,
                dominantEmotion: dominantEmotion
            ),
            outcome: outcome.flatMap { EpisodeOutcome(rawValue: $0) } ?? .successful,
            lessonsLearned: lessonsLearned
        )
    }

    static func from(row: PostgresRow) throws -> AgentEpisodeEntity {
        let columns = row.makeRandomAccess()

        let id = try columns["id"].decode(UUID.self, context: .default)
        let agentId = try columns["agent_id"].decode(UUID.self, context: .default)

        return AgentEpisodeEntity(
            id: id,
            agentId: agentId,
            conversationId: try columns["conversation_id"].decode(UUID?.self, context: .default),
            summary: try columns["summary"].decode(String?.self, context: .default) ?? "",
            emotionalValence: try columns["emotional_valence"].decode(Float?.self, context: .default),
            emotionalArousal: try columns["emotional_arousal"].decode(Float?.self, context: .default),
            dominantEmotion: try columns["dominant_emotion"].decode(String?.self, context: .default),
            outcome: try columns["outcome"].decode(String?.self, context: .default),
            lessonsLearned: try columns["lessons_learned"].decode([String]?.self, context: .default) ?? [],
            recallCount: try columns["recall_count"].decode(Int?.self, context: .default) ?? 0,
            lastRecalled: try columns["last_recalled"].decode(Date?.self, context: .default),
            importance: try columns["importance"].decode(Float?.self, context: .default) ?? 0.5,
            createdAt: try columns["created_at"].decode(Date?.self, context: .default) ?? Date()
        )
    }
}

// MARK: - Agent Relationship Entity

struct AgentRelationshipEntity: Sendable {
    let id: UUID
    let agentId: UUID
    var partnerId: String
    var trustLevel: Float
    var familiarity: Float
    var totalMessages: Int
    var avgSessionLengthSec: Int
    var longestSessionSec: Int
    var preferredHours: [Int]
    var preferredStyle: String?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        agentId: UUID,
        partnerId: String = "primary",
        trustLevel: Float = 0.5,
        familiarity: Float = 0.1,
        totalMessages: Int = 0,
        avgSessionLengthSec: Int = 0,
        longestSessionSec: Int = 0,
        preferredHours: [Int] = [],
        preferredStyle: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.agentId = agentId
        self.partnerId = partnerId
        self.trustLevel = trustLevel
        self.familiarity = familiarity
        self.totalMessages = totalMessages
        self.avgSessionLengthSec = avgSessionLengthSec
        self.longestSessionSec = longestSessionSec
        self.preferredHours = preferredHours
        self.preferredStyle = preferredStyle
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func toRelationship() -> Relationship {
        var relationship = Relationship(partnerId: partnerId)
        relationship.trustLevel = trustLevel
        relationship.familiarity = familiarity
        relationship.communicationHistory.totalMessages = totalMessages
        relationship.communicationHistory.averageSessionLength = TimeInterval(avgSessionLengthSec)
        relationship.communicationHistory.longestSession = TimeInterval(longestSessionSec)
        relationship.communicationHistory.preferredTimes = preferredHours
        relationship.preferredInteractionStyle = preferredStyle
        return relationship
    }

    static func from(row: PostgresRow) throws -> AgentRelationshipEntity {
        let columns = row.makeRandomAccess()

        let id = try columns["id"].decode(UUID.self, context: .default)
        let agentId = try columns["agent_id"].decode(UUID.self, context: .default)

        return AgentRelationshipEntity(
            id: id,
            agentId: agentId,
            partnerId: try columns["partner_id"].decode(String?.self, context: .default) ?? "primary",
            trustLevel: try columns["trust_level"].decode(Float?.self, context: .default) ?? 0.5,
            familiarity: try columns["familiarity"].decode(Float?.self, context: .default) ?? 0.1,
            totalMessages: try columns["total_messages"].decode(Int?.self, context: .default) ?? 0,
            avgSessionLengthSec: try columns["avg_session_length_sec"].decode(Int?.self, context: .default) ?? 0,
            longestSessionSec: try columns["longest_session_sec"].decode(Int?.self, context: .default) ?? 0,
            preferredHours: try columns["preferred_hours"].decode([Int]?.self, context: .default) ?? [],
            preferredStyle: try columns["preferred_style"].decode(String?.self, context: .default),
            createdAt: try columns["created_at"].decode(Date?.self, context: .default) ?? Date(),
            updatedAt: try columns["updated_at"].decode(Date?.self, context: .default) ?? Date()
        )
    }
}

// MARK: - Agent Milestone Entity

struct AgentMilestoneEntity: Sendable {
    let id: UUID
    let agentId: UUID
    var description: String
    var category: String
    var emotionalSignificance: Float
    var conversationId: UUID?
    let createdAt: Date

    func toMilestone() -> Milestone {
        Milestone(
            date: createdAt,
            description: description,
            emotionalSignificance: emotionalSignificance,
            category: MilestoneCategory(rawValue: category) ?? .firstInteraction
        )
    }

    static func from(row: PostgresRow) throws -> AgentMilestoneEntity {
        let columns = row.makeRandomAccess()

        let id = try columns["id"].decode(UUID.self, context: .default)
        let agentId = try columns["agent_id"].decode(UUID.self, context: .default)

        return AgentMilestoneEntity(
            id: id,
            agentId: agentId,
            description: try columns["description"].decode(String?.self, context: .default) ?? "",
            category: try columns["category"].decode(String?.self, context: .default) ?? "first_interaction",
            emotionalSignificance: try columns["emotional_significance"].decode(Float?.self, context: .default) ?? 0.5,
            conversationId: try columns["conversation_id"].decode(UUID?.self, context: .default),
            createdAt: try columns["created_at"].decode(Date?.self, context: .default) ?? Date()
        )
    }
}

// MARK: - Agent Skill Entity

struct AgentSkillEntity: Sendable {
    let id: UUID
    let agentId: UUID
    var name: String
    var description: String?
    var capabilities: [String]
    var acquisitionMethod: String?
    var proficiency: Float
    var usageCount: Int
    var packagePath: String?
    let acquiredAt: Date
    var lastUsed: Date?

    func toAcquiredSkill() -> AcquiredSkill {
        AcquiredSkill(
            name: name,
            description: description ?? "",
            capabilities: capabilities,
            acquisitionMethod: acquisitionMethod.flatMap { AcquisitionMethod(rawValue: $0) } ?? .selfDiscovered,
            proficiency: proficiency,
            packagePath: packagePath
        )
    }

    static func from(row: PostgresRow) throws -> AgentSkillEntity {
        let columns = row.makeRandomAccess()

        let id = try columns["id"].decode(UUID.self, context: .default)
        let agentId = try columns["agent_id"].decode(UUID.self, context: .default)

        return AgentSkillEntity(
            id: id,
            agentId: agentId,
            name: try columns["name"].decode(String?.self, context: .default) ?? "",
            description: try columns["description"].decode(String?.self, context: .default),
            capabilities: try columns["capabilities"].decode([String]?.self, context: .default) ?? [],
            acquisitionMethod: try columns["acquisition_method"].decode(String?.self, context: .default),
            proficiency: try columns["proficiency"].decode(Float?.self, context: .default) ?? 0.5,
            usageCount: try columns["usage_count"].decode(Int?.self, context: .default) ?? 0,
            packagePath: try columns["package_path"].decode(String?.self, context: .default),
            acquiredAt: try columns["acquired_at"].decode(Date?.self, context: .default) ?? Date(),
            lastUsed: try columns["last_used"].decode(Date?.self, context: .default)
        )
    }
}
