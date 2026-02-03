import Foundation

// MARK: - Action Proposal
// Represents an action the agent wants to perform, pending user approval

struct ActionProposal: Identifiable, Sendable {
    let id: UUID
    let action: AgentAction
    let reasoning: String
    let riskLevel: RiskLevel
    let urgency: ProposalUrgency
    let createdAt: Date
    let expiresAt: Date?
    let previewContent: String?

    init(
        id: UUID = UUID(),
        action: AgentAction,
        reasoning: String,
        riskLevel: RiskLevel? = nil,
        urgency: ProposalUrgency = .routine,
        expiresAt: Date? = nil,
        previewContent: String? = nil
    ) {
        self.id = id
        self.action = action
        self.reasoning = reasoning
        self.riskLevel = riskLevel ?? action.defaultRiskLevel
        self.urgency = urgency
        self.createdAt = Date()
        self.expiresAt = expiresAt
        self.previewContent = previewContent
    }

    var isExpired: Bool {
        guard let expiry = expiresAt else { return false }
        return Date() > expiry
    }

    var requiresApproval: Bool {
        return riskLevel >= .high
    }
}

// MARK: - Risk Levels

enum RiskLevel: Int, Comparable, Sendable {
    case none = 0       // Read-only, no side effects
    case low = 1        // Internal changes only
    case medium = 2     // Local system changes
    case high = 3       // External communication or significant changes
    case critical = 4   // Financial, security, or irreversible actions

    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var description: String {
        switch self {
        case .none: return "None"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }

    var requiresApproval: Bool {
        return self >= .high
    }

    var color: String {
        switch self {
        case .none: return "gray"
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}

// MARK: - Proposal Urgency

enum ProposalUrgency: Int, Comparable, Sendable {
    case routine = 0        // In-app notification panel
    case timeSensitive = 1  // System notification
    case urgent = 2         // Floating overlay

    static func < (lhs: ProposalUrgency, rhs: ProposalUrgency) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var description: String {
        switch self {
        case .routine: return "Routine"
        case .timeSensitive: return "Time Sensitive"
        case .urgent: return "Urgent"
        }
    }
}

// MARK: - Agent Actions

enum AgentAction: Sendable {
    // Communication
    case sendMessage(recipient: String, content: String, service: MessageService)
    case draftMessage(recipient: String, content: String, service: MessageService)

    // Browser
    case openURL(url: String)
    case summarizePage(url: String)
    case searchWeb(query: String)

    // File System
    case moveFile(from: String, to: String)
    case organizeFile(path: String, suggestedLocation: String)
    case deleteFile(path: String)
    case createFolder(at: String)

    // App Control
    case launchApp(name: String)
    case switchToApp(name: String)
    case quitApp(name: String)

    // Clipboard
    case copyToClipboard(content: String)
    case pasteFromClipboard

    // System
    case showNotification(title: String, body: String)
    case createReminder(title: String, date: Date?)
    case createCalendarEvent(title: String, start: Date, end: Date)

    // Navigation
    case navigateInApp(to: String)
    case scrollTo(element: String)
    case click(element: String)

    // Observation (no side effects)
    case observe(target: String)
    case summarize(content: String)

    var defaultRiskLevel: RiskLevel {
        switch self {
        // No risk - pure observation
        case .observe, .summarize:
            return .none

        // Low risk - internal/reversible
        case .navigateInApp, .scrollTo, .copyToClipboard, .summarizePage:
            return .low

        // Medium risk - local changes
        case .launchApp, .switchToApp, .openURL, .createFolder, .showNotification, .searchWeb, .pasteFromClipboard, .click:
            return .medium

        // High risk - external communication or significant changes
        case .sendMessage, .draftMessage, .moveFile, .organizeFile, .quitApp, .createReminder, .createCalendarEvent:
            return .high

        // Critical - destructive or irreversible
        case .deleteFile:
            return .critical
        }
    }

    var description: String {
        switch self {
        case .sendMessage(let recipient, _, let service):
            return "Send \(service.rawValue) to \(recipient)"
        case .draftMessage(let recipient, _, let service):
            return "Draft \(service.rawValue) to \(recipient)"
        case .openURL(let url):
            return "Open \(url)"
        case .summarizePage(let url):
            return "Summarize page: \(url)"
        case .searchWeb(let query):
            return "Search: \(query)"
        case .moveFile(let from, let to):
            return "Move \((from as NSString).lastPathComponent) to \((to as NSString).lastPathComponent)"
        case .organizeFile(let path, let location):
            return "Move \((path as NSString).lastPathComponent) to \(location)"
        case .deleteFile(let path):
            return "Delete \((path as NSString).lastPathComponent)"
        case .createFolder(let path):
            return "Create folder at \(path)"
        case .launchApp(let name):
            return "Launch \(name)"
        case .switchToApp(let name):
            return "Switch to \(name)"
        case .quitApp(let name):
            return "Quit \(name)"
        case .copyToClipboard:
            return "Copy to clipboard"
        case .pasteFromClipboard:
            return "Paste from clipboard"
        case .showNotification(let title, _):
            return "Show notification: \(title)"
        case .createReminder(let title, _):
            return "Create reminder: \(title)"
        case .createCalendarEvent(let title, _, _):
            return "Create event: \(title)"
        case .navigateInApp(let to):
            return "Navigate to \(to)"
        case .scrollTo(let element):
            return "Scroll to \(element)"
        case .click(let element):
            return "Click \(element)"
        case .observe(let target):
            return "Observe \(target)"
        case .summarize:
            return "Summarize content"
        }
    }
}

enum MessageService: String, Sendable {
    case iMessage = "iMessage"
    case sms = "SMS"
}

// MARK: - Proposal Result

enum ProposalResult: Sendable {
    case approved
    case rejected
    case modified(AgentAction)
    case expired
    case error(String)
}

// MARK: - Proposal Manager

@MainActor
class ProposalManager: ObservableObject {
    static let shared = ProposalManager()

    @Published private(set) var pendingProposals: [ActionProposal] = []
    @Published private(set) var recentResults: [(ActionProposal, ProposalResult)] = []

    private var proposalHandlers: [(ActionProposal) -> Void] = []

    private init() {}

    // MARK: - Proposal Lifecycle

    func submitProposal(_ proposal: ActionProposal) {
        pendingProposals.append(proposal)

        // Notify handlers
        for handler in proposalHandlers {
            handler(proposal)
        }

        // Route based on urgency
        routeProposal(proposal)

        AppLogger.shared.log("ProposalManager: New proposal - \(proposal.action.description)", level: .info)
    }

    func resolveProposal(_ id: UUID, result: ProposalResult) {
        guard let index = pendingProposals.firstIndex(where: { $0.id == id }) else { return }

        let proposal = pendingProposals.remove(at: index)
        recentResults.append((proposal, result))

        // Keep recent results limited
        if recentResults.count > 50 {
            recentResults.removeFirst()
        }

        AppLogger.shared.log("ProposalManager: Resolved - \(proposal.action.description) -> \(result)", level: .info)
    }

    func onProposal(_ handler: @escaping (ActionProposal) -> Void) {
        proposalHandlers.append(handler)
    }

    // MARK: - Routing

    private func routeProposal(_ proposal: ActionProposal) {
        switch proposal.urgency {
        case .routine:
            // Handled by in-app UI
            NotificationCenter.default.post(name: .proposalSubmitted, object: proposal)

        case .timeSensitive:
            // Send system notification
            sendSystemNotification(for: proposal)

        case .urgent:
            // Show floating overlay
            NotificationCenter.default.post(name: .urgentProposalSubmitted, object: proposal)
        }
    }

    private func sendSystemNotification(for proposal: ActionProposal) {
        // Will be implemented with UNUserNotificationCenter
        NotificationCenter.default.post(name: .proposalSubmitted, object: proposal)
    }

    // MARK: - Cleanup

    func cleanupExpired() {
        let now = Date()
        let expired = pendingProposals.filter { $0.expiresAt != nil && $0.expiresAt! < now }

        for proposal in expired {
            resolveProposal(proposal.id, result: .expired)
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let proposalSubmitted = Notification.Name("proposalSubmitted")
    static let urgentProposalSubmitted = Notification.Name("urgentProposalSubmitted")
    static let proposalResolved = Notification.Name("proposalResolved")
}
