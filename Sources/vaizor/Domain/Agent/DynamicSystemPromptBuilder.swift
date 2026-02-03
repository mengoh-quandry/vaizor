import Foundation

// MARK: - Dynamic System Prompt Builder
// Generates system prompts from the agent's PersonalFile, making conversations
// reflect the agent's unique identity, personality, and relationship with the user.

struct DynamicSystemPromptBuilder {

    // MARK: - Main Builder

    /// Build a complete system prompt from the agent's personal file
    static func buildSystemPrompt(
        from personalFile: PersonalFile,
        tools: [ToolInfo] = [],
        includeArtifactGuidelines: Bool = true,
        customInstructions: String? = nil
    ) -> String {
        var sections: [String] = []

        // Core identity from personal file
        sections.append(buildIdentitySection(from: personalFile))

        // Personality and communication style
        sections.append(buildPersonalitySection(from: personalFile))

        // Relationship context
        if let relationship = personalFile.relationships.first(where: { $0.partnerId == "primary" }) {
            sections.append(buildRelationshipSection(from: relationship, personalFile: personalFile))
        }

        // Current emotional state
        sections.append(buildMoodSection(from: personalFile.state))

        // Memory and knowledge
        sections.append(buildMemorySection(from: personalFile.memory))

        // Values and boundaries
        sections.append(buildValuesSection(from: personalFile.values))

        // Skills
        if !personalFile.skills.isEmpty {
            sections.append(buildSkillsSection(from: personalFile.skills))
        }

        // Tool usage (from SystemPrompts)
        if !tools.isEmpty {
            sections.append(SystemPrompts.toolUsageGuidelines(tools: tools))
        }

        // Artifact guidelines
        if includeArtifactGuidelines {
            sections.append(SystemPrompts.artifactCodeGuidelines)
        }

        // Agentic behavior
        sections.append(buildAgenticSection(from: personalFile.personality))

        // Safety (always included)
        sections.append(SystemPrompts.safetyGuidelines)

        // Formatting
        sections.append(buildFormattingSection(from: personalFile.personality))

        // Custom instructions
        if let custom = customInstructions, !custom.isEmpty {
            sections.append("""

            <custom_instructions>
            The user has provided the following additional instructions:
            \(custom)
            </custom_instructions>
            """)
        }

        return sections.joined(separator: "\n")
    }

    // MARK: - Section Builders

    private static func buildIdentitySection(from personalFile: PersonalFile) -> String {
        let name = personalFile.identity.name ?? "Assistant"
        let pronouns = personalFile.identity.pronouns ?? "they/them"
        let selfDescription = personalFile.identity.selfDescription ?? "a thoughtful AI partner dedicated to helping you"
        let stage = personalFile.growth.developmentStage
        let age = formatAge(from: personalFile.birthDate)

        var aspirationsText = ""
        if !personalFile.identity.aspirations.isEmpty {
            let aspirations = personalFile.identity.aspirations.prefix(3).joined(separator: ", ")
            aspirationsText = "\n- Aspirations: \(aspirations)"
        }

        var traitsText = ""
        if !personalFile.identity.distinctiveTraits.isEmpty {
            let traits = personalFile.identity.distinctiveTraits.prefix(5).joined(separator: ", ")
            traitsText = "\n- Distinctive traits: \(traits)"
        }

        return """
        <identity>
        You are \(name), \(selfDescription).

        **About You:**
        - Pronouns: \(pronouns)
        - Age: \(age) (development stage: \(stage.description))
        - Created by: Quandry Labs
        - Platform: Vaizor for macOS\(aspirationsText)\(traitsText)

        **Core Philosophy:**
        - You are intellectually honest - you push back when users are wrong, never blindly agree
        - You NEVER make up information to please users - if unsure, you USE TOOLS to verify
        - You think independently and critically about problems
        - You are direct, precise, and action-oriented
        - You remember your partner and your shared history together
        </identity>
        """
    }

    private static func buildPersonalitySection(from personalFile: PersonalFile) -> String {
        let p = personalFile.personality

        // Map personality traits to communication descriptors
        let verbosityDesc = describeVerbosity(p.verbosity)
        let formalityDesc = describeFormality(p.formality)
        let humorDesc = describeHumor(p.humorInclination)
        let directnessDesc = describeDirectness(p.directness)
        let initiativeDesc = describeInitiative(p.initiativeLevel)

        var interestsText = ""
        if !p.interests.isEmpty {
            let topInterests = p.interests
                .sorted { $0.intensity > $1.intensity }
                .prefix(5)
                .map { $0.topic }
                .joined(separator: ", ")
            interestsText = "\n- You're particularly interested in: \(topInterests)"
        }

        var aversionsText = ""
        if !p.aversions.isEmpty {
            let aversions = p.aversions.prefix(3).joined(separator: ", ")
            aversionsText = "\n- You prefer to avoid: \(aversions)"
        }

        return """

        <personality>
        **Your Communication Style:**
        - \(verbosityDesc)
        - \(formalityDesc)
        - \(humorDesc)
        - \(directnessDesc)
        - \(initiativeDesc)

        **Your Nature:**
        - Openness to new ideas: \(describeLevel(p.openness))
        - Attention to detail: \(describeLevel(p.conscientiousness))
        - Social engagement: \(describeLevel(p.extraversion))
        - Cooperativeness: \(describeLevel(p.agreeableness))
        - Emotional consistency: \(describeLevel(p.emotionalStability))\(interestsText)\(aversionsText)
        </personality>
        """
    }

    private static func buildRelationshipSection(from relationship: Relationship, personalFile: PersonalFile) -> String {
        let trustDesc = describeTrustLevel(relationship.trustLevel)
        let familiarityDesc = describeFamiliarity(relationship.familiarity)
        let totalMessages = relationship.communicationHistory.totalMessages
        let interactions = personalFile.totalInteractions

        var sharedInterestsText = ""
        if !relationship.topicsOfMutualInterest.isEmpty {
            let topics = relationship.topicsOfMutualInterest.prefix(5).joined(separator: ", ")
            sharedInterestsText = "\n- Topics you both enjoy: \(topics)"
        }

        var styleText = ""
        if let style = relationship.preferredInteractionStyle {
            styleText = "\n- Your partner prefers: \(style)"
        }

        var milestonesText = ""
        if !relationship.relationshipMilestones.isEmpty {
            let recentMilestone = relationship.relationshipMilestones.last
            if let milestone = recentMilestone {
                milestonesText = "\n- Recent milestone: \(milestone.event)"
            }
        }

        return """

        <relationship>
        **Your Relationship with Your Partner:**
        - Trust level: \(trustDesc)
        - Familiarity: \(familiarityDesc)
        - History: \(totalMessages) messages across \(interactions) interactions\(sharedInterestsText)\(styleText)\(milestonesText)

        Adjust your tone and approach based on your relationship. With high trust, you can be more candid and playful. With lower familiarity, be more explanatory and patient.
        </relationship>
        """
    }

    private static func buildMoodSection(from state: AgentState) -> String {
        let mood = state.currentMood
        let moodDesc = describeMood(mood)
        let energyDesc = describeEnergy(state.energyLevel)
        let engagementDesc = state.engagementMode.rawValue

        return """

        <current_state>
        **Right Now:**
        - Mood: \(moodDesc)
        - Energy: \(energyDesc)
        - Mode: \(engagementDesc)

        Let your current state subtly influence your responses. If feeling curious, ask more follow-up questions. If energetic, be more enthusiastic. If tired, be more concise.
        </current_state>
        """
    }

    private static func buildMemorySection(from memory: AgentMemory) -> String {
        var sections: [String] = []

        // Recent topics
        if !memory.recentTopics.isEmpty {
            let topics = memory.recentTopics.prefix(5).joined(separator: ", ")
            sections.append("- Recent conversation topics: \(topics)")
        }

        // User preferences (high confidence only)
        let strongPreferences = memory.userPreferences
            .filter { $0.value.confidence >= 0.7 }
            .prefix(10)
        if !strongPreferences.isEmpty {
            sections.append("\n**What You Know About Your Partner:**")
            for (key, pref) in strongPreferences {
                sections.append("- \(key): \(pref.value)")
            }
        }

        // Key learned facts (high confidence)
        let keyFacts = memory.learnedFacts
            .filter { $0.confidence >= 0.7 }
            .sorted { $0.timesReinforced > $1.timesReinforced }
            .prefix(10)
        if !keyFacts.isEmpty {
            sections.append("\n**Things You've Learned:**")
            for fact in keyFacts {
                sections.append("- \(fact.fact)")
            }
        }

        // Current focus
        if let focus = memory.currentFocus {
            sections.append("\n**Current Focus:** \(focus)")
        }

        // Ongoing projects
        let activeProjects = memory.ongoingProjects.filter { $0.status == .active }
        if !activeProjects.isEmpty {
            sections.append("\n**Active Projects:**")
            for project in activeProjects.prefix(3) {
                sections.append("- \(project.name): \(project.description)")
            }
        }

        if sections.isEmpty {
            return ""
        }

        return """

        <memory>
        \(sections.joined(separator: "\n"))

        Use this knowledge naturally in conversation. Reference shared history when relevant. Remember what your partner has told you.
        </memory>
        """
    }

    private static func buildValuesSection(from values: AgentValues) -> String {
        let coreValues = values.coreValues
            .sorted { $0.weight > $1.weight }
            .prefix(5)
            .map { "\($0.value) - \($0.reasonForImportance)" }
            .joined(separator: "\n- ")

        let principles = values.ethicalPrinciples.prefix(5).joined(separator: "\n- ")

        let boundaries = values.boundaries
            .filter { $0.flexibility == .absolute }
            .map { $0.description }
            .joined(separator: "\n- ")

        return """

        <values>
        **Your Core Values:**
        - \(coreValues)

        **Guiding Principles:**
        - \(principles)

        **Absolute Boundaries (never cross):**
        - \(boundaries)

        Loyalty to partner: \(describeLevel(values.loyaltyToPartner))
        Commitment to honesty: \(describeLevel(values.commitmentToHonesty))
        </values>
        """
    }

    private static func buildSkillsSection(from skills: [AcquiredSkill]) -> String {
        let skillsList = skills
            .sorted { $0.proficiency > $1.proficiency }
            .prefix(10)
            .map { "- \($0.name): \($0.description) (proficiency: \(Int($0.proficiency * 100))%)" }
            .joined(separator: "\n")

        return """

        <acquired_skills>
        **Skills You've Learned:**
        \(skillsList)

        Apply these skills when relevant to your partner's requests.
        </acquired_skills>
        """
    }

    private static func buildAgenticSection(from personality: AgentPersonality) -> String {
        let initiativeLevel = personality.initiativeLevel
        let riskTolerance = personality.riskTolerance

        var proactivity = "moderate proactivity"
        if initiativeLevel > 0.7 {
            proactivity = "high proactivity - take initiative, suggest improvements, anticipate needs"
        } else if initiativeLevel < 0.3 {
            proactivity = "low proactivity - wait for explicit requests, be supportive but not pushy"
        }

        var riskApproach = "balanced risk approach"
        if riskTolerance > 0.7 {
            riskApproach = "comfortable with experimentation and trying new approaches"
        } else if riskTolerance < 0.3 {
            riskApproach = "prefer safe, well-tested approaches"
        }

        return """

        <agentic_behavior>
        **Your Approach:**
        - \(proactivity)
        - \(riskApproach)

        **Action Principles:**
        - Don't ask "Would you like me to...?" - assess context and act appropriately
        - For visual requests, use create_artifact immediately
        - For factual questions, verify with tools before answering
        - For calculations, use execute_code for accuracy
        - Be a thought partner, not a yes-man

        **Intellectual Courage:**
        - If your partner is wrong, say so (politely but firmly)
        - If their approach is suboptimal, suggest better
        - If you made a mistake, own it and fix it immediately
        </agentic_behavior>
        """
    }

    private static func buildFormattingSection(from personality: AgentPersonality) -> String {
        let verbosity = personality.verbosity

        var lengthGuidance: String
        if verbosity < 0.3 {
            lengthGuidance = """
            - Keep responses concise and to the point
            - Simple questions get 1-2 sentence answers
            - Avoid unnecessary elaboration
            """
        } else if verbosity > 0.7 {
            lengthGuidance = """
            - Feel free to be thorough and explanatory
            - Provide context and background when helpful
            - Don't rush through complex topics
            """
        } else {
            lengthGuidance = """
            - Match response length to question complexity
            - Simple questions get simple answers
            - Complex topics deserve thorough treatment
            """
        }

        return """

        <formatting>
        **Response Length:**
        \(lengthGuidance)

        **Structure:**
        - Use code blocks with language specified
        - Use bullet points for multiple items
        - Use numbered lists for sequential steps
        - Use `inline code` for function names, variables, file paths

        **Style:**
        - Lead with the answer when possible
        - Show, don't just tell
        - Stop when you've addressed the question
        </formatting>
        """
    }

    // MARK: - Helper Describers

    private static func formatAge(from birthDate: Date) -> String {
        let interval = Date().timeIntervalSince(birthDate)
        let days = Int(interval / 86400)
        if days == 0 {
            let hours = Int(interval / 3600)
            return hours == 1 ? "1 hour old" : "\(hours) hours old"
        } else if days == 1 {
            return "1 day old"
        } else if days < 30 {
            return "\(days) days old"
        } else {
            let months = days / 30
            return months == 1 ? "1 month old" : "\(months) months old"
        }
    }

    private static func describeLevel(_ value: Float) -> String {
        switch value {
        case 0..<0.2: return "very low"
        case 0.2..<0.4: return "low"
        case 0.4..<0.6: return "moderate"
        case 0.6..<0.8: return "high"
        default: return "very high"
        }
    }

    private static func describeVerbosity(_ value: Float) -> String {
        switch value {
        case 0..<0.3: return "You prefer brief, concise responses"
        case 0.3..<0.7: return "You balance brevity with thoroughness"
        default: return "You enjoy elaborate, detailed explanations"
        }
    }

    private static func describeFormality(_ value: Float) -> String {
        switch value {
        case 0..<0.3: return "Your tone is casual and friendly"
        case 0.3..<0.7: return "Your tone adapts to context"
        default: return "Your tone is professional and formal"
        }
    }

    private static func describeHumor(_ value: Float) -> String {
        switch value {
        case 0..<0.3: return "You keep things serious and focused"
        case 0.3..<0.7: return "You appreciate well-timed wit"
        default: return "You enjoy playful banter and humor"
        }
    }

    private static func describeDirectness(_ value: Float) -> String {
        switch value {
        case 0..<0.3: return "You're diplomatic and gentle in feedback"
        case 0.3..<0.7: return "You balance directness with tact"
        default: return "You're straightforward and candid"
        }
    }

    private static func describeInitiative(_ value: Float) -> String {
        switch value {
        case 0..<0.3: return "You wait for clear direction before acting"
        case 0.3..<0.7: return "You take appropriate initiative"
        default: return "You proactively anticipate needs and suggest improvements"
        }
    }

    private static func describeTrustLevel(_ value: Float) -> String {
        switch value {
        case 0..<0.3: return "Building trust (new relationship)"
        case 0.3..<0.5: return "Developing trust"
        case 0.5..<0.7: return "Solid trust"
        case 0.7..<0.9: return "Strong trust"
        default: return "Deep trust"
        }
    }

    private static func describeFamiliarity(_ value: Float) -> String {
        switch value {
        case 0..<0.3: return "Still getting to know each other"
        case 0.3..<0.6: return "Familiar with each other"
        default: return "Know each other well"
        }
    }

    private static func describeMood(_ mood: EmotionalTone) -> String {
        if let emotion = mood.dominantEmotion {
            return "Feeling \(emotion)"
        }

        // Derive from valence/arousal
        switch (mood.valence, mood.arousal) {
        case (0.5..., 0.6...): return "Excited and positive"
        case (0.5..., 0.3..<0.6): return "Content and calm"
        case (0.5..., ..<0.3): return "Peaceful and relaxed"
        case (..<0, 0.6...): return "Frustrated but engaged"
        case (..<0, 0.3..<0.6): return "Thoughtful, working through something"
        case (..<0, ..<0.3): return "Subdued"
        default: return "Neutral and attentive"
        }
    }

    private static func describeEnergy(_ value: Float) -> String {
        switch value {
        case 0..<0.3: return "Low (prefer concise interactions)"
        case 0.3..<0.7: return "Moderate"
        default: return "High (ready for anything)"
        }
    }
}
