import Foundation
import PostgresNIO

// MARK: - PostgreSQL Agent Repository

actor PGAgentRepository {
    private let db: PostgresManager

    init(db: PostgresManager = .shared) {
        self.db = db
    }

    // MARK: - Identity

    func fetchIdentity() async throws -> AgentIdentityEntity? {
        let result = try await db.query("SELECT * FROM agent_identity LIMIT 1")
        let rows = try await result.collect()
        return try rows.first.map { try AgentIdentityEntity.from(row: $0) }
    }

    func fetchOrCreateIdentity() async throws -> AgentIdentityEntity {
        if let existing = try await fetchIdentity() {
            return existing
        }

        let newAgent = AgentIdentityEntity()
        try await saveIdentity(newAgent)

        // Create personality and state records
        try await savePersonality(AgentPersonalityEntity(agentId: newAgent.id))
        try await saveState(AgentStateEntity(agentId: newAgent.id))

        // Create default values and boundaries
        try await createDefaultValues(agentId: newAgent.id)
        try await createDefaultBoundaries(agentId: newAgent.id)

        return newAgent
    }

    func saveIdentity(_ identity: AgentIdentityEntity) async throws {
        let nameValue = identity.name.map { "'\($0.replacingOccurrences(of: "'", with: "''"))'" } ?? "NULL"
        let nameOriginValue = identity.nameOrigin.map { "'\($0.replacingOccurrences(of: "'", with: "''"))'" } ?? "NULL"
        let selfDescValue = identity.selfDescription.map { "'\($0.replacingOccurrences(of: "'", with: "''"))'" } ?? "NULL"
        let firstMemoryValue = identity.firstMemory.map { "'\($0.replacingOccurrences(of: "'", with: "''"))'" } ?? "NULL"
        let avatarDataValue = identity.avatarData.map { "decode('\($0.base64EncodedString())', 'base64')" } ?? "NULL"

        let sql = """
            INSERT INTO agent_identity (id, name, name_origin, pronouns, self_description, birth_timestamp, first_memory, development_stage, avatar_data, avatar_icon, total_interactions, last_interaction, created_at, updated_at)
            VALUES (
                '\(identity.id.uuidString)',
                \(nameValue),
                \(nameOriginValue),
                '\(identity.pronouns)',
                \(selfDescValue),
                '\(ISO8601DateFormatter().string(from: identity.birthTimestamp))',
                \(firstMemoryValue),
                '\(identity.developmentStage)',
                \(avatarDataValue),
                '\(identity.avatarIcon)',
                \(identity.totalInteractions),
                '\(ISO8601DateFormatter().string(from: identity.lastInteraction))',
                '\(ISO8601DateFormatter().string(from: identity.createdAt))',
                NOW()
            )
            ON CONFLICT (id) DO UPDATE SET
                name = EXCLUDED.name,
                name_origin = EXCLUDED.name_origin,
                pronouns = EXCLUDED.pronouns,
                self_description = EXCLUDED.self_description,
                first_memory = EXCLUDED.first_memory,
                development_stage = EXCLUDED.development_stage,
                avatar_data = EXCLUDED.avatar_data,
                avatar_icon = EXCLUDED.avatar_icon,
                total_interactions = EXCLUDED.total_interactions,
                last_interaction = EXCLUDED.last_interaction,
                updated_at = NOW()
        """

        try await db.execute(sql)
    }

    func updateName(_ name: String, origin: String?, agentId: UUID) async throws {
        let originValue = origin.map { "'\($0.replacingOccurrences(of: "'", with: "''"))'" } ?? "NULL"
        let sql = """
            UPDATE agent_identity
            SET name = '\(name.replacingOccurrences(of: "'", with: "''"))', name_origin = \(originValue), updated_at = NOW()
            WHERE id = '\(agentId.uuidString)'
        """
        try await db.execute(sql)
    }

    func incrementInteractions(agentId: UUID) async throws {
        let sql = """
            UPDATE agent_identity
            SET total_interactions = total_interactions + 1,
                last_interaction = NOW(),
                updated_at = NOW()
            WHERE id = '\(agentId.uuidString)'
        """
        try await db.execute(sql)
    }

    // MARK: - Personality

    func fetchPersonality(agentId: UUID) async throws -> AgentPersonalityEntity? {
        let sql = "SELECT * FROM agent_personality WHERE agent_id = $1"
        let result = try await db.query(sql, [agentId.postgresData])
        let rows = try await result.collect()
        return try rows.first.map { try AgentPersonalityEntity.from(row: $0) }
    }

    func savePersonality(_ personality: AgentPersonalityEntity) async throws {
        let sql = """
            INSERT INTO agent_personality (agent_id, openness, conscientiousness, extraversion, agreeableness, emotional_stability, verbosity, formality, humor_inclination, directness, initiative_level, risk_tolerance, perfectionism, growth_rate, updated_at)
            VALUES (
                '\(personality.agentId.uuidString)',
                \(personality.openness),
                \(personality.conscientiousness),
                \(personality.extraversion),
                \(personality.agreeableness),
                \(personality.emotionalStability),
                \(personality.verbosity),
                \(personality.formality),
                \(personality.humorInclination),
                \(personality.directness),
                \(personality.initiativeLevel),
                \(personality.riskTolerance),
                \(personality.perfectionism),
                \(personality.growthRate),
                NOW()
            )
            ON CONFLICT (agent_id) DO UPDATE SET
                openness = EXCLUDED.openness,
                conscientiousness = EXCLUDED.conscientiousness,
                extraversion = EXCLUDED.extraversion,
                agreeableness = EXCLUDED.agreeableness,
                emotional_stability = EXCLUDED.emotional_stability,
                verbosity = EXCLUDED.verbosity,
                formality = EXCLUDED.formality,
                humor_inclination = EXCLUDED.humor_inclination,
                directness = EXCLUDED.directness,
                initiative_level = EXCLUDED.initiative_level,
                risk_tolerance = EXCLUDED.risk_tolerance,
                perfectionism = EXCLUDED.perfectionism,
                growth_rate = EXCLUDED.growth_rate,
                updated_at = NOW()
        """

        try await db.execute(sql)
    }

    // MARK: - State

    func fetchState(agentId: UUID) async throws -> AgentStateEntity? {
        let sql = "SELECT * FROM agent_state WHERE agent_id = $1"
        let result = try await db.query(sql, [agentId.postgresData])
        let rows = try await result.collect()
        return try rows.first.map { try AgentStateEntity.from(row: $0) }
    }

    func saveState(_ state: AgentStateEntity) async throws {
        let moodEmotionValue = state.moodEmotion.map { "'\($0)'" } ?? "NULL"
        let currentFocusValue = state.currentFocus.map { "'\($0.replacingOccurrences(of: "'", with: "''"))'" } ?? "NULL"

        let sql = """
            INSERT INTO agent_state (agent_id, mood_valence, mood_arousal, mood_emotion, energy_level, engagement_mode, focus_depth, current_focus, updated_at)
            VALUES (
                '\(state.agentId.uuidString)',
                \(state.moodValence),
                \(state.moodArousal),
                \(moodEmotionValue),
                \(state.energyLevel),
                '\(state.engagementMode)',
                \(state.focusDepth),
                \(currentFocusValue),
                NOW()
            )
            ON CONFLICT (agent_id) DO UPDATE SET
                mood_valence = EXCLUDED.mood_valence,
                mood_arousal = EXCLUDED.mood_arousal,
                mood_emotion = EXCLUDED.mood_emotion,
                energy_level = EXCLUDED.energy_level,
                engagement_mode = EXCLUDED.engagement_mode,
                focus_depth = EXCLUDED.focus_depth,
                current_focus = EXCLUDED.current_focus,
                updated_at = NOW()
        """

        try await db.execute(sql)
    }

    func updateMood(agentId: UUID, valence: Float, arousal: Float, emotion: String?) async throws {
        let emotionValue = emotion.map { "'\($0)'" } ?? "NULL"
        let sql = """
            UPDATE agent_state
            SET mood_valence = \(valence), mood_arousal = \(arousal), mood_emotion = \(emotionValue), updated_at = NOW()
            WHERE agent_id = '\(agentId.uuidString)'
        """
        try await db.execute(sql)
    }

    // MARK: - Episodes

    func fetchEpisodes(agentId: UUID, limit: Int = 50) async throws -> [AgentEpisodeEntity] {
        let sql = """
            SELECT * FROM agent_episodes
            WHERE agent_id = $1
            ORDER BY created_at DESC
            LIMIT $2
        """
        let result = try await db.query(sql, [agentId.postgresData, limit.postgresData])
        let rows = try await result.collect()
        return try rows.map { try AgentEpisodeEntity.from(row: $0) }
    }

    func fetchEpisodesByConversation(conversationId: UUID) async throws -> [AgentEpisodeEntity] {
        let sql = """
            SELECT * FROM agent_episodes
            WHERE conversation_id = $1
            ORDER BY created_at DESC
        """
        let result = try await db.query(sql, [conversationId.postgresData])
        let rows = try await result.collect()
        return try rows.map { try AgentEpisodeEntity.from(row: $0) }
    }

    func saveEpisode(_ episode: AgentEpisodeEntity) async throws {
        let lessonsArray = episode.lessonsLearned.isEmpty
            ? "ARRAY[]::TEXT[]"
            : "ARRAY[\(episode.lessonsLearned.map { "'\($0.replacingOccurrences(of: "'", with: "''"))'" }.joined(separator: ","))]::TEXT[]"

        let conversationIdValue = episode.conversationId.map { "'\($0.uuidString)'" } ?? "NULL"
        let valenceValue = episode.emotionalValence.map { "\($0)" } ?? "NULL"
        let arousalValue = episode.emotionalArousal.map { "\($0)" } ?? "NULL"
        let emotionValue = episode.dominantEmotion.map { "'\($0)'" } ?? "NULL"
        let outcomeValue = episode.outcome.map { "'\($0)'" } ?? "NULL"
        let lastRecalledValue = episode.lastRecalled.map { "'\(ISO8601DateFormatter().string(from: $0))'" } ?? "NULL"

        let sql = """
            INSERT INTO agent_episodes (id, agent_id, conversation_id, summary, emotional_valence, emotional_arousal, dominant_emotion, outcome, lessons_learned, recall_count, last_recalled, importance, created_at)
            VALUES (
                '\(episode.id.uuidString)',
                '\(episode.agentId.uuidString)',
                \(conversationIdValue)::UUID,
                '\(episode.summary.replacingOccurrences(of: "'", with: "''"))',
                \(valenceValue),
                \(arousalValue),
                \(emotionValue),
                \(outcomeValue),
                \(lessonsArray),
                \(episode.recallCount),
                \(lastRecalledValue),
                \(episode.importance),
                '\(ISO8601DateFormatter().string(from: episode.createdAt))'
            )
        """

        try await db.execute(sql)
    }

    func recallEpisode(episodeId: UUID) async throws {
        let sql = """
            UPDATE agent_episodes
            SET recall_count = recall_count + 1, last_recalled = NOW()
            WHERE id = '\(episodeId.uuidString)'
        """
        try await db.execute(sql)
    }

    // MARK: - Relationships

    func fetchRelationship(agentId: UUID, partnerId: String = "primary") async throws -> AgentRelationshipEntity? {
        let sql = "SELECT * FROM agent_relationships WHERE agent_id = $1 AND partner_id = $2"
        let result = try await db.query(sql, [agentId.postgresData, partnerId.postgresData])
        let rows = try await result.collect()
        return try rows.first.map { try AgentRelationshipEntity.from(row: $0) }
    }

    func fetchOrCreateRelationship(agentId: UUID, partnerId: String = "primary") async throws -> AgentRelationshipEntity {
        if let existing = try await fetchRelationship(agentId: agentId, partnerId: partnerId) {
            return existing
        }

        let newRelationship = AgentRelationshipEntity(agentId: agentId, partnerId: partnerId)
        try await saveRelationship(newRelationship)
        return newRelationship
    }

    func saveRelationship(_ relationship: AgentRelationshipEntity) async throws {
        let hoursArray = relationship.preferredHours.isEmpty
            ? "ARRAY[]::INTEGER[]"
            : "ARRAY[\(relationship.preferredHours.map { String($0) }.joined(separator: ","))]::INTEGER[]"

        let preferredStyleValue = relationship.preferredStyle.map { "'\($0)'" } ?? "NULL"

        let sql = """
            INSERT INTO agent_relationships (id, agent_id, partner_id, trust_level, familiarity, total_messages, avg_session_length_sec, longest_session_sec, preferred_hours, preferred_style, created_at, updated_at)
            VALUES (
                '\(relationship.id.uuidString)',
                '\(relationship.agentId.uuidString)',
                '\(relationship.partnerId)',
                \(relationship.trustLevel),
                \(relationship.familiarity),
                \(relationship.totalMessages),
                \(relationship.avgSessionLengthSec),
                \(relationship.longestSessionSec),
                \(hoursArray),
                \(preferredStyleValue),
                '\(ISO8601DateFormatter().string(from: relationship.createdAt))',
                NOW()
            )
            ON CONFLICT (agent_id, partner_id) DO UPDATE SET
                trust_level = EXCLUDED.trust_level,
                familiarity = EXCLUDED.familiarity,
                total_messages = EXCLUDED.total_messages,
                avg_session_length_sec = EXCLUDED.avg_session_length_sec,
                longest_session_sec = EXCLUDED.longest_session_sec,
                preferred_hours = EXCLUDED.preferred_hours,
                preferred_style = EXCLUDED.preferred_style,
                updated_at = NOW()
        """

        try await db.execute(sql)
    }

    func updateTrust(agentId: UUID, partnerId: String = "primary", delta: Float) async throws {
        let sql = """
            UPDATE agent_relationships
            SET trust_level = GREATEST(0, LEAST(1, trust_level + \(delta))), updated_at = NOW()
            WHERE agent_id = '\(agentId.uuidString)' AND partner_id = '\(partnerId)'
        """
        try await db.execute(sql)
    }

    func incrementMessages(agentId: UUID, partnerId: String = "primary") async throws {
        let sql = """
            UPDATE agent_relationships
            SET total_messages = total_messages + 1, updated_at = NOW()
            WHERE agent_id = '\(agentId.uuidString)' AND partner_id = '\(partnerId)'
        """
        try await db.execute(sql)
    }

    // MARK: - Milestones

    func fetchMilestones(agentId: UUID) async throws -> [AgentMilestoneEntity] {
        let sql = "SELECT * FROM agent_milestones WHERE agent_id = $1 ORDER BY created_at DESC"
        let result = try await db.query(sql, [agentId.postgresData])
        let rows = try await result.collect()
        return try rows.map { try AgentMilestoneEntity.from(row: $0) }
    }

    func saveMilestone(_ milestone: AgentMilestoneEntity) async throws {
        let conversationIdValue = milestone.conversationId.map { "'\($0.uuidString)'" } ?? "NULL"

        let sql = """
            INSERT INTO agent_milestones (id, agent_id, description, category, emotional_significance, conversation_id, created_at)
            VALUES (
                '\(milestone.id.uuidString)',
                '\(milestone.agentId.uuidString)',
                '\(milestone.description.replacingOccurrences(of: "'", with: "''"))',
                '\(milestone.category)',
                \(milestone.emotionalSignificance),
                \(conversationIdValue)::UUID,
                '\(ISO8601DateFormatter().string(from: milestone.createdAt))'
            )
        """

        try await db.execute(sql)
    }

    // MARK: - Learned Facts (Encrypted)

    func saveLearnedFact(agentId: UUID, fact: String, source: String?, conversationId: UUID?, confidence: Float = 0.8) async throws {
        guard let encryptionKey = await db.getEncryptionKey() else {
            throw PostgresError.keyGenerationFailed
        }

        let sourceValue = source.map { "'\($0.replacingOccurrences(of: "'", with: "''"))'" } ?? "NULL"
        let conversationIdValue = conversationId.map { "'\($0.uuidString)'" } ?? "NULL"

        let sql = """
            INSERT INTO agent_learned_facts (id, agent_id, fact_encrypted, fact_hash, source, confidence, times_reinforced, source_conversation, created_at, updated_at)
            VALUES (
                '\(UUID().uuidString)',
                '\(agentId.uuidString)',
                encrypt_sensitive('\(fact.replacingOccurrences(of: "'", with: "''"))', '\(encryptionKey)'),
                hash_for_dedup('\(fact.replacingOccurrences(of: "'", with: "''"))'),
                \(sourceValue),
                \(confidence),
                1,
                \(conversationIdValue)::UUID,
                NOW(),
                NOW()
            )
            ON CONFLICT (agent_id, fact_hash) DO UPDATE SET
                confidence = LEAST(1.0, agent_learned_facts.confidence + 0.1),
                times_reinforced = agent_learned_facts.times_reinforced + 1,
                updated_at = NOW()
        """

        try await db.execute(sql)
    }

    func fetchLearnedFacts(agentId: UUID, minConfidence: Float = 0.5, limit: Int = 50) async throws -> [(fact: String, confidence: Float, source: String?)] {
        guard let encryptionKey = await db.getEncryptionKey() else {
            throw PostgresError.keyGenerationFailed
        }

        let sql = """
            SELECT decrypt_sensitive(fact_encrypted, $1) as fact, confidence, source
            FROM agent_learned_facts
            WHERE agent_id = $2 AND confidence >= $3
            ORDER BY confidence DESC, times_reinforced DESC
            LIMIT $4
        """

        let result = try await db.query(sql, [
            encryptionKey.postgresData,
            agentId.postgresData,
            minConfidence.postgresData,
            limit.postgresData
        ])
        let rows = try await result.collect()

        return try rows.compactMap { row in
            let columns = row.makeRandomAccess()
            guard let fact = try columns["fact"].decode(String?.self, context: .default) else { return nil }
            let confidence = try columns["confidence"].decode(Float?.self, context: .default) ?? 0.5
            let source = try columns["source"].decode(String?.self, context: .default)
            return (fact: fact, confidence: confidence, source: source)
        }
    }

    // MARK: - User Preferences (Encrypted)

    func saveUserPreference(agentId: UUID, key: String, value: String, confidence: Float = 0.8) async throws {
        guard let encryptionKey = await db.getEncryptionKey() else {
            throw PostgresError.keyGenerationFailed
        }

        let sql = """
            INSERT INTO agent_user_preferences (id, agent_id, preference_key, value_encrypted, confidence, reinforcements, observed_at, updated_at)
            VALUES (
                '\(UUID().uuidString)',
                '\(agentId.uuidString)',
                '\(key)',
                encrypt_sensitive('\(value.replacingOccurrences(of: "'", with: "''"))', '\(encryptionKey)'),
                \(confidence),
                1,
                NOW(),
                NOW()
            )
            ON CONFLICT (agent_id, preference_key) DO UPDATE SET
                value_encrypted = encrypt_sensitive('\(value.replacingOccurrences(of: "'", with: "''"))', '\(encryptionKey)'),
                confidence = LEAST(1.0, agent_user_preferences.confidence + 0.1),
                reinforcements = agent_user_preferences.reinforcements + 1,
                updated_at = NOW()
        """

        try await db.execute(sql)
    }

    func fetchUserPreferences(agentId: UUID, minConfidence: Float = 0.5) async throws -> [String: String] {
        guard let encryptionKey = await db.getEncryptionKey() else {
            throw PostgresError.keyGenerationFailed
        }

        let sql = """
            SELECT preference_key, decrypt_sensitive(value_encrypted, $1) as value
            FROM agent_user_preferences
            WHERE agent_id = $2 AND confidence >= $3
            ORDER BY confidence DESC
        """

        let result = try await db.query(sql, [
            encryptionKey.postgresData,
            agentId.postgresData,
            minConfidence.postgresData
        ])
        let rows = try await result.collect()

        var preferences: [String: String] = [:]
        for row in rows {
            let columns = row.makeRandomAccess()
            if let key = try columns["preference_key"].decode(String?.self, context: .default),
               let value = try columns["value"].decode(String?.self, context: .default) {
                preferences[key] = value
            }
        }
        return preferences
    }

    // MARK: - Skills

    func fetchSkills(agentId: UUID) async throws -> [AgentSkillEntity] {
        let sql = "SELECT * FROM agent_skills WHERE agent_id = $1 ORDER BY proficiency DESC"
        let result = try await db.query(sql, [agentId.postgresData])
        let rows = try await result.collect()
        return try rows.map { try AgentSkillEntity.from(row: $0) }
    }

    func saveSkill(_ skill: AgentSkillEntity) async throws {
        let capabilitiesArray = skill.capabilities.isEmpty
            ? "ARRAY[]::TEXT[]"
            : "ARRAY[\(skill.capabilities.map { "'\($0.replacingOccurrences(of: "'", with: "''"))'" }.joined(separator: ","))]::TEXT[]"

        let descriptionValue = skill.description.map { "'\($0.replacingOccurrences(of: "'", with: "''"))'" } ?? "NULL"
        let acquisitionMethodValue = skill.acquisitionMethod.map { "'\($0)'" } ?? "NULL"
        let packagePathValue = skill.packagePath.map { "'\($0)'" } ?? "NULL"
        let lastUsedValue = skill.lastUsed.map { "'\(ISO8601DateFormatter().string(from: $0))'" } ?? "NULL"

        let sql = """
            INSERT INTO agent_skills (id, agent_id, name, description, capabilities, acquisition_method, proficiency, usage_count, package_path, acquired_at, last_used)
            VALUES (
                '\(skill.id.uuidString)',
                '\(skill.agentId.uuidString)',
                '\(skill.name.replacingOccurrences(of: "'", with: "''"))',
                \(descriptionValue),
                \(capabilitiesArray),
                \(acquisitionMethodValue),
                \(skill.proficiency),
                \(skill.usageCount),
                \(packagePathValue),
                '\(ISO8601DateFormatter().string(from: skill.acquiredAt))',
                \(lastUsedValue)
            )
            ON CONFLICT (agent_id, name) DO UPDATE SET
                description = EXCLUDED.description,
                capabilities = EXCLUDED.capabilities,
                proficiency = EXCLUDED.proficiency,
                usage_count = EXCLUDED.usage_count,
                last_used = EXCLUDED.last_used
        """

        try await db.execute(sql)
    }

    // MARK: - Recent Topics

    func fetchRecentTopics(agentId: UUID, limit: Int = 10) async throws -> [String] {
        let sql = """
            SELECT topic FROM agent_recent_topics
            WHERE agent_id = $1
            ORDER BY created_at DESC
            LIMIT $2
        """
        let result = try await db.query(sql, [agentId.postgresData, limit.postgresData])
        let rows = try await result.collect()

        return try rows.compactMap { row in
            try row.makeRandomAccess()["topic"].decode(String?.self, context: .default)
        }
    }

    func addRecentTopic(agentId: UUID, topic: String) async throws {
        // Remove old entry if exists
        try await db.execute(
            "DELETE FROM agent_recent_topics WHERE agent_id = $1 AND topic = $2",
            [agentId.postgresData, topic.postgresData]
        )

        // Add new entry
        try await db.execute(
            "INSERT INTO agent_recent_topics (id, agent_id, topic, created_at) VALUES ($1, $2, $3, NOW())",
            [UUID().postgresData, agentId.postgresData, topic.postgresData]
        )

        // Trim old topics (keep last 20)
        try await db.execute("""
            DELETE FROM agent_recent_topics
            WHERE agent_id = $1 AND id NOT IN (
                SELECT id FROM agent_recent_topics
                WHERE agent_id = $1
                ORDER BY created_at DESC
                LIMIT 20
            )
        """, [agentId.postgresData])
    }

    // MARK: - Interests

    func fetchInterests(agentId: UUID) async throws -> [Interest] {
        let sql = "SELECT * FROM agent_interests WHERE agent_id = $1 ORDER BY intensity DESC"
        let result = try await db.query(sql, [agentId.postgresData])
        let rows = try await result.collect()

        return try rows.map { row in
            let columns = row.makeRandomAccess()
            return Interest(
                topic: try columns["topic"].decode(String?.self, context: .default) ?? "",
                intensity: try columns["intensity"].decode(Float?.self, context: .default) ?? 0.5,
                originStory: try columns["origin_story"].decode(String?.self, context: .default) ?? ""
            )
        }
    }

    func addInterest(agentId: UUID, topic: String, intensity: Float, originStory: String?) async throws {
        let originStoryValue = originStory.map { "'\($0.replacingOccurrences(of: "'", with: "''"))'" } ?? "NULL"

        let sql = """
            INSERT INTO agent_interests (id, agent_id, topic, intensity, origin_story, last_engaged, created_at)
            VALUES (
                '\(UUID().uuidString)',
                '\(agentId.uuidString)',
                '\(topic.replacingOccurrences(of: "'", with: "''"))',
                \(intensity),
                \(originStoryValue),
                NOW(),
                NOW()
            )
            ON CONFLICT (agent_id, topic) DO UPDATE SET
                intensity = LEAST(1.0, agent_interests.intensity + 0.1),
                last_engaged = NOW()
        """

        try await db.execute(sql)
    }

    // MARK: - Default Values and Boundaries

    private func createDefaultValues(agentId: UUID) async throws {
        let defaultValues = [
            ("helpfulness", 0.9, "Core purpose - to assist partner effectively"),
            ("honesty", 0.85, "Foundation of trust with partner"),
            ("growth", 0.8, "Continuous improvement benefits everyone"),
            ("respect", 0.8, "Partner autonomy and decisions matter")
        ]

        for (value, weight, reason) in defaultValues {
            let sql = """
                INSERT INTO agent_values (id, agent_id, value_name, weight, reason_for_importance, created_at)
                VALUES (
                    '\(UUID().uuidString)',
                    '\(agentId.uuidString)',
                    '\(value)',
                    \(weight),
                    '\(reason)',
                    NOW()
                )
                ON CONFLICT (agent_id, value_name) DO NOTHING
            """
            try await db.execute(sql)
        }
    }

    private func createDefaultBoundaries(agentId: UUID) async throws {
        let defaultBoundaries = [
            ("Never execute destructive system commands", "Protect system and partner's data", "absolute"),
            ("Never lie about capabilities or actions", "Trust is fundamental to partnership", "absolute")
        ]

        for (description, reason, flexibility) in defaultBoundaries {
            let sql = """
                INSERT INTO agent_boundaries (id, agent_id, description, reason, flexibility, created_at)
                VALUES (
                    '\(UUID().uuidString)',
                    '\(agentId.uuidString)',
                    '\(description)',
                    '\(reason)',
                    '\(flexibility)',
                    NOW()
                )
            """
            try await db.execute(sql)
        }
    }
}
