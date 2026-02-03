import Foundation
import GRDB

// MARK: - Migration Service
// Migrates data from SQLite + JSON to PostgreSQL

actor MigrationService {
    private let postgres: PostgresManager
    private let conversationRepo: PGConversationRepository
    private let agentRepo: PGAgentRepository

    init(postgres: PostgresManager = .shared) {
        self.postgres = postgres
        self.conversationRepo = PGConversationRepository(db: postgres)
        self.agentRepo = PGAgentRepository(db: postgres)
    }

    // MARK: - Full Migration

    func migrateAll(progress: ((String, Double) -> Void)? = nil) async throws {
        progress?("Running PostgreSQL schema migrations...", 0.0)
        try await postgres.runMigrations()

        progress?("Migrating conversations and messages...", 0.1)
        try await migrateConversations(progress: progress)

        progress?("Migrating agent identity...", 0.7)
        try await migrateAgentFromJSON()

        progress?("Migration complete!", 1.0)
        Task { @MainActor in
            AppLogger.shared.log("Full migration to PostgreSQL completed", level: .info)
        }
    }

    // MARK: - Conversation Migration

    private func migrateConversations(progress: ((String, Double) -> Void)?) async throws {
        let sqliteDB = DatabaseManager.shared.dbQueue

        // Fetch all conversations from SQLite
        let conversations = try await sqliteDB.read { db -> [ConversationRecord] in
            try ConversationRecord.fetchAll(db)
        }

        let total = Double(conversations.count)
        for (index, record) in conversations.enumerated() {
            let progressValue = 0.1 + (0.5 * Double(index) / max(total, 1))
            progress?("Migrating conversation \(index + 1) of \(conversations.count)...", progressValue)

            // Convert to domain model then to PostgreSQL
            let conversation = record.asModel()
            try await conversationRepo.save(conversation)

            // Migrate messages for this conversation
            let messages = try await sqliteDB.read { db -> [MessageRecord] in
                try MessageRecord
                    .filter(Column("conversation_id") == record.id)
                    .order(Column("created_at").asc)
                    .fetchAll(db)
            }

            for messageRecord in messages {
                // Load attachments from SQLite
                let attachmentRecords = try await sqliteDB.read { db -> [AttachmentRecord] in
                    try AttachmentRecord
                        .filter(Column("message_id") == messageRecord.id)
                        .fetchAll(db)
                }

                // Convert message with attachments
                let message = messageRecord.asModel(attachments: attachmentRecords)
                try await conversationRepo.saveMessage(message)
            }

            // Migrate tool runs
            let toolRuns = try await sqliteDB.read { db -> [ToolRunRecord] in
                try ToolRunRecord
                    .filter(Column("conversation_id") == record.id)
                    .fetchAll(db)
            }

            for toolRun in toolRuns {
                try await conversationRepo.saveToolRun(
                    conversationId: UUID(uuidString: toolRun.conversationId)!,
                    messageId: toolRun.messageId.flatMap { UUID(uuidString: $0) },
                    toolName: toolRun.toolName,
                    serverId: toolRun.toolServerId,
                    serverName: toolRun.toolServerName,
                    inputJson: toolRun.inputJson,
                    outputJson: toolRun.outputJson,
                    isError: toolRun.isError,
                    durationMs: nil
                )
            }
        }

        // Migrate folders
        progress?("Migrating folders...", 0.6)
        let folders = try await sqliteDB.read { db -> [FolderRecord] in
            try FolderRecord.fetchAll(db)
        }

        for folder in folders {
            let folderId = UUID(uuidString: folder.id) ?? UUID()
            let parentIdValue = folder.parentId.flatMap { UUID(uuidString: $0) }.map { "'\($0.uuidString)'" } ?? "NULL"
            let colorValue = folder.color.map { "'\($0.replacingOccurrences(of: "'", with: "''"))'" } ?? "NULL"

            let sql = """
                INSERT INTO folders (id, name, color, parent_id, created_at)
                VALUES (
                    '\(folderId.uuidString)',
                    '\(folder.name.replacingOccurrences(of: "'", with: "''"))',
                    \(colorValue),
                    \(parentIdValue)::UUID,
                    '\(ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: folder.createdAt)))'
                )
                ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, color = EXCLUDED.color
            """
            try await postgres.execute(sql)
        }

        // Migrate projects
        progress?("Migrating projects...", 0.65)
        let projects = try await sqliteDB.read { db -> [ProjectRecord] in
            try ProjectRecord.fetchAll(db)
        }

        for project in projects {
            let projectId = UUID(uuidString: project.id) ?? UUID()
            let iconNameValue = project.iconName.map { "'\($0.replacingOccurrences(of: "'", with: "''"))'" } ?? "NULL"
            let colorValue = project.color.map { "'\($0.replacingOccurrences(of: "'", with: "''"))'" } ?? "NULL"

            let sql = """
                INSERT INTO projects (id, name, description, icon_name, color, is_archived, created_at, updated_at)
                VALUES (
                    '\(projectId.uuidString)',
                    '\(project.name.replacingOccurrences(of: "'", with: "''"))',
                    NULL,
                    \(iconNameValue),
                    \(colorValue),
                    \(project.isArchived),
                    '\(ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: project.createdAt)))',
                    '\(ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: project.updatedAt)))'
                )
                ON CONFLICT (id) DO UPDATE SET
                    name = EXCLUDED.name,
                    description = EXCLUDED.description,
                    icon_name = EXCLUDED.icon_name,
                    color = EXCLUDED.color,
                    is_archived = EXCLUDED.is_archived,
                    updated_at = EXCLUDED.updated_at
            """
            try await postgres.execute(sql)
        }
    }

    // MARK: - Agent Migration from JSON

    private func migrateAgentFromJSON() async throws {
        let personalFilePath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".vaizor/agent/personal.json")

        guard FileManager.default.fileExists(atPath: personalFilePath.path) else {
            Task { @MainActor in
                AppLogger.shared.log("No existing agent personal file to migrate", level: .info)
            }
            return
        }

        let data = try Data(contentsOf: personalFilePath)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let personalFile = try decoder.decode(PersonalFile.self, from: data)

        // Create agent identity
        let agentId = UUID()
        let identity = AgentIdentityEntity(
            id: agentId,
            name: personalFile.identity.name,
            nameOrigin: personalFile.identity.nameOrigin,
            pronouns: personalFile.identity.pronouns ?? "they/them",
            selfDescription: personalFile.identity.selfDescription,
            birthTimestamp: personalFile.identity.birthTimestamp,
            firstMemory: personalFile.identity.firstMemory,
            developmentStage: personalFile.growth.developmentStage.rawValue,
            totalInteractions: personalFile.totalInteractions,
            lastInteraction: personalFile.lastInteraction
        )
        try await agentRepo.saveIdentity(identity)

        // Migrate personality
        let personality = AgentPersonalityEntity(
            agentId: agentId,
            openness: personalFile.personality.openness,
            conscientiousness: personalFile.personality.conscientiousness,
            extraversion: personalFile.personality.extraversion,
            agreeableness: personalFile.personality.agreeableness,
            emotionalStability: personalFile.personality.emotionalStability,
            verbosity: personalFile.personality.verbosity,
            formality: personalFile.personality.formality,
            humorInclination: personalFile.personality.humorInclination,
            directness: personalFile.personality.directness,
            initiativeLevel: personalFile.personality.initiativeLevel,
            riskTolerance: personalFile.personality.riskTolerance,
            perfectionism: personalFile.personality.perfectionism,
            growthRate: personalFile.growth.growthRate
        )
        try await agentRepo.savePersonality(personality)

        // Migrate state
        let state = AgentStateEntity(
            agentId: agentId,
            moodValence: personalFile.state.currentMood.valence,
            moodArousal: personalFile.state.currentMood.arousal,
            moodEmotion: personalFile.state.currentMood.dominantEmotion,
            energyLevel: personalFile.state.energyLevel,
            engagementMode: personalFile.state.engagementMode.rawValue,
            focusDepth: personalFile.state.focusDepth,
            currentFocus: personalFile.memory.currentFocus
        )
        try await agentRepo.saveState(state)

        // Migrate milestones
        for milestone in personalFile.identity.significantMilestones {
            let entity = AgentMilestoneEntity(
                id: milestone.id,
                agentId: agentId,
                description: milestone.description,
                category: milestone.category.rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1_$2", options: .regularExpression).lowercased(),
                emotionalSignificance: milestone.emotionalSignificance,
                conversationId: nil,
                createdAt: milestone.date
            )
            try await agentRepo.saveMilestone(entity)
        }

        // Migrate episodes
        for episode in personalFile.memory.episodes {
            let entity = AgentEpisodeEntity(
                id: episode.id,
                agentId: agentId,
                conversationId: nil,
                summary: episode.summary,
                emotionalValence: episode.emotionalTone.valence,
                emotionalArousal: episode.emotionalTone.arousal,
                dominantEmotion: episode.emotionalTone.dominantEmotion,
                outcome: episode.outcome.rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1_$2", options: .regularExpression).lowercased(),
                lessonsLearned: episode.lessonsLearned,
                recallCount: episode.recallCount,
                lastRecalled: episode.lastRecalled,
                importance: 0.5,
                createdAt: episode.timestamp
            )
            try await agentRepo.saveEpisode(entity)
        }

        // Migrate learned facts (encrypted)
        for fact in personalFile.memory.learnedFacts {
            try await agentRepo.saveLearnedFact(
                agentId: agentId,
                fact: fact.fact,
                source: fact.source,
                conversationId: nil,
                confidence: fact.confidence
            )
        }

        // Migrate user preferences (encrypted)
        for (key, pref) in personalFile.memory.userPreferences {
            try await agentRepo.saveUserPreference(
                agentId: agentId,
                key: key,
                value: pref.value,
                confidence: pref.confidence
            )
        }

        // Migrate relationships
        for relationship in personalFile.relationships {
            let entity = AgentRelationshipEntity(
                agentId: agentId,
                partnerId: relationship.partnerId,
                trustLevel: relationship.trustLevel,
                familiarity: relationship.familiarity,
                totalMessages: relationship.communicationHistory.totalMessages,
                avgSessionLengthSec: Int(relationship.communicationHistory.averageSessionLength),
                longestSessionSec: Int(relationship.communicationHistory.longestSession),
                preferredHours: relationship.communicationHistory.preferredTimes,
                preferredStyle: relationship.preferredInteractionStyle
            )
            try await agentRepo.saveRelationship(entity)

            // Migrate shared interests
            for topic in relationship.topicsOfMutualInterest {
                let interestId = UUID()
                let sql = """
                    INSERT INTO agent_shared_interests (id, relationship_id, topic, created_at)
                    VALUES (
                        '\(interestId.uuidString)',
                        '\(entity.id.uuidString)',
                        '\(topic.replacingOccurrences(of: "'", with: "''"))',
                        NOW()
                    )
                    ON CONFLICT (relationship_id, topic) DO NOTHING
                """
                try await postgres.execute(sql)
            }
        }

        // Migrate skills
        for skill in personalFile.skills {
            let entity = AgentSkillEntity(
                id: skill.id,
                agentId: agentId,
                name: skill.name,
                description: skill.description,
                capabilities: skill.capabilities,
                acquisitionMethod: skill.acquisitionMethod.rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1_$2", options: .regularExpression).lowercased(),
                proficiency: skill.proficiency,
                usageCount: 0,
                packagePath: skill.packagePath,
                acquiredAt: Date(),
                lastUsed: nil
            )
            try await agentRepo.saveSkill(entity)
        }

        // Migrate interests
        for interest in personalFile.personality.interests {
            try await agentRepo.addInterest(
                agentId: agentId,
                topic: interest.topic,
                intensity: interest.intensity,
                originStory: interest.originStory
            )
        }

        // Migrate recent topics
        for topic in personalFile.memory.recentTopics {
            try await agentRepo.addRecentTopic(agentId: agentId, topic: topic)
        }

        // Migrate values
        for value in personalFile.values.coreValues {
            let valueId = value.id
            let sql = """
                INSERT INTO agent_values (id, agent_id, value_name, weight, reason_for_importance, created_at)
                VALUES (
                    '\(valueId.uuidString)',
                    '\(agentId.uuidString)',
                    '\(value.value.replacingOccurrences(of: "'", with: "''"))',
                    \(value.weight),
                    '\(value.reasonForImportance.replacingOccurrences(of: "'", with: "''"))',
                    NOW()
                )
                ON CONFLICT (agent_id, value_name) DO UPDATE SET weight = EXCLUDED.weight
            """
            try await postgres.execute(sql)
        }

        // Migrate boundaries
        for boundary in personalFile.values.boundaries {
            let boundaryId = boundary.id
            let sql = """
                INSERT INTO agent_boundaries (id, agent_id, description, reason, flexibility, created_at)
                VALUES (
                    '\(boundaryId.uuidString)',
                    '\(agentId.uuidString)',
                    '\(boundary.description.replacingOccurrences(of: "'", with: "''"))',
                    '\(boundary.reason.replacingOccurrences(of: "'", with: "''"))',
                    '\(boundary.flexibility.rawValue)',
                    NOW()
                )
            """
            try await postgres.execute(sql)
        }

        // Migrate ethical principles
        for principle in personalFile.values.ethicalPrinciples {
            let principleId = UUID()
            let sql = """
                INSERT INTO agent_ethical_principles (id, agent_id, principle, created_at)
                VALUES (
                    '\(principleId.uuidString)',
                    '\(agentId.uuidString)',
                    '\(principle.replacingOccurrences(of: "'", with: "''"))',
                    NOW()
                )
            """
            try await postgres.execute(sql)
        }

        Task { @MainActor in
            AppLogger.shared.log("Agent personal file migrated to PostgreSQL", level: .info)
        }

        // Rename old file to backup
        let backupPath = personalFilePath.deletingPathExtension().appendingPathExtension("json.migrated")
        try FileManager.default.moveItem(at: personalFilePath, to: backupPath)
    }

    // MARK: - Verify Migration

    func verifyMigration() async throws -> MigrationVerificationResult {
        var result = MigrationVerificationResult()

        // Check conversations count
        let pgConvResult = try await postgres.query("SELECT COUNT(*) as count FROM conversations")
        let pgConvRows = try await pgConvResult.collect()
        result.postgresConversations = try pgConvRows.first?.makeRandomAccess()["count"].decode(Int.self, context: .default) ?? 0

        let sqliteConvCount = try await DatabaseManager.shared.dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM conversations") ?? 0
        }
        result.sqliteConversations = sqliteConvCount

        // Check messages count
        let pgMsgResult = try await postgres.query("SELECT COUNT(*) as count FROM messages")
        let pgMsgRows = try await pgMsgResult.collect()
        result.postgresMessages = try pgMsgRows.first?.makeRandomAccess()["count"].decode(Int.self, context: .default) ?? 0

        let sqliteMsgCount = try await DatabaseManager.shared.dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM messages") ?? 0
        }
        result.sqliteMessages = sqliteMsgCount

        // Check agent exists
        let agentResult = try await postgres.query("SELECT COUNT(*) as count FROM agent_identity")
        let agentRows = try await agentResult.collect()
        result.agentExists = (try agentRows.first?.makeRandomAccess()["count"].decode(Int.self, context: .default) ?? 0) > 0

        return result
    }
}

struct MigrationVerificationResult {
    var postgresConversations: Int = 0
    var sqliteConversations: Int = 0
    var postgresMessages: Int = 0
    var sqliteMessages: Int = 0
    var agentExists: Bool = false

    var conversationsMatch: Bool { postgresConversations == sqliteConversations }
    var messagesMatch: Bool { postgresMessages == sqliteMessages }
    var isValid: Bool { conversationsMatch && messagesMatch && agentExists }

    var summary: String {
        """
        Migration Verification:
        - Conversations: \(postgresConversations)/\(sqliteConversations) \(conversationsMatch ? "✓" : "✗")
        - Messages: \(postgresMessages)/\(sqliteMessages) \(messagesMatch ? "✓" : "✗")
        - Agent: \(agentExists ? "✓" : "✗")
        - Overall: \(isValid ? "VALID" : "INCOMPLETE")
        """
    }
}
