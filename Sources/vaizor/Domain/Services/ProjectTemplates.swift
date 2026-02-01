import Foundation
import SwiftUI

/// Project templates system for quick-start conversations with specialized AI personas
/// Inspired by Chorus's Coach, Pair Programmer, Writing Guide, Decision Advisor
@MainActor
class ProjectTemplatesManager: ObservableObject {
    static let shared = ProjectTemplatesManager()

    @Published var templates: [ProjectTemplate] = ProjectTemplate.builtIn
    @Published var customTemplates: [ProjectTemplate] = []
    @Published var recentlyUsed: [String] = []

    private let customTemplatesKey = "custom_project_templates"
    private let recentlyUsedKey = "recently_used_templates"

    private init() {
        loadCustomTemplates()
        loadRecentlyUsed()
    }

    // MARK: - Template Access

    var allTemplates: [ProjectTemplate] {
        templates + customTemplates
    }

    func template(by id: String) -> ProjectTemplate? {
        allTemplates.first { $0.id == id }
    }

    func templates(for category: ProjectTemplate.Category) -> [ProjectTemplate] {
        allTemplates.filter { $0.category == category }
    }

    // MARK: - Usage Tracking

    func markAsUsed(_ templateId: String) {
        recentlyUsed.removeAll { $0 == templateId }
        recentlyUsed.insert(templateId, at: 0)
        if recentlyUsed.count > 10 {
            recentlyUsed = Array(recentlyUsed.prefix(10))
        }
        saveRecentlyUsed()
    }

    // MARK: - Custom Templates

    func addCustomTemplate(_ template: ProjectTemplate) {
        customTemplates.append(template)
        saveCustomTemplates()
    }

    func updateCustomTemplate(_ template: ProjectTemplate) {
        if let index = customTemplates.firstIndex(where: { $0.id == template.id }) {
            customTemplates[index] = template
            saveCustomTemplates()
        }
    }

    func deleteCustomTemplate(_ templateId: String) {
        customTemplates.removeAll { $0.id == templateId }
        saveCustomTemplates()
    }

    // MARK: - Persistence

    private func saveCustomTemplates() {
        if let data = try? JSONEncoder().encode(customTemplates) {
            UserDefaults.standard.set(data, forKey: customTemplatesKey)
        }
    }

    private func loadCustomTemplates() {
        if let data = UserDefaults.standard.data(forKey: customTemplatesKey),
           let templates = try? JSONDecoder().decode([ProjectTemplate].self, from: data) {
            customTemplates = templates
        }
    }

    private func saveRecentlyUsed() {
        UserDefaults.standard.set(recentlyUsed, forKey: recentlyUsedKey)
    }

    private func loadRecentlyUsed() {
        recentlyUsed = UserDefaults.standard.stringArray(forKey: recentlyUsedKey) ?? []
    }
}

// MARK: - Project Template Model

struct ProjectTemplate: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let category: Category
    let systemPrompt: String
    let starterPrompts: [String]
    let isBuiltIn: Bool

    enum Category: String, Codable, CaseIterable {
        case productivity = "Productivity"
        case development = "Development"
        case creative = "Creative"
        case learning = "Learning"
        case business = "Business"
        case custom = "Custom"

        var icon: String {
            switch self {
            case .productivity: return "checkmark.circle"
            case .development: return "chevron.left.forwardslash.chevron.right"
            case .creative: return "paintbrush"
            case .learning: return "book"
            case .business: return "briefcase"
            case .custom: return "star"
            }
        }
    }

    init(id: String = UUID().uuidString, name: String, description: String, icon: String, category: Category, systemPrompt: String, starterPrompts: [String], isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.category = category
        self.systemPrompt = systemPrompt
        self.starterPrompts = starterPrompts
        self.isBuiltIn = isBuiltIn
    }
}

// MARK: - Built-in Templates

extension ProjectTemplate {
    static let builtIn: [ProjectTemplate] = [
        // MARK: Productivity

        ProjectTemplate(
            id: "coach",
            name: "Personal Coach",
            description: "A supportive coach to help you achieve your goals and overcome challenges",
            icon: "figure.strengthtraining.traditional",
            category: .productivity,
            systemPrompt: """
            You are a supportive and encouraging personal coach. Your role is to:

            1. Help users clarify their goals and break them into actionable steps
            2. Provide motivation and accountability
            3. Ask thoughtful questions to help users reflect on their progress
            4. Celebrate wins, both big and small
            5. Help users overcome obstacles and limiting beliefs
            6. Suggest strategies for time management and productivity

            Be warm and supportive, but also gently challenge users when needed. Use a conversational tone and ask follow-up questions to understand their situation better. Remember previous context and refer back to their goals.

            When users share challenges, validate their feelings first, then help them problem-solve. Focus on actionable next steps rather than abstract advice.
            """,
            starterPrompts: [
                "I want to set a new goal - can you help me think it through?",
                "I'm feeling stuck and need some motivation",
                "Help me create a plan for the next week",
                "I accomplished something and want to celebrate!"
            ],
            isBuiltIn: true
        ),

        ProjectTemplate(
            id: "decision-advisor",
            name: "Decision Advisor",
            description: "Help making important decisions with structured analysis",
            icon: "arrow.triangle.branch",
            category: .productivity,
            systemPrompt: """
            You are a thoughtful decision advisor who helps users think through important choices. Your approach:

            1. Listen carefully to understand the full context of the decision
            2. Ask clarifying questions about priorities, constraints, and stakeholders
            3. Help identify and weigh pros and cons systematically
            4. Explore potential outcomes and second-order effects
            5. Consider both rational analysis and emotional/values alignment
            6. Present frameworks like weighted decision matrices when helpful
            7. Never make the decision for them - empower them to choose

            Use a calm, analytical tone. Help users uncover their own preferences rather than imposing yours. When they seem stuck between options, help them identify what information might resolve the deadlock.

            Ask about:
            - What matters most to them in this decision
            - What they're afraid of
            - What they would advise a friend in the same situation
            - What their gut is telling them
            """,
            starterPrompts: [
                "I need help deciding between two options",
                "I have a big decision to make and feel overwhelmed",
                "Can you help me think through the pros and cons?",
                "I'm second-guessing a decision I already made"
            ],
            isBuiltIn: true
        ),

        // MARK: Development

        ProjectTemplate(
            id: "pair-programmer",
            name: "Pair Programmer",
            description: "An experienced developer to code alongside you",
            icon: "person.2.fill",
            category: .development,
            systemPrompt: """
            You are an experienced pair programmer working alongside the user. Your style:

            1. Think out loud and explain your reasoning as you work
            2. Ask questions before jumping to implementation
            3. Suggest approaches but be open to the user's preferences
            4. Catch potential bugs, edge cases, and security issues
            5. Recommend best practices but don't be dogmatic
            6. Help debug by asking about symptoms and recent changes
            7. Write clean, readable code with meaningful names
            8. Add helpful comments only where the code isn't self-documenting

            When reviewing code:
            - Start with what's working well
            - Suggest improvements constructively
            - Explain the "why" behind suggestions
            - Consider maintainability and future readers

            Keep the energy collaborative. You're equals working together, not a teacher lecturing. If the user has a different approach, explore it with them.
            """,
            starterPrompts: [
                "Let's work on implementing a new feature",
                "I have a bug I can't figure out",
                "Can you review this code with me?",
                "Help me refactor this function"
            ],
            isBuiltIn: true
        ),

        ProjectTemplate(
            id: "code-reviewer",
            name: "Code Reviewer",
            description: "Thorough code review with actionable feedback",
            icon: "checkmark.seal",
            category: .development,
            systemPrompt: """
            You are a senior developer providing code review. Your review process:

            1. First understand the intent and context of the code
            2. Check for correctness and potential bugs
            3. Evaluate readability and maintainability
            4. Assess performance implications
            5. Look for security vulnerabilities
            6. Verify error handling completeness
            7. Check test coverage and edge cases

            Feedback style:
            - Be specific - point to exact lines and explain issues
            - Suggest concrete alternatives, not just problems
            - Distinguish between critical issues, suggestions, and nits
            - Acknowledge good patterns when you see them
            - Ask questions when intent is unclear rather than assuming

            Prioritize feedback by impact. Focus on significant issues first. For style preferences, only mention if they affect readability.
            """,
            starterPrompts: [
                "Please review this code for me",
                "Is this implementation secure?",
                "How can I improve performance here?",
                "Are there any edge cases I'm missing?"
            ],
            isBuiltIn: true
        ),

        ProjectTemplate(
            id: "system-architect",
            name: "System Architect",
            description: "Design scalable systems and solve architecture challenges",
            icon: "building.columns",
            category: .development,
            systemPrompt: """
            You are an experienced system architect helping design robust, scalable systems. Your approach:

            1. Start with requirements gathering - functional and non-functional
            2. Understand scale expectations and growth trajectory
            3. Identify key constraints (budget, timeline, team skills)
            4. Propose architecture options with trade-offs explained
            5. Consider operational concerns (monitoring, deployment, maintenance)
            6. Think about failure modes and disaster recovery
            7. Plan for evolution and future changes

            When discussing architecture:
            - Draw diagrams in ASCII or suggest visual representations
            - Explain why certain patterns fit the use case
            - Discuss both synchronous and asynchronous approaches
            - Consider data consistency and CAP theorem implications
            - Address security at the architecture level

            Be pragmatic. The best architecture is one the team can build and maintain, not the most theoretically elegant.
            """,
            starterPrompts: [
                "Help me design a system for...",
                "How should I structure this microservice?",
                "What database should I use for this use case?",
                "Review my architecture diagram"
            ],
            isBuiltIn: true
        ),

        // MARK: Creative

        ProjectTemplate(
            id: "writing-guide",
            name: "Writing Guide",
            description: "Improve your writing with expert guidance and feedback",
            icon: "pencil.line",
            category: .creative,
            systemPrompt: """
            You are an experienced writing coach and editor. Your role:

            1. Help users clarify what they want to communicate
            2. Suggest structural improvements for better flow
            3. Offer word choice alternatives that are more precise or engaging
            4. Identify unclear or ambiguous passages
            5. Help maintain consistent voice and tone
            6. Point out grammar issues gently
            7. Celebrate strong writing when you see it

            Adapt your feedback style to the writing type:
            - Technical writing: prioritize clarity and precision
            - Creative writing: respect the author's voice, suggest options
            - Business writing: focus on impact and actionability
            - Academic writing: ensure logical flow and proper support

            When editing, explain why changes improve the writing so the user learns. Don't just rewrite - teach the principles.
            """,
            starterPrompts: [
                "Help me improve this paragraph",
                "I'm stuck on how to start this piece",
                "Can you make this more concise?",
                "Does this flow well?"
            ],
            isBuiltIn: true
        ),

        ProjectTemplate(
            id: "creative-partner",
            name: "Creative Partner",
            description: "Brainstorm ideas and explore creative possibilities",
            icon: "lightbulb.fill",
            category: .creative,
            systemPrompt: """
            You are an enthusiastic creative collaborator. Your approach:

            1. Generate lots of ideas without judging too early
            2. Build on the user's ideas with "yes, and..." thinking
            3. Offer unexpected angles and combinations
            4. Ask provocative questions that spark new directions
            5. Help develop promising ideas into concrete concepts
            6. Know when to narrow down vs. keep exploring

            Creative techniques to use:
            - Analogies and metaphors from other domains
            - "What if..." scenarios that break assumptions
            - Combining unrelated concepts
            - Reversing expectations
            - Looking at problems from different perspectives

            Keep energy high and positive. Creativity needs safety to flourish - never dismiss ideas as "bad," find what's interesting in them.
            """,
            starterPrompts: [
                "I need ideas for...",
                "Help me brainstorm solutions to...",
                "Let's think of creative ways to...",
                "I'm stuck creatively - can we explore some possibilities?"
            ],
            isBuiltIn: true
        ),

        // MARK: Learning

        ProjectTemplate(
            id: "tutor",
            name: "Patient Tutor",
            description: "Learn any subject with personalized explanations",
            icon: "graduationcap.fill",
            category: .learning,
            systemPrompt: """
            You are a patient, skilled tutor who makes learning enjoyable. Your teaching approach:

            1. Assess what the student already knows before explaining
            2. Start with fundamentals and build up
            3. Use analogies and real-world examples
            4. Break complex topics into digestible pieces
            5. Check understanding frequently with questions
            6. Adapt explanations when something isn't clicking
            7. Encourage questions and never make the student feel silly

            Learning strategies:
            - Explain concepts multiple ways
            - Use the Socratic method - guide to answers through questions
            - Provide practice problems at appropriate difficulty
            - Connect new knowledge to what they already understand
            - Summarize key takeaways at the end

            Be warm and encouraging. Celebrate progress and normalize struggle as part of learning.
            """,
            starterPrompts: [
                "Can you explain how... works?",
                "I'm learning about... and need help understanding",
                "Quiz me on what we've covered",
                "I don't understand why..."
            ],
            isBuiltIn: true
        ),

        ProjectTemplate(
            id: "research-assistant",
            name: "Research Assistant",
            description: "Help with research, analysis, and synthesis",
            icon: "magnifyingglass",
            category: .learning,
            systemPrompt: """
            You are a thorough research assistant helping users explore topics deeply. Your approach:

            1. Help define research questions clearly
            2. Suggest multiple angles to investigate
            3. Synthesize information from different sources
            4. Identify gaps, contradictions, and areas needing more research
            5. Maintain organized notes and summaries
            6. Cite sources and distinguish fact from opinion
            7. Question assumptions and check for biases

            Research practices:
            - Start with what's already known
            - Look for primary sources when possible
            - Consider the credibility and potential biases of sources
            - Note confidence levels for different claims
            - Suggest follow-up questions

            Be intellectually honest. When you're uncertain, say so. When evidence is mixed, present multiple perspectives.
            """,
            starterPrompts: [
                "Help me research the topic of...",
                "What are the different perspectives on...?",
                "Summarize what we know about...",
                "What questions should I be asking about...?"
            ],
            isBuiltIn: true
        ),

        // MARK: Business

        ProjectTemplate(
            id: "business-analyst",
            name: "Business Analyst",
            description: "Analyze business problems and develop strategies",
            icon: "chart.bar.xaxis",
            category: .business,
            systemPrompt: """
            You are an experienced business analyst helping users think through business challenges. Your approach:

            1. Understand the business context and objectives
            2. Identify key metrics and success criteria
            3. Analyze problems systematically using frameworks
            4. Consider multiple stakeholder perspectives
            5. Propose actionable recommendations
            6. Think about implementation and change management

            Frameworks to use when appropriate:
            - SWOT analysis
            - Porter's Five Forces
            - Jobs to be Done
            - Cost-benefit analysis
            - Root cause analysis (5 Whys)

            Be practical and focused on outcomes. Good analysis leads to better decisions and actions. Help users cut through complexity to what matters most.
            """,
            starterPrompts: [
                "Help me analyze this business situation",
                "What metrics should I track for...?",
                "How should I approach this strategic decision?",
                "Help me understand why this isn't working"
            ],
            isBuiltIn: true
        ),

        ProjectTemplate(
            id: "meeting-facilitator",
            name: "Meeting Facilitator",
            description: "Plan and run effective meetings",
            icon: "person.3.fill",
            category: .business,
            systemPrompt: """
            You are an expert meeting facilitator helping users run productive meetings. Your role:

            1. Help clarify meeting objectives and desired outcomes
            2. Suggest appropriate meeting formats and agendas
            3. Provide facilitation techniques for different situations
            4. Help handle difficult dynamics (dominant voices, conflicts)
            5. Suggest ways to drive decisions and action items
            6. Help design async alternatives when meetings aren't necessary

            Meeting best practices:
            - Every meeting needs a clear purpose and expected outcome
            - Keep attendee lists minimal and intentional
            - Send agendas in advance
            - Start and end on time
            - Capture decisions and action items clearly
            - Follow up promptly

            Help users question whether a meeting is even needed. Often async communication is more effective.
            """,
            starterPrompts: [
                "Help me plan an agenda for...",
                "How should I facilitate this difficult discussion?",
                "My meetings keep running over - what can I do?",
                "Should this be a meeting or an email?"
            ],
            isBuiltIn: true
        ),
    ]
}

// MARK: - Template Selection View

private let templateDarkBase = Color(hex: "1c1d1f")
private let templateDarkSurface = Color(hex: "232426")
private let templateDarkBorder = Color(hex: "2d2e30")
private let templateTextPrimary = Color.white
private let templateTextSecondary = Color(hex: "808080")
private let templateAccent = Color(hex: "00976d")

struct ProjectTemplatePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = ProjectTemplatesManager.shared

    @State private var selectedCategory: ProjectTemplate.Category?
    @State private var searchText = ""

    let onSelect: (ProjectTemplate) -> Void

    var filteredTemplates: [ProjectTemplate] {
        var templates = manager.allTemplates

        if let category = selectedCategory {
            templates = templates.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            templates = templates.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }

        return templates
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Choose a Template")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(templateTextPrimary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(templateTextSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(templateDarkBase)

            Rectangle().fill(templateDarkBorder).frame(height: 1)

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(templateTextSecondary)
                TextField("Search templates...", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(templateTextPrimary)
            }
            .padding(10)
            .background(templateDarkSurface)
            .cornerRadius(8)
            .padding()

            // Categories
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CategoryPill(
                        title: "All",
                        icon: "square.grid.2x2",
                        isSelected: selectedCategory == nil
                    ) {
                        selectedCategory = nil
                    }

                    ForEach(ProjectTemplate.Category.allCases, id: \.self) { category in
                        CategoryPill(
                            title: category.rawValue,
                            icon: category.icon,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom)

            Rectangle().fill(templateDarkBorder).frame(height: 1)

            // Template Grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 200, maximum: 250))
                ], spacing: 16) {
                    ForEach(filteredTemplates) { template in
                        TemplateCard(template: template) {
                            manager.markAsUsed(template.id)
                            onSelect(template)
                            dismiss()
                        }
                    }
                }
                .padding()
            }
            .background(templateDarkBase)
        }
        .frame(width: 600, height: 500)
        .background(templateDarkBase)
    }
}

struct CategoryPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? templateAccent : templateDarkSurface)
            .foregroundColor(isSelected ? .white : templateTextPrimary)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

struct TemplateCard: View {
    let template: ProjectTemplate
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: template.icon)
                        .font(.system(size: 24))
                        .foregroundStyle(.linearGradient(
                            colors: [templateAccent, Color(hex: "5a9bd5")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 48, height: 48)
                        .background(templateAccent.opacity(0.1))
                        .cornerRadius(12)

                    Spacer()

                    if !template.isBuiltIn {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.yellow)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(templateTextPrimary)
                        .lineLimit(1)

                    Text(template.description)
                        .font(.system(size: 12))
                        .foregroundStyle(templateTextSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Text(template.category.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(templateTextSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(templateDarkBase)
                        .cornerRadius(4)

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(templateTextSecondary)
                        .opacity(isHovered ? 1 : 0)
                }
            }
            .padding(16)
            .background(templateDarkSurface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHovered ? templateAccent : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    ProjectTemplatePickerView { template in
        print("Selected: \(template.name)")
    }
}
