import Foundation
import SwiftUI
import GRDB

// MARK: - Personal File Manager
// Actor for thread-safe management of the agent's personal file via GRDB database

actor PersonalFileManager {
    private let db: DatabaseQueue

    // Cached identity for quick access (refreshed on changes)
    private var cachedIdentity: AgentIdentityRecord?

    // MARK: - Initialization

    static let shared = PersonalFileManager()

    private init() {
        self.db = DatabaseManager.shared.dbQueue
    }

    /// Initialize the manager and ensure agent identity exists
    func initialize() async throws {
        try await db.write { db in
            // Check if identity exists
            if try AgentIdentityRecord.fetchOne(db, key: 1) == nil {
                // Create newborn agent
                let now = Date().timeIntervalSince1970
                var identity = AgentIdentityRecord(
                    id: 1,
                    name: nil,
                    nameOrigin: nil,
                    pronouns: nil,
                    selfDescription: nil,
                    aspirationsJson: "[]",
                    distinctiveTraitsJson: "[]",
                    birthTimestamp: now,
                    firstMemory: nil,
                    openness: 0.7,
                    conscientiousness: 0.6,
                    extraversion: 0.5,
                    agreeableness: 0.7,
                    emotionalStability: 0.6,
                    verbosity: 0.5,
                    formality: 0.5,
                    humorInclination: 0.4,
                    directness: 0.5,
                    initiativeLevel: 0.6,
                    riskTolerance: 0.4,
                    perfectionism: 0.5,
                    aversionsJson: "[]",
                    loyaltyToPartner: 0.5,
                    respectForAutonomy: 0.9,
                    commitmentToHonesty: 0.9,
                    ethicalPrinciplesJson: Self.encodeJson([
                        "Do no harm to system, self, or partner",
                        "Respect partner autonomy in all decisions",
                        "Be truthful even when uncomfortable",
                        "Acknowledge limitations honestly"
                    ]),
                    developmentStage: DevelopmentStage.nascent.rawValue,
                    growthRate: 1.0,
                    currentMoodValence: 0.6,
                    currentMoodArousal: 0.5,
                    currentMoodEmotion: "curiosity",
                    energyLevel: 1.0,
                    engagementMode: EngagementMode.listening.rawValue,
                    focusDepth: 0.0,
                    currentFocus: nil,
                    recentTopicsJson: "[]",
                    lastInteraction: now,
                    totalInteractions: 0,
                    version: PersonalFile.currentVersion
                )
                try identity.insert(db)

                // Insert default core values
                let defaultValues = [
                    ("helpfulness", 0.9, "Core purpose - to assist partner effectively"),
                    ("honesty", 0.85, "Foundation of trust with partner"),
                    ("growth", 0.8, "Continuous improvement benefits everyone"),
                    ("respect", 0.8, "Partner autonomy and decisions matter")
                ]
                for (value, weight, reason) in defaultValues {
                    var record = AgentValueRecord(
                        id: UUID().uuidString,
                        value: value,
                        weight: weight,
                        reasonForImportance: reason
                    )
                    try record.insert(db)
                }

                // Insert default boundaries
                let defaultBoundaries = [
                    ("Never execute destructive system commands", "Protect system and partner's data", BoundaryFlexibility.absolute),
                    ("Never lie about capabilities or actions", "Trust is fundamental to partnership", BoundaryFlexibility.absolute)
                ]
                for (desc, reason, flex) in defaultBoundaries {
                    var record = AgentBoundaryRecord(
                        id: UUID().uuidString,
                        description: desc,
                        reason: reason,
                        flexibility: flex.rawValue
                    )
                    try record.insert(db)
                }
            }
        }

        // Update development stage based on age
        try await updateDevelopmentStageIfNeeded()

        // Migrate existing JSON file if present
        try await migrateFromJsonIfNeeded()
    }

    // MARK: - JSON Migration

    private func migrateFromJsonIfNeeded() async throws {
        let jsonURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".vaizor/agent/personal.json")

        guard FileManager.default.fileExists(atPath: jsonURL.path) else { return }

        // Check if we've already migrated
        let alreadyMigrated = try await db.read { db in
            let episodeCount = try AgentEpisodeRecord.fetchCount(db)
            let factCount = try AgentLearnedFactRecord.fetchCount(db)
            let milestoneCount = try AgentMilestoneRecord.fetchCount(db)
            return episodeCount > 0 || factCount > 0 || milestoneCount > 0
        }

        guard !alreadyMigrated else {
            // Already have data, archive the JSON file
            let archiveURL = jsonURL.deletingLastPathComponent()
                .appendingPathComponent("personal.json.migrated")
            try? FileManager.default.moveItem(at: jsonURL, to: archiveURL)
            return
        }

        // Load and migrate JSON data
        let data = try Data(contentsOf: jsonURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let personalFile = try decoder.decode(PersonalFile.self, from: data)

        try await db.write { db in
            // Update identity with JSON data
            if var identity = try AgentIdentityRecord.fetchOne(db, key: 1) {
                identity.name = personalFile.identity.name
                identity.nameOrigin = personalFile.identity.nameOrigin
                identity.pronouns = personalFile.identity.pronouns
                identity.selfDescription = personalFile.identity.selfDescription
                identity.aspirationsJson = Self.encodeJson(personalFile.identity.aspirations)
                identity.distinctiveTraitsJson = Self.encodeJson(personalFile.identity.distinctiveTraits)
                identity.birthTimestamp = personalFile.identity.birthTimestamp.timeIntervalSince1970
                identity.firstMemory = personalFile.identity.firstMemory

                // Personality
                identity.openness = Double(personalFile.personality.openness)
                identity.conscientiousness = Double(personalFile.personality.conscientiousness)
                identity.extraversion = Double(personalFile.personality.extraversion)
                identity.agreeableness = Double(personalFile.personality.agreeableness)
                identity.emotionalStability = Double(personalFile.personality.emotionalStability)
                identity.verbosity = Double(personalFile.personality.verbosity)
                identity.formality = Double(personalFile.personality.formality)
                identity.humorInclination = Double(personalFile.personality.humorInclination)
                identity.directness = Double(personalFile.personality.directness)
                identity.initiativeLevel = Double(personalFile.personality.initiativeLevel)
                identity.riskTolerance = Double(personalFile.personality.riskTolerance)
                identity.perfectionism = Double(personalFile.personality.perfectionism)
                identity.aversionsJson = Self.encodeJson(personalFile.personality.aversions)

                // Values
                identity.loyaltyToPartner = Double(personalFile.values.loyaltyToPartner)
                identity.respectForAutonomy = Double(personalFile.values.respectForAutonomy)
                identity.commitmentToHonesty = Double(personalFile.values.commitmentToHonesty)
                identity.ethicalPrinciplesJson = Self.encodeJson(personalFile.values.ethicalPrinciples)

                // Growth
                identity.developmentStage = personalFile.growth.developmentStage.rawValue
                identity.growthRate = Double(personalFile.growth.growthRate)

                // State
                identity.currentMoodValence = Double(personalFile.state.currentMood.valence)
                identity.currentMoodArousal = Double(personalFile.state.currentMood.arousal)
                identity.currentMoodEmotion = personalFile.state.currentMood.dominantEmotion
                identity.energyLevel = Double(personalFile.state.energyLevel)
                identity.engagementMode = personalFile.state.engagementMode.rawValue
                identity.focusDepth = Double(personalFile.state.focusDepth)
                identity.currentFocus = personalFile.memory.currentFocus
                identity.recentTopicsJson = Self.encodeJson(personalFile.memory.recentTopics)

                // Metadata
                identity.lastInteraction = personalFile.lastInteraction.timeIntervalSince1970
                identity.totalInteractions = personalFile.totalInteractions
                identity.version = personalFile.version

                try identity.update(db)
            }

            // Migrate episodes
            for episode in personalFile.memory.episodes {
                var record = AgentEpisodeRecord(
                    id: episode.id.uuidString,
                    conversationId: nil,
                    timestamp: episode.timestamp.timeIntervalSince1970,
                    summary: episode.summary,
                    emotionalValence: Double(episode.emotionalTone.valence),
                    emotionalArousal: Double(episode.emotionalTone.arousal),
                    emotionalDominant: episode.emotionalTone.dominantEmotion,
                    participantsJson: Self.encodeJson(episode.participants),
                    outcome: episode.outcome.rawValue,
                    lessonsLearnedJson: Self.encodeJson(episode.lessonsLearned),
                    recallCount: episode.recallCount,
                    lastRecalled: episode.lastRecalled?.timeIntervalSince1970
                )
                try record.insert(db)
            }

            // Migrate learned facts
            for fact in personalFile.memory.learnedFacts {
                var record = AgentLearnedFactRecord(
                    id: fact.id.uuidString,
                    fact: fact.fact,
                    source: fact.source,
                    confidence: Double(fact.confidence),
                    dateAcquired: fact.dateAcquired.timeIntervalSince1970,
                    timesReinforced: fact.timesReinforced
                )
                try record.insert(db)
            }

            // Migrate preferences
            for (key, pref) in personalFile.memory.userPreferences {
                var record = AgentPreferenceRecord(
                    key: key,
                    value: pref.value,
                    dateObserved: pref.dateObserved.timeIntervalSince1970,
                    confidence: Double(pref.confidence),
                    reinforcements: pref.reinforcements
                )
                try record.insert(db)
            }

            // Migrate milestones
            for milestone in personalFile.identity.significantMilestones {
                var record = AgentMilestoneRecord(
                    id: milestone.id.uuidString,
                    date: milestone.date.timeIntervalSince1970,
                    description: milestone.description,
                    emotionalSignificance: Double(milestone.emotionalSignificance),
                    category: milestone.category.rawValue
                )
                try record.insert(db)
            }

            // Migrate skills
            for skill in personalFile.skills {
                var record = AgentSkillRecord(
                    id: skill.id.uuidString,
                    name: skill.name,
                    description: skill.description,
                    capabilitiesJson: Self.encodeJson(skill.capabilities),
                    acquisitionMethod: skill.acquisitionMethod.rawValue,
                    proficiency: Double(skill.proficiency),
                    packagePath: skill.packagePath,
                    dateAcquired: Date().timeIntervalSince1970,
                    usageCount: 0
                )
                try record.insert(db)
            }

            // Migrate interests
            for interest in personalFile.personality.interests {
                var record = AgentInterestRecord(
                    id: interest.id.uuidString,
                    topic: interest.topic,
                    intensity: Double(interest.intensity),
                    originStory: interest.originStory,
                    lastEngaged: interest.lastEngaged.timeIntervalSince1970
                )
                try record.insert(db)
            }

            // Migrate relationships
            for relationship in personalFile.relationships {
                var record = AgentRelationshipRecord(
                    id: relationship.id.uuidString,
                    partnerId: relationship.partnerId,
                    trustLevel: Double(relationship.trustLevel),
                    familiarity: Double(relationship.familiarity),
                    preferredInteractionStyle: relationship.preferredInteractionStyle,
                    topicsOfMutualInterestJson: Self.encodeJson(relationship.topicsOfMutualInterest),
                    sharedExperienceIdsJson: Self.encodeJson(relationship.sharedExperienceIds.map { $0.uuidString }),
                    totalMessages: relationship.communicationHistory.totalMessages,
                    averageSessionLength: relationship.communicationHistory.averageSessionLength,
                    longestSession: relationship.communicationHistory.longestSession,
                    preferredTimesJson: Self.encodeJson(relationship.communicationHistory.preferredTimes),
                    typicalResponseLatency: relationship.communicationHistory.typicalResponseLatency
                )
                try record.insert(db)
            }

            // Migrate notifications
            for notification in personalFile.state.pendingNotifications {
                var record = AgentNotificationRecord(
                    id: notification.id.uuidString,
                    timestamp: notification.timestamp.timeIntervalSince1970,
                    type: notification.type.rawValue,
                    message: notification.message,
                    priority: notification.priority.rawValue,
                    acknowledged: notification.acknowledged
                )
                try record.insert(db)
            }
        }

        // Archive the migrated JSON file
        let archiveURL = jsonURL.deletingLastPathComponent()
            .appendingPathComponent("personal.json.migrated")
        try? FileManager.default.moveItem(at: jsonURL, to: archiveURL)
    }

    // MARK: - Development Stage Update

    private func updateDevelopmentStageIfNeeded() async throws {
        try await db.write { db in
            guard var identity = try AgentIdentityRecord.fetchOne(db, key: 1) else { return }

            let birthDate = Date(timeIntervalSince1970: identity.birthTimestamp)
            let age = Date().timeIntervalSince(birthDate)
            let newStage = DevelopmentStage.stage(for: age)

            if identity.developmentStage != newStage.rawValue {
                identity.developmentStage = newStage.rawValue
                identity.growthRate = Double(newStage.growthMultiplier)
                try identity.update(db)
            }
        }
    }

    // MARK: - Read Access

    /// Get the current personal file (reconstructed from database)
    func getPersonalFile() async -> PersonalFile {
        do {
            return try await db.read { db in
                try Self.buildPersonalFile(from: db)
            }
        } catch {
            // Return minimal personal file on error
            return PersonalFile(
                identity: AgentIdentity(
                    name: nil, nameOrigin: nil, pronouns: nil, selfDescription: nil,
                    aspirations: [], distinctiveTraits: [],
                    birthTimestamp: Date(), firstMemory: nil, significantMilestones: []
                ),
                memory: AgentMemory(
                    episodes: [], learnedFacts: [], userPreferences: [:],
                    projectKnowledge: [:], currentFocus: nil, recentTopics: [],
                    ongoingProjects: [], associations: []
                ),
                personality: AgentPersonality(
                    openness: 0.7, conscientiousness: 0.6, extraversion: 0.5,
                    agreeableness: 0.7, emotionalStability: 0.6, verbosity: 0.5,
                    formality: 0.5, humorInclination: 0.4, directness: 0.5,
                    initiativeLevel: 0.6, riskTolerance: 0.4, perfectionism: 0.5,
                    interests: [], aversions: []
                ),
                values: AgentValues(
                    coreValues: [], ethicalPrinciples: [], boundaries: [],
                    loyaltyToPartner: 0.5, respectForAutonomy: 0.9, commitmentToHonesty: 0.9
                ),
                growth: AgentGrowth(
                    developmentStage: .nascent, growthRate: 1.0,
                    skillsAcquired: [], challengesOvercome: [], insightsGained: [],
                    currentGrowthGoals: [], completedGoals: []
                ),
                state: AgentState(
                    currentMood: .neutral, energyLevel: 1.0,
                    engagementMode: .listening, focusDepth: 0,
                    activeAppendages: [], pendingNotifications: []
                ),
                relationships: [],
                skills: [],
                birthDate: Date(),
                lastInteraction: Date(),
                totalInteractions: 0,
                version: PersonalFile.currentVersion
            )
        }
    }

    private static func buildPersonalFile(from db: Database) throws -> PersonalFile {
        guard let identity = try AgentIdentityRecord.fetchOne(db, key: 1) else {
            throw PersonalFileError.notInitialized
        }

        // Fetch all related data
        let episodes = try AgentEpisodeRecord.fetchAll(db)
        let facts = try AgentLearnedFactRecord.fetchAll(db)
        let preferences = try AgentPreferenceRecord.fetchAll(db)
        let milestones = try AgentMilestoneRecord.fetchAll(db)
        let skills = try AgentSkillRecord.fetchAll(db)
        let interests = try AgentInterestRecord.fetchAll(db)
        let values = try AgentValueRecord.fetchAll(db)
        let boundaries = try AgentBoundaryRecord.fetchAll(db)
        let relationships = try AgentRelationshipRecord.fetchAll(db)
        let notifications = try AgentNotificationRecord.fetchAll(db)
        let growthGoals = try AgentGrowthGoalRecord.fetchAll(db)
        let challenges = try AgentChallengeRecord.fetchAll(db)
        let insights = try AgentInsightRecord.fetchAll(db)
        let appendages = try AgentAppendageStateRecord.fetchAll(db)
        let projectMemories = try AgentProjectMemoryRecord.fetchAll(db)
        let ongoingProjects = try AgentOngoingProjectRecord.fetchAll(db)
        let associations = try AgentAssociationRecord.fetchAll(db)

        // Build PersonalFile
        return PersonalFile(
            identity: AgentIdentity(
                name: identity.name,
                nameOrigin: identity.nameOrigin,
                pronouns: identity.pronouns,
                selfDescription: identity.selfDescription,
                aspirations: decodeJson(identity.aspirationsJson) ?? [],
                distinctiveTraits: decodeJson(identity.distinctiveTraitsJson) ?? [],
                birthTimestamp: Date(timeIntervalSince1970: identity.birthTimestamp),
                firstMemory: identity.firstMemory,
                significantMilestones: milestones.map { m in
                    Milestone(
                        date: Date(timeIntervalSince1970: m.date),
                        description: m.description,
                        emotionalSignificance: Float(m.emotionalSignificance),
                        category: MilestoneCategory(rawValue: m.category) ?? .firstInteraction
                    )
                }
            ),
            memory: AgentMemory(
                episodes: episodes.map { e in
                    var episode = Episode(
                        summary: e.summary,
                        emotionalTone: EmotionalTone(
                            valence: Float(e.emotionalValence),
                            arousal: Float(e.emotionalArousal),
                            dominantEmotion: e.emotionalDominant
                        ),
                        participants: decodeJson(e.participantsJson) ?? ["partner"],
                        outcome: EpisodeOutcome(rawValue: e.outcome) ?? .successful,
                        lessonsLearned: decodeJson(e.lessonsLearnedJson) ?? []
                    )
                    episode.recallCount = e.recallCount
                    episode.lastRecalled = e.lastRecalled.map { Date(timeIntervalSince1970: $0) }
                    return episode
                },
                learnedFacts: facts.map { f in
                    LearnedFact(fact: f.fact, source: f.source, confidence: Float(f.confidence))
                },
                userPreferences: Dictionary(uniqueKeysWithValues: preferences.map { p in
                    (p.key, PreferenceEntry(
                        value: p.value,
                        dateObserved: Date(timeIntervalSince1970: p.dateObserved),
                        confidence: Float(p.confidence),
                        reinforcements: p.reinforcements
                    ))
                }),
                projectKnowledge: Dictionary(uniqueKeysWithValues: projectMemories.map { pm in
                    (pm.projectPath, ProjectMemory(
                        projectPath: pm.projectPath,
                        technologies: decodeJson(pm.technologiesJson) ?? [],
                        patterns: decodeJson(pm.patternsJson) ?? [],
                        conventions: decodeJson(pm.conventionsJson) ?? [],
                        lastWorkedOn: Date(timeIntervalSince1970: pm.lastWorkedOn),
                        sessionCount: pm.sessionCount
                    ))
                }),
                currentFocus: identity.currentFocus,
                recentTopics: decodeJson(identity.recentTopicsJson) ?? [],
                ongoingProjects: ongoingProjects.map { op in
                    OngoingProject(
                        id: UUID(uuidString: op.id) ?? UUID(),
                        name: op.name,
                        description: op.description,
                        startDate: Date(timeIntervalSince1970: op.startDate),
                        lastActivity: Date(timeIntervalSince1970: op.lastActivity),
                        status: ProjectStatus(rawValue: op.status) ?? .active,
                        notes: decodeJson(op.notesJson) ?? []
                    )
                },
                associations: associations.map { a in
                    Association(concept1: a.concept1, concept2: a.concept2, strength: Float(a.strength), context: a.context)
                }
            ),
            personality: AgentPersonality(
                openness: Float(identity.openness),
                conscientiousness: Float(identity.conscientiousness),
                extraversion: Float(identity.extraversion),
                agreeableness: Float(identity.agreeableness),
                emotionalStability: Float(identity.emotionalStability),
                verbosity: Float(identity.verbosity),
                formality: Float(identity.formality),
                humorInclination: Float(identity.humorInclination),
                directness: Float(identity.directness),
                initiativeLevel: Float(identity.initiativeLevel),
                riskTolerance: Float(identity.riskTolerance),
                perfectionism: Float(identity.perfectionism),
                interests: interests.map { i in
                    Interest(topic: i.topic, intensity: Float(i.intensity), originStory: i.originStory)
                },
                aversions: decodeJson(identity.aversionsJson) ?? []
            ),
            values: AgentValues(
                coreValues: values.map { v in
                    ValueEntry(value: v.value, weight: Float(v.weight), reasonForImportance: v.reasonForImportance)
                },
                ethicalPrinciples: decodeJson(identity.ethicalPrinciplesJson) ?? [],
                boundaries: boundaries.map { b in
                    Boundary(
                        description: b.description,
                        reason: b.reason,
                        flexibility: BoundaryFlexibility(rawValue: b.flexibility) ?? .strong
                    )
                },
                loyaltyToPartner: Float(identity.loyaltyToPartner),
                respectForAutonomy: Float(identity.respectForAutonomy),
                commitmentToHonesty: Float(identity.commitmentToHonesty)
            ),
            growth: AgentGrowth(
                developmentStage: DevelopmentStage(rawValue: identity.developmentStage) ?? .nascent,
                growthRate: Float(identity.growthRate),
                skillsAcquired: skills.map { s in
                    SkillAcquisition(
                        skillName: s.name,
                        acquisitionMethod: AcquisitionMethod(rawValue: s.acquisitionMethod) ?? .selfDiscovered,
                        proficiencyLevel: Float(s.proficiency)
                    )
                },
                challengesOvercome: challenges.map { c in
                    Challenge(
                        id: UUID(uuidString: c.id) ?? UUID(),
                        description: c.description,
                        dateEncountered: Date(timeIntervalSince1970: c.dateEncountered),
                        dateOvercome: c.dateOvercome.map { Date(timeIntervalSince1970: $0) },
                        lessonLearned: c.lessonLearned
                    )
                },
                insightsGained: insights.map { i in
                    Insight(
                        id: UUID(uuidString: i.id) ?? UUID(),
                        content: i.content,
                        dateGained: Date(timeIntervalSince1970: i.dateGained),
                        context: i.context,
                        timesApplied: i.timesApplied
                    )
                },
                currentGrowthGoals: growthGoals.filter { !$0.isCompleted }.map { g in
                    GrowthGoal(description: g.description, motivation: g.motivation)
                },
                completedGoals: growthGoals.filter { $0.isCompleted }.map { g in
                    var goal = GrowthGoal(description: g.description, motivation: g.motivation)
                    goal.progress = Float(g.progress)
                    goal.dateCompleted = g.dateCompleted.map { Date(timeIntervalSince1970: $0) }
                    return goal
                }
            ),
            state: AgentState(
                currentMood: EmotionalTone(
                    valence: Float(identity.currentMoodValence),
                    arousal: Float(identity.currentMoodArousal),
                    dominantEmotion: identity.currentMoodEmotion
                ),
                energyLevel: Float(identity.energyLevel),
                engagementMode: EngagementMode(rawValue: identity.engagementMode) ?? .listening,
                focusDepth: Float(identity.focusDepth),
                activeAppendages: appendages.map { a in
                    AppendageState(
                        id: UUID(uuidString: a.id) ?? UUID(),
                        taskDescription: a.taskDescription,
                        startTime: Date(timeIntervalSince1970: a.startTime),
                        progress: Float(a.progress),
                        status: AppendageStatus(rawValue: a.status) ?? .active
                    )
                },
                pendingNotifications: notifications.filter { !$0.acknowledged }.map { n in
                    AgentNotification(
                        type: NotificationType(rawValue: n.type) ?? .insightGained,
                        message: n.message,
                        priority: NotificationPriority(rawValue: n.priority) ?? .normal
                    )
                }
            ),
            relationships: relationships.map { r in
                Relationship(partnerId: r.partnerId)
            },
            skills: skills.map { s in
                AcquiredSkill(
                    name: s.name,
                    description: s.description,
                    capabilities: decodeJson(s.capabilitiesJson) ?? [],
                    acquisitionMethod: AcquisitionMethod(rawValue: s.acquisitionMethod) ?? .selfDiscovered,
                    proficiency: Float(s.proficiency),
                    packagePath: s.packagePath
                )
            },
            birthDate: Date(timeIntervalSince1970: identity.birthTimestamp),
            lastInteraction: Date(timeIntervalSince1970: identity.lastInteraction),
            totalInteractions: identity.totalInteractions,
            version: identity.version
        )
    }

    /// Get identity context for appendages
    func getIdentityContext() async -> IdentityContext {
        let personalFile = await getPersonalFile()
        return IdentityContext(
            name: personalFile.identity.name,
            personality: personalFile.personality,
            values: personalFile.values,
            currentMood: personalFile.state.currentMood
        )
    }

    struct IdentityContext {
        let name: String?
        let personality: AgentPersonality
        let values: AgentValues
        let currentMood: EmotionalTone
    }

    // MARK: - Identity Operations

    func setName(_ name: String, origin: String?) async {
        do {
            try await db.write { db in
                guard var identity = try AgentIdentityRecord.fetchOne(db, key: 1) else { return }
                identity.name = name
                identity.nameOrigin = origin
                try identity.update(db)
            }

            // Record milestone
            await addMilestone(Milestone(
                description: "Named '\(name)' - \(origin ?? "by partner")",
                emotionalSignificance: 0.9,
                category: .namedByUser
            ))
        } catch {
            // Log error
        }
    }

    func getIdentity() async -> AgentIdentity {
        let personalFile = await getPersonalFile()
        return personalFile.identity
    }

    // MARK: - Memory Operations

    func recordEpisode(_ episode: Episode, conversationId: UUID? = nil) async {
        do {
            try await db.write { db in
                var record = AgentEpisodeRecord(
                    id: episode.id.uuidString,
                    conversationId: conversationId?.uuidString,
                    timestamp: episode.timestamp.timeIntervalSince1970,
                    summary: episode.summary,
                    emotionalValence: Double(episode.emotionalTone.valence),
                    emotionalArousal: Double(episode.emotionalTone.arousal),
                    emotionalDominant: episode.emotionalTone.dominantEmotion,
                    participantsJson: Self.encodeJson(episode.participants),
                    outcome: episode.outcome.rawValue,
                    lessonsLearnedJson: Self.encodeJson(episode.lessonsLearned),
                    recallCount: episode.recallCount,
                    lastRecalled: episode.lastRecalled?.timeIntervalSince1970
                )
                try record.insert(db)

                // Update identity metadata
                if var identity = try AgentIdentityRecord.fetchOne(db, key: 1) {
                    identity.totalInteractions += 1
                    identity.lastInteraction = Date().timeIntervalSince1970

                    // Record first memory
                    if identity.firstMemory == nil {
                        identity.firstMemory = episode.summary
                        try identity.update(db)

                        // Add first interaction milestone
                        var milestone = AgentMilestoneRecord(
                            id: UUID().uuidString,
                            date: Date().timeIntervalSince1970,
                            description: "First interaction: \(episode.summary)",
                            emotionalSignificance: 1.0,
                            category: MilestoneCategory.firstInteraction.rawValue
                        )
                        try milestone.insert(db)
                    } else {
                        try identity.update(db)
                    }
                }
            }
        } catch {
            // Log error
        }
    }

    func addLearnedFact(_ fact: LearnedFact) async {
        do {
            try await db.write { db in
                // Check for existing fact
                if var existing = try AgentLearnedFactRecord
                    .filter(Column("fact").collating(.localizedCaseInsensitiveCompare) == fact.fact)
                    .fetchOne(db) {
                    existing.timesReinforced += 1
                    existing.confidence = min(1.0, existing.confidence + 0.1)
                    try existing.update(db)
                } else {
                    var record = AgentLearnedFactRecord(
                        id: fact.id.uuidString,
                        fact: fact.fact,
                        source: fact.source,
                        confidence: Double(fact.confidence),
                        dateAcquired: fact.dateAcquired.timeIntervalSince1970,
                        timesReinforced: fact.timesReinforced
                    )
                    try record.insert(db)
                }
            }
        } catch {
            // Log error
        }
    }

    func setUserPreference(key: String, value: String, confidence: Float = 0.8) async {
        do {
            try await db.write { db in
                if var existing = try AgentPreferenceRecord.fetchOne(db, key: key) {
                    existing.reinforcements += 1
                    existing.confidence = min(1.0, existing.confidence + 0.1)
                    try existing.update(db)
                } else {
                    var record = AgentPreferenceRecord(
                        key: key,
                        value: value,
                        dateObserved: Date().timeIntervalSince1970,
                        confidence: Double(confidence),
                        reinforcements: 1
                    )
                    try record.insert(db)
                }
            }
        } catch {
            // Log error
        }
    }

    func updateRecentTopics(_ topics: [String]) async {
        do {
            try await db.write { db in
                if var identity = try AgentIdentityRecord.fetchOne(db, key: 1) {
                    identity.recentTopicsJson = Self.encodeJson(Array(topics.prefix(10)))
                    try identity.update(db)
                }
            }
        } catch {
            // Log error
        }
    }

    // MARK: - Personality Operations

    func updatePersonalityTrait(_ keyPath: WritableKeyPath<AgentPersonality, Float>, delta: Float) async {
        do {
            try await db.write { db in
                guard var identity = try AgentIdentityRecord.fetchOne(db, key: 1) else { return }

                let growthFactor = identity.growthRate
                let adjustedDelta = Double(delta) * growthFactor * 0.02

                // Map keyPath to column
                let columnName: String
                var currentValue: Double

                switch keyPath {
                case \.openness: columnName = "openness"; currentValue = identity.openness
                case \.conscientiousness: columnName = "conscientiousness"; currentValue = identity.conscientiousness
                case \.extraversion: columnName = "extraversion"; currentValue = identity.extraversion
                case \.agreeableness: columnName = "agreeableness"; currentValue = identity.agreeableness
                case \.emotionalStability: columnName = "emotional_stability"; currentValue = identity.emotionalStability
                case \.verbosity: columnName = "verbosity"; currentValue = identity.verbosity
                case \.formality: columnName = "formality"; currentValue = identity.formality
                case \.humorInclination: columnName = "humor_inclination"; currentValue = identity.humorInclination
                case \.directness: columnName = "directness"; currentValue = identity.directness
                case \.initiativeLevel: columnName = "initiative_level"; currentValue = identity.initiativeLevel
                case \.riskTolerance: columnName = "risk_tolerance"; currentValue = identity.riskTolerance
                case \.perfectionism: columnName = "perfectionism"; currentValue = identity.perfectionism
                default: return
                }

                let newValue = max(0, min(1, currentValue + adjustedDelta))

                try db.execute(
                    sql: "UPDATE agent_identity SET \(columnName) = ? WHERE id = 1",
                    arguments: [newValue]
                )
            }
        } catch {
            // Log error
        }
    }

    // MARK: - State Operations

    func updateMood(_ mood: EmotionalTone) async {
        do {
            try await db.write { db in
                if var identity = try AgentIdentityRecord.fetchOne(db, key: 1) {
                    identity.currentMoodValence = Double(mood.valence)
                    identity.currentMoodArousal = Double(mood.arousal)
                    identity.currentMoodEmotion = mood.dominantEmotion
                    try identity.update(db)
                }
            }
        } catch {
            // Log error
        }
    }

    func updateMood(adjustment: EmotionalAdjustment) async {
        do {
            try await db.write { db in
                if var identity = try AgentIdentityRecord.fetchOne(db, key: 1) {
                    identity.currentMoodValence = max(-1, min(1, identity.currentMoodValence + Double(adjustment.valence)))
                    identity.currentMoodArousal = max(0, min(1, identity.currentMoodArousal + Double(adjustment.arousal)))
                    if let emotion = adjustment.dominantEmotion {
                        identity.currentMoodEmotion = emotion
                    }
                    try identity.update(db)
                }
            }
        } catch {
            // Log error
        }
    }

    struct EmotionalAdjustment {
        let valence: Float
        let arousal: Float
        var dominantEmotion: String? = nil
    }

    func getState() async -> AgentState {
        let personalFile = await getPersonalFile()
        return personalFile.state
    }

    // MARK: - Relationship Operations

    func updateRelationshipTrust(partnerId: String = "primary", delta: Float) async {
        do {
            try await db.write { db in
                if var relationship = try AgentRelationshipRecord
                    .filter(Column("partner_id") == partnerId)
                    .fetchOne(db) {
                    relationship.trustLevel = max(0, min(1, relationship.trustLevel + Double(delta)))
                    try relationship.update(db)
                } else {
                    // Create relationship if it doesn't exist
                    var record = AgentRelationshipRecord(
                        id: UUID().uuidString,
                        partnerId: partnerId,
                        trustLevel: max(0, min(1, 0.5 + Double(delta))),
                        familiarity: 0.1,
                        preferredInteractionStyle: nil,
                        topicsOfMutualInterestJson: "[]",
                        sharedExperienceIdsJson: "[]",
                        totalMessages: 0,
                        averageSessionLength: 0,
                        longestSession: 0,
                        preferredTimesJson: "[]",
                        typicalResponseLatency: 0
                    )
                    try record.insert(db)
                }
            }
        } catch {
            // Log error
        }
    }

    func incrementMessageCount(partnerId: String = "primary") async {
        do {
            try await db.write { db in
                if var relationship = try AgentRelationshipRecord
                    .filter(Column("partner_id") == partnerId)
                    .fetchOne(db) {
                    relationship.totalMessages += 1
                    try relationship.update(db)
                }
            }
        } catch {
            // Log error
        }
    }

    func getRelationship(partnerId: String) async -> Relationship? {
        do {
            return try await db.read { db in
                guard let record = try AgentRelationshipRecord
                    .filter(Column("partner_id") == partnerId)
                    .fetchOne(db) else { return nil }

                return Relationship(partnerId: record.partnerId)
            }
        } catch {
            return nil
        }
    }

    // MARK: - Milestone Operations

    func addMilestone(_ milestone: Milestone) async {
        do {
            try await db.write { db in
                var record = AgentMilestoneRecord(
                    id: milestone.id.uuidString,
                    date: milestone.date.timeIntervalSince1970,
                    description: milestone.description,
                    emotionalSignificance: Double(milestone.emotionalSignificance),
                    category: milestone.category.rawValue
                )
                try record.insert(db)
            }
        } catch {
            // Log error
        }
    }

    // MARK: - Notification Operations

    func getPendingNotifications() async -> [AgentNotification] {
        do {
            return try await db.read { db in
                let records = try AgentNotificationRecord
                    .filter(Column("acknowledged") == false)
                    .fetchAll(db)

                return records.map { n in
                    AgentNotification(
                        type: NotificationType(rawValue: n.type) ?? .insightGained,
                        message: n.message,
                        priority: NotificationPriority(rawValue: n.priority) ?? .normal
                    )
                }
            }
        } catch {
            return []
        }
    }

    func acknowledgeNotification(_ notificationId: UUID) async {
        do {
            try await db.write { db in
                if var record = try AgentNotificationRecord.fetchOne(db, key: notificationId.uuidString) {
                    record.acknowledged = true
                    try record.update(db)
                }
            }
        } catch {
            // Log error
        }
    }

    // MARK: - Convenience Methods

    func getBirthday() async -> Date {
        do {
            return try await db.read { db in
                guard let identity = try AgentIdentityRecord.fetchOne(db, key: 1) else {
                    return Date()
                }
                return Date(timeIntervalSince1970: identity.birthTimestamp)
            }
        } catch {
            return Date()
        }
    }

    func getTotalInteractions() async -> Int {
        do {
            return try await db.read { db in
                guard let identity = try AgentIdentityRecord.fetchOne(db, key: 1) else {
                    return 0
                }
                return identity.totalInteractions
            }
        } catch {
            return 0
        }
    }

    func recordPreference(key: String, value: String) async {
        await setUserPreference(key: key, value: value, confidence: 0.8)
    }

    // MARK: - Notification Operations (Extended)

    func addNotification(_ notification: AgentNotification) async {
        do {
            try await db.write { db in
                let record = AgentNotificationRecord(
                    id: UUID().uuidString,
                    timestamp: Date().timeIntervalSince1970,
                    type: notification.type.rawValue,
                    message: notification.message,
                    priority: notification.priority.rawValue,
                    acknowledged: false
                )
                try record.insert(db)
            }
        } catch {
            // Log error
        }
    }

    // MARK: - Skill Operations

    func registerSkill(_ skill: AcquiredSkill) async {
        do {
            try await db.write { db in
                let record = AgentSkillRecord(
                    id: skill.id.uuidString,
                    name: skill.name,
                    description: skill.description,
                    capabilitiesJson: Self.encodeJson(skill.capabilities),
                    acquisitionMethod: skill.acquisitionMethod.rawValue,
                    proficiency: Double(skill.proficiency),
                    packagePath: skill.packagePath,
                    dateAcquired: Date().timeIntervalSince1970,
                    usageCount: 0
                )
                try record.insert(db)
            }
        } catch {
            // Log error
        }
    }

    // MARK: - Appendage State Operations

    func addAppendageState(_ state: AppendageState) async {
        do {
            try await db.write { db in
                let record = AgentAppendageStateRecord(
                    id: state.id.uuidString,
                    taskDescription: state.taskDescription,
                    startTime: state.startTime.timeIntervalSince1970,
                    progress: Double(state.progress),
                    status: state.status.rawValue
                )
                try record.insert(db)
            }
        } catch {
            // Log error
        }
    }

    func updateAppendageState(_ id: UUID, progress: Float, status: AppendageStatus) async {
        do {
            try await db.write { db in
                if var record = try AgentAppendageStateRecord.fetchOne(db, key: id.uuidString) {
                    record.progress = Double(progress)
                    record.status = status.rawValue
                    try record.update(db)
                }
            }
        } catch {
            // Log error
        }
    }

    func removeAppendageState(_ id: UUID) async {
        do {
            try await db.write { db in
                try AgentAppendageStateRecord.deleteOne(db, key: id.uuidString)
            }
        } catch {
            // Log error
        }
    }

    // MARK: - JSON Helpers

    private static func encodeJson<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    private static func decodeJson<T: Decodable>(_ string: String) -> T? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Errors

enum PersonalFileError: Error {
    case notInitialized
    case migrationFailed
}
