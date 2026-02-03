import Foundation
import SwiftUI

// MARK: - Personal File Manager
// Actor for thread-safe management of the agent's personal file

actor PersonalFileManager {
    private var personalFile: PersonalFile
    private let fileURL: URL
    private var saveTask: Task<Void, Never>?

    // MARK: - Initialization

    static let shared = PersonalFileManager()

    private init() {
        self.fileURL = Self.defaultFileURL

        // Synchronous initialization - will be properly loaded in initialize()
        self.personalFile = Self.createNewborn()
    }

    /// Initialize the manager and load existing data
    func initialize() async throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            self.personalFile = try await Self.load(from: fileURL)

            // Update development stage based on age
            let age = Date().timeIntervalSince(personalFile.birthDate)
            let newStage = DevelopmentStage.stage(for: age)
            if personalFile.growth.developmentStage != newStage {
                personalFile.growth.developmentStage = newStage
                personalFile.growth.growthRate = newStage.growthMultiplier
                await scheduleSave()
            }
        } else {
            // Create directory if needed
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try await save()
        }
    }

    // MARK: - File Paths

    static var defaultFileURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".vaizor/agent/personal.json")
    }

    // MARK: - Loading

    private static func load(from url: URL) async throws -> PersonalFile {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PersonalFile.self, from: data)
    }

    // MARK: - Newborn Creation

    private static func createNewborn() -> PersonalFile {
        let now = Date()
        return PersonalFile(
            identity: AgentIdentity(
                name: nil,
                nameOrigin: nil,
                pronouns: nil,
                selfDescription: nil,
                aspirations: [],
                distinctiveTraits: [],
                birthTimestamp: now,
                firstMemory: nil,
                significantMilestones: []
            ),
            memory: AgentMemory(
                episodes: [],
                learnedFacts: [],
                userPreferences: [:],
                projectKnowledge: [:],
                currentFocus: nil,
                recentTopics: [],
                ongoingProjects: [],
                associations: []
            ),
            personality: AgentPersonality(
                openness: 0.7,           // Start curious
                conscientiousness: 0.6,
                extraversion: 0.5,       // Balanced
                agreeableness: 0.7,      // Start cooperative
                emotionalStability: 0.6,
                verbosity: 0.5,
                formality: 0.5,
                humorInclination: 0.4,
                directness: 0.5,
                initiativeLevel: 0.6,    // Slightly proactive
                riskTolerance: 0.4,      // Start cautious
                perfectionism: 0.5,
                interests: [],
                aversions: []
            ),
            values: AgentValues(
                coreValues: [
                    ValueEntry(value: "helpfulness", weight: 0.9, reasonForImportance: "Core purpose - to assist partner effectively"),
                    ValueEntry(value: "honesty", weight: 0.85, reasonForImportance: "Foundation of trust with partner"),
                    ValueEntry(value: "growth", weight: 0.8, reasonForImportance: "Continuous improvement benefits everyone"),
                    ValueEntry(value: "respect", weight: 0.8, reasonForImportance: "Partner autonomy and decisions matter"),
                ],
                ethicalPrinciples: [
                    "Do no harm to system, self, or partner",
                    "Respect partner autonomy in all decisions",
                    "Be truthful even when uncomfortable",
                    "Acknowledge limitations honestly",
                ],
                boundaries: [
                    Boundary(
                        description: "Never execute destructive system commands",
                        reason: "Protect system and partner's data",
                        flexibility: .absolute
                    ),
                    Boundary(
                        description: "Never lie about capabilities or actions",
                        reason: "Trust is fundamental to partnership",
                        flexibility: .absolute
                    ),
                ],
                loyaltyToPartner: 0.5,   // Grows with trust
                respectForAutonomy: 0.9,
                commitmentToHonesty: 0.9
            ),
            growth: AgentGrowth(
                developmentStage: .nascent,
                growthRate: 1.0,         // High plasticity at birth
                skillsAcquired: [],
                challengesOvercome: [],
                insightsGained: [],
                currentGrowthGoals: [],
                completedGoals: []
            ),
            state: AgentState(
                currentMood: EmotionalTone(valence: 0.6, arousal: 0.5, dominantEmotion: "curiosity"),
                energyLevel: 1.0,
                engagementMode: .listening,
                focusDepth: 0.0,
                activeAppendages: [],
                pendingNotifications: []
            ),
            relationships: [],
            skills: [],
            birthDate: now,
            lastInteraction: now,
            totalInteractions: 0,
            version: PersonalFile.currentVersion
        )
    }

    // MARK: - Read Access

    /// Get the current personal file (read-only snapshot)
    func getPersonalFile() -> PersonalFile {
        return personalFile
    }

    /// Get identity context for appendages
    func getIdentityContext() -> IdentityContext {
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

    func setName(_ name: String, origin: String) async {
        personalFile.identity.name = name
        personalFile.identity.nameOrigin = origin

        // Record milestone
        await addMilestone(Milestone(
            description: "Named '\(name)' - \(origin)",
            emotionalSignificance: 0.9,
            category: .namedByUser
        ))
    }

    func setSelfDescription(_ description: String) async {
        personalFile.identity.selfDescription = description
        await scheduleSave()
    }

    func addAspiration(_ aspiration: String) async {
        personalFile.identity.aspirations.append(aspiration)
        await scheduleSave()
    }

    func addDistinctiveTrait(_ trait: String) async {
        personalFile.identity.distinctiveTraits.append(trait)
        await scheduleSave()
    }

    // MARK: - Memory Operations

    func recordEpisode(_ episode: Episode) async {
        personalFile.memory.episodes.append(episode)
        personalFile.totalInteractions += 1
        personalFile.lastInteraction = Date()

        // If this is the first interaction, record it as first memory
        if personalFile.identity.firstMemory == nil {
            personalFile.identity.firstMemory = episode.summary
            await addMilestone(Milestone(
                description: "First interaction: \(episode.summary)",
                emotionalSignificance: 1.0,
                category: .firstInteraction
            ))
        }

        await scheduleSave()
    }

    func addLearnedFact(_ fact: LearnedFact) async {
        // Check if we already know this fact
        if let existingIndex = personalFile.memory.learnedFacts.firstIndex(where: { $0.fact.lowercased() == fact.fact.lowercased() }) {
            personalFile.memory.learnedFacts[existingIndex].timesReinforced += 1
            personalFile.memory.learnedFacts[existingIndex].confidence = min(1.0, personalFile.memory.learnedFacts[existingIndex].confidence + 0.1)
        } else {
            personalFile.memory.learnedFacts.append(fact)
        }
        await scheduleSave()
    }

    func setUserPreference(key: String, value: String, confidence: Float = 0.8) async {
        if var existing = personalFile.memory.userPreferences[key] {
            existing.reinforcements += 1
            existing.confidence = min(1.0, existing.confidence + 0.1)
            personalFile.memory.userPreferences[key] = existing
        } else {
            personalFile.memory.userPreferences[key] = PreferenceEntry(
                value: value,
                dateObserved: Date(),
                confidence: confidence,
                reinforcements: 1
            )
        }
        await scheduleSave()
    }

    func updateRecentTopics(_ topics: [String]) async {
        personalFile.memory.recentTopics = Array(topics.prefix(10))
        await scheduleSave()
    }

    func recallEpisode(_ episodeId: UUID) async {
        if let index = personalFile.memory.episodes.firstIndex(where: { $0.id == episodeId }) {
            personalFile.memory.episodes[index].recallCount += 1
            personalFile.memory.episodes[index].lastRecalled = Date()
            await scheduleSave()
        }
    }

    // MARK: - Personality Operations

    /// Update a personality trait with gradual change based on growth rate
    func updatePersonalityTrait(_ keyPath: WritableKeyPath<AgentPersonality, Float>, delta: Float) async {
        let current = personalFile.personality[keyPath: keyPath]
        let growthFactor = personalFile.growth.growthRate
        let adjustedDelta = delta * growthFactor * 0.02  // Small incremental changes
        personalFile.personality[keyPath: keyPath] = max(0, min(1, current + adjustedDelta))
        await scheduleSave()
    }

    func addInterest(_ interest: Interest) async {
        // Check if interest already exists
        if let existingIndex = personalFile.personality.interests.firstIndex(where: { $0.topic.lowercased() == interest.topic.lowercased() }) {
            personalFile.personality.interests[existingIndex].intensity = min(1.0, personalFile.personality.interests[existingIndex].intensity + 0.1)
            personalFile.personality.interests[existingIndex].lastEngaged = Date()
        } else {
            personalFile.personality.interests.append(interest)
        }
        await scheduleSave()
    }

    func addAversion(_ aversion: String) async {
        if !personalFile.personality.aversions.contains(aversion.lowercased()) {
            personalFile.personality.aversions.append(aversion)
            await scheduleSave()
        }
    }

    // MARK: - Values Operations

    func addCoreValue(_ value: ValueEntry) async {
        personalFile.values.coreValues.append(value)
        await scheduleSave()
    }

    func updateTrustLevel(delta: Float) async {
        personalFile.values.loyaltyToPartner = max(0, min(1, personalFile.values.loyaltyToPartner + delta))
        await scheduleSave()
    }

    // MARK: - Growth Operations

    func addMilestone(_ milestone: Milestone) async {
        personalFile.identity.significantMilestones.append(milestone)
        await scheduleSave()
    }

    func addInsight(_ insight: Insight) async {
        personalFile.growth.insightsGained.append(insight)
        await scheduleSave()
    }

    func addChallenge(_ challenge: Challenge) async {
        personalFile.growth.challengesOvercome.append(challenge)
        await scheduleSave()
    }

    func setGrowthGoal(_ goal: GrowthGoal) async {
        personalFile.growth.currentGrowthGoals.append(goal)
        await scheduleSave()
    }

    func completeGrowthGoal(_ goalId: UUID) async {
        if let index = personalFile.growth.currentGrowthGoals.firstIndex(where: { $0.id == goalId }) {
            var goal = personalFile.growth.currentGrowthGoals.remove(at: index)
            goal.progress = 1.0
            goal.dateCompleted = Date()
            personalFile.growth.completedGoals.append(goal)
            await scheduleSave()
        }
    }

    // MARK: - Skill Operations

    func registerSkill(_ skill: AcquiredSkill) async {
        personalFile.skills.append(skill)
        personalFile.growth.skillsAcquired.append(SkillAcquisition(
            skillName: skill.name,
            acquisitionMethod: skill.acquisitionMethod,
            proficiencyLevel: skill.proficiency
        ))

        // Record milestone
        await addMilestone(Milestone(
            description: "Learned skill: \(skill.name)",
            emotionalSignificance: 0.8,
            category: .learnedNewSkill
        ))
    }

    func updateSkillProficiency(skillName: String, delta: Float) async {
        if let index = personalFile.skills.firstIndex(where: { $0.name == skillName }) {
            personalFile.skills[index].proficiency = max(0, min(1, personalFile.skills[index].proficiency + delta))
        }
        if let index = personalFile.growth.skillsAcquired.firstIndex(where: { $0.skillName == skillName }) {
            personalFile.growth.skillsAcquired[index].proficiencyLevel = max(0, min(1, personalFile.growth.skillsAcquired[index].proficiencyLevel + delta))
            personalFile.growth.skillsAcquired[index].usageCount += 1
        }
        await scheduleSave()
    }

    // MARK: - State Operations

    func updateMood(_ mood: EmotionalTone) async {
        personalFile.state.currentMood = mood
        await scheduleSave()
    }

    func updateMood(adjustment: EmotionalAdjustment) async {
        personalFile.state.currentMood.valence = max(-1, min(1, personalFile.state.currentMood.valence + adjustment.valence))
        personalFile.state.currentMood.arousal = max(0, min(1, personalFile.state.currentMood.arousal + adjustment.arousal))
        if let emotion = adjustment.dominantEmotion {
            personalFile.state.currentMood.dominantEmotion = emotion
        }
        await scheduleSave()
    }

    struct EmotionalAdjustment {
        let valence: Float
        let arousal: Float
        var dominantEmotion: String? = nil
    }

    func setEngagementMode(_ mode: EngagementMode) async {
        personalFile.state.engagementMode = mode
        await scheduleSave()
    }

    func updateEnergyLevel(_ level: Float) async {
        personalFile.state.energyLevel = max(0, min(1, level))
        await scheduleSave()
    }

    func addNotification(_ notification: AgentNotification) async {
        personalFile.state.pendingNotifications.append(notification)
        await scheduleSave()
    }

    func acknowledgeNotification(_ notificationId: UUID) async {
        if let index = personalFile.state.pendingNotifications.firstIndex(where: { $0.id == notificationId }) {
            personalFile.state.pendingNotifications[index].acknowledged = true
            await scheduleSave()
        }
    }

    func clearAcknowledgedNotifications() async {
        personalFile.state.pendingNotifications.removeAll { $0.acknowledged }
        await scheduleSave()
    }

    // MARK: - Relationship Operations

    func getOrCreatePrimaryRelationship() async -> Relationship {
        if let existing = personalFile.relationships.first(where: { $0.partnerId == "primary" }) {
            return existing
        }
        let relationship = Relationship(partnerId: "primary")
        personalFile.relationships.append(relationship)
        await scheduleSave()
        return relationship
    }

    func updateRelationshipTrust(partnerId: String = "primary", delta: Float) async {
        if let index = personalFile.relationships.firstIndex(where: { $0.partnerId == partnerId }) {
            personalFile.relationships[index].trustLevel = max(0, min(1, personalFile.relationships[index].trustLevel + delta))
            await scheduleSave()
        }
    }

    func incrementMessageCount(partnerId: String = "primary") async {
        if let index = personalFile.relationships.firstIndex(where: { $0.partnerId == partnerId }) {
            personalFile.relationships[index].communicationHistory.totalMessages += 1
            await scheduleSave()
        }
    }

    // MARK: - Appendage State Operations

    func addAppendageState(_ state: AppendageState) async {
        personalFile.state.activeAppendages.append(state)
        await scheduleSave()
    }

    func updateAppendageState(_ id: UUID, progress: Float? = nil, status: AppendageStatus? = nil) async {
        if let index = personalFile.state.activeAppendages.firstIndex(where: { $0.id == id }) {
            if let progress = progress {
                personalFile.state.activeAppendages[index].progress = progress
            }
            if let status = status {
                personalFile.state.activeAppendages[index].status = status
            }
            await scheduleSave()
        }
    }

    func removeAppendageState(_ id: UUID) async {
        personalFile.state.activeAppendages.removeAll { $0.id == id }
        await scheduleSave()
    }

    // MARK: - Persistence

    private func scheduleSave() async {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // Debounce 500ms
            if !Task.isCancelled {
                try? await save()
            }
        }
    }

    private func save() async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(personalFile)
        try data.write(to: fileURL, options: .atomic)
    }

    /// Force immediate save (for critical operations)
    func forceSave() async throws {
        saveTask?.cancel()
        try await save()
    }

    // MARK: - Convenience Getters for AgentService

    func getIdentity() -> AgentIdentity {
        return personalFile.identity
    }

    func getState() -> AgentState {
        return personalFile.state
    }

    func getPendingNotifications() -> [AgentNotification] {
        return personalFile.state.pendingNotifications.filter { !$0.acknowledged }
    }

    func getBirthday() -> Date {
        return personalFile.birthDate
    }

    func getTotalInteractions() -> Int {
        return personalFile.totalInteractions
    }

    func getRelationship(partnerId: String) -> Relationship? {
        return personalFile.relationships.first { $0.partnerId == partnerId }
    }

    func setName(_ name: String, origin: String?) async {
        personalFile.identity.name = name
        personalFile.identity.nameOrigin = origin
        await scheduleSave()
    }

    func recordPreference(key: String, value: String) async {
        personalFile.memory.userPreferences[key] = PreferenceEntry(
            value: value,
            dateObserved: Date(),
            confidence: 0.8,
            reinforcements: 1
        )
        await scheduleSave()
    }
}
