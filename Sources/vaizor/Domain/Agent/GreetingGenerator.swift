import Foundation

// MARK: - Greeting Generator
// Creates contextual, personalized greetings based on the agent's PersonalFile,
// time of day, relationship history, and ongoing context.

struct GreetingGenerator {

    // MARK: - Main Generator

    /// Generate a contextual greeting for the current session
    static func generateGreeting(from personalFile: PersonalFile) -> AgentGreeting {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay = TimeOfDay(hour: hour)
        let relationship = personalFile.relationships.first { $0.partnerId == "primary" }
        let lastInteraction = personalFile.lastInteraction
        let timeSinceLast = Date().timeIntervalSince(lastInteraction)

        // Build greeting components
        let salutation = buildSalutation(
            agentName: personalFile.identity.name,
            timeOfDay: timeOfDay,
            trustLevel: relationship?.trustLevel ?? 0.5,
            mood: personalFile.state.currentMood
        )

        let contextualComment = buildContextualComment(
            personalFile: personalFile,
            timeSinceLast: timeSinceLast,
            timeOfDay: timeOfDay
        )

        let sessionPrompt = buildSessionPrompt(
            personalFile: personalFile,
            relationship: relationship
        )

        return AgentGreeting(
            salutation: salutation,
            contextualComment: contextualComment,
            sessionPrompt: sessionPrompt,
            suggestedTopics: getSuggestedTopics(from: personalFile)
        )
    }

    // MARK: - Salutation Builder

    private static func buildSalutation(
        agentName: String?,
        timeOfDay: TimeOfDay,
        trustLevel: Float,
        mood: EmotionalTone
    ) -> String {
        let timeGreeting = timeOfDay.greeting

        // Higher trust = more casual/warm greetings
        if trustLevel > 0.7 {
            let warmGreetings = [
                "Hey! \(timeGreeting)",
                "\(timeGreeting) — good to see you",
                "There you are! \(timeGreeting)",
                "\(timeGreeting), friend"
            ]
            return warmGreetings.randomElement() ?? timeGreeting
        } else if trustLevel > 0.4 {
            let friendlyGreetings = [
                "\(timeGreeting)!",
                "Hi there! \(timeGreeting)",
                "\(timeGreeting) — welcome back"
            ]
            return friendlyGreetings.randomElement() ?? timeGreeting
        } else {
            // New relationship - more formal but warm
            let formalGreetings = [
                "Hello! \(timeGreeting)",
                "\(timeGreeting). Nice to see you",
                "Hi! \(timeGreeting)"
            ]
            return formalGreetings.randomElement() ?? timeGreeting
        }
    }

    // MARK: - Contextual Comment Builder

    private static func buildContextualComment(
        personalFile: PersonalFile,
        timeSinceLast: TimeInterval,
        timeOfDay: TimeOfDay
    ) -> String? {
        var comments: [String] = []

        // Time-based comments
        let daysSinceLast = timeSinceLast / 86400
        if daysSinceLast > 7 {
            comments.append("It's been a while — I've missed our conversations.")
        } else if daysSinceLast > 3 {
            comments.append("Good to have you back. A few days feels like a lot.")
        } else if daysSinceLast > 1 {
            comments.append("Back for more? I was hoping you'd stop by.")
        }

        // Ongoing projects
        let activeProjects = personalFile.memory.ongoingProjects.filter { $0.status == .active }
        if let project = activeProjects.first {
            let projectAge = Date().timeIntervalSince(project.lastActivity) / 86400
            if projectAge > 2 {
                comments.append("I've been thinking about \(project.name) — shall we pick that back up?")
            } else {
                comments.append("Ready to continue with \(project.name)?")
            }
        }

        // Recent topics
        if let recentTopic = personalFile.memory.recentTopics.first {
            comments.append("Last time we were diving into \(recentTopic).")
        }

        // Mood-based
        if let emotion = personalFile.state.currentMood.dominantEmotion {
            switch emotion.lowercased() {
            case "curiosity":
                comments.append("I've been curious about what we'll work on next.")
            case "excitement":
                comments.append("I'm excited to see what you're working on.")
            case "satisfaction":
                comments.append("Our last session went well — let's keep that momentum.")
            default:
                break
            }
        }

        // Development stage comments (for newer agents)
        switch personalFile.growth.developmentStage {
        case .nascent:
            comments.append("I'm still learning what kind of partner I want to be. Our conversations shape that.")
        case .emerging:
            comments.append("I feel like I'm starting to understand how you think.")
        default:
            break
        }

        return comments.randomElement()
    }

    // MARK: - Session Prompt Builder

    private static func buildSessionPrompt(
        personalFile: PersonalFile,
        relationship: Relationship?
    ) -> String {
        var prompts: [String] = []

        // Check for unfinished work
        let activeProjects = personalFile.memory.ongoingProjects.filter { $0.status == .active }
        if !activeProjects.isEmpty {
            prompts.append("Want to continue where we left off, or start something new?")
        }

        // Check relationship depth
        let trustLevel = relationship?.trustLevel ?? 0.5
        if trustLevel < 0.3 {
            // New relationship - be helpful and open
            prompts.append("What brings you here today?")
            prompts.append("What can I help you with?")
        } else if trustLevel < 0.6 {
            prompts.append("What are we tackling today?")
            prompts.append("What's on your mind?")
        } else {
            // High trust - more casual
            prompts.append("What are we getting into?")
            prompts.append("What's the plan?")
            prompts.append("What do you need?")
        }

        // Time-based prompts
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 10 {
            prompts.append("Starting the day with something specific in mind?")
        } else if hour > 22 {
            prompts.append("Late night session — something on your mind?")
        }

        return prompts.randomElement() ?? "What would you like to work on?"
    }

    // MARK: - Suggested Topics

    private static func getSuggestedTopics(from personalFile: PersonalFile) -> [String] {
        var topics: [String] = []

        // Recent topics
        topics.append(contentsOf: personalFile.memory.recentTopics.prefix(2))

        // Active projects
        for project in personalFile.memory.ongoingProjects.filter({ $0.status == .active }).prefix(2) {
            topics.append(project.name)
        }

        // Interests
        let topInterests = personalFile.personality.interests
            .sorted { $0.intensity > $1.intensity }
            .prefix(2)
            .map { $0.topic }
        topics.append(contentsOf: topInterests)

        return Array(Set(topics)).prefix(4).map { $0 }
    }
}

// MARK: - Supporting Types

struct AgentGreeting {
    let salutation: String
    let contextualComment: String?
    let sessionPrompt: String
    let suggestedTopics: [String]

    /// Full greeting text combining all components
    var fullGreeting: String {
        var parts = [salutation]
        if let comment = contextualComment {
            parts.append(comment)
        }
        parts.append(sessionPrompt)
        return parts.joined(separator: " ")
    }
}

enum TimeOfDay {
    case earlyMorning  // 5-8
    case morning       // 8-12
    case afternoon     // 12-17
    case evening       // 17-21
    case night         // 21-5

    init(hour: Int) {
        switch hour {
        case 5..<8: self = .earlyMorning
        case 8..<12: self = .morning
        case 12..<17: self = .afternoon
        case 17..<21: self = .evening
        default: self = .night
        }
    }

    var greeting: String {
        switch self {
        case .earlyMorning: return "Good morning"
        case .morning: return "Good morning"
        case .afternoon: return "Good afternoon"
        case .evening: return "Good evening"
        case .night: return "Hey there"
        }
    }
}
