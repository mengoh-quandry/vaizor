import Foundation
import SwiftUI

/// Tracks API usage costs across conversations and projects
@MainActor
class CostTracker: ObservableObject {
    static let shared = CostTracker()

    // MARK: - Published State

    @Published var currentSessionCost: Double = 0
    @Published var todayCost: Double = 0
    @Published var monthCost: Double = 0
    @Published var conversationCosts: [UUID: Double] = [:]

    // MARK: - Cache Statistics

    @Published var sessionCacheHits: Int = 0
    @Published var sessionCacheMisses: Int = 0
    @Published var sessionCacheReadTokens: Int = 0
    @Published var sessionCacheWriteTokens: Int = 0
    @Published var totalCacheHits: Int = 0
    @Published var totalCacheMisses: Int = 0
    @Published var totalCacheReadTokens: Int = 0
    @Published var totalCacheWriteTokens: Int = 0
    @Published var estimatedCacheSavings: Double = 0

    // MARK: - Pricing (per 1M tokens, USD)

    struct ModelPricing: Codable {
        let inputPer1M: Double
        let outputPer1M: Double
        let cacheReadPer1M: Double?
        let cacheWritePer1M: Double?

        static let defaultPricing = ModelPricing(
            inputPer1M: 3.0,
            outputPer1M: 15.0,
            cacheReadPer1M: 0.30,
            cacheWritePer1M: 3.75
        )
    }

    /// Pricing for various models (per 1M tokens in USD)
    /// Cache pricing: writes are 1.25x base input, reads are 0.1x base input (90% discount)
    private let modelPricing: [String: ModelPricing] = [
        // Claude Opus 4.5 (latest)
        "claude-opus-4-5-20251101": ModelPricing(inputPer1M: 5.0, outputPer1M: 25.0, cacheReadPer1M: 0.50, cacheWritePer1M: 6.25),
        "claude-opus-4.5": ModelPricing(inputPer1M: 5.0, outputPer1M: 25.0, cacheReadPer1M: 0.50, cacheWritePer1M: 6.25),

        // Claude Sonnet 4.5
        "claude-sonnet-4-5-20250514": ModelPricing(inputPer1M: 3.0, outputPer1M: 15.0, cacheReadPer1M: 0.30, cacheWritePer1M: 3.75),
        "claude-sonnet-4.5": ModelPricing(inputPer1M: 3.0, outputPer1M: 15.0, cacheReadPer1M: 0.30, cacheWritePer1M: 3.75),

        // Claude 3.5 Sonnet
        "claude-3-5-sonnet-20241022": ModelPricing(inputPer1M: 3.0, outputPer1M: 15.0, cacheReadPer1M: 0.30, cacheWritePer1M: 3.75),
        "claude-3-5-sonnet-latest": ModelPricing(inputPer1M: 3.0, outputPer1M: 15.0, cacheReadPer1M: 0.30, cacheWritePer1M: 3.75),

        // Claude 3.5 Haiku
        "claude-3-5-haiku-20241022": ModelPricing(inputPer1M: 0.80, outputPer1M: 4.0, cacheReadPer1M: 0.08, cacheWritePer1M: 1.0),
        "claude-3-5-haiku-latest": ModelPricing(inputPer1M: 0.80, outputPer1M: 4.0, cacheReadPer1M: 0.08, cacheWritePer1M: 1.0),

        // Claude Haiku 4.5
        "claude-haiku-4-5-20250514": ModelPricing(inputPer1M: 1.0, outputPer1M: 5.0, cacheReadPer1M: 0.10, cacheWritePer1M: 1.25),
        "claude-haiku-4.5": ModelPricing(inputPer1M: 1.0, outputPer1M: 5.0, cacheReadPer1M: 0.10, cacheWritePer1M: 1.25),

        // Claude 3 Opus
        "claude-3-opus-20240229": ModelPricing(inputPer1M: 15.0, outputPer1M: 75.0, cacheReadPer1M: 1.50, cacheWritePer1M: 18.75),
        "claude-3-opus-latest": ModelPricing(inputPer1M: 15.0, outputPer1M: 75.0, cacheReadPer1M: 1.50, cacheWritePer1M: 18.75),

        // Claude 3 Sonnet
        "claude-3-sonnet-20240229": ModelPricing(inputPer1M: 3.0, outputPer1M: 15.0, cacheReadPer1M: 0.30, cacheWritePer1M: 3.75),

        // Claude 3 Haiku
        "claude-3-haiku-20240307": ModelPricing(inputPer1M: 0.25, outputPer1M: 1.25, cacheReadPer1M: 0.03, cacheWritePer1M: 0.30),

        // GPT-4o (automatic caching with 50% discount on cached tokens)
        "gpt-4o": ModelPricing(inputPer1M: 2.50, outputPer1M: 10.0, cacheReadPer1M: 1.25, cacheWritePer1M: nil),
        "gpt-4o-2024-11-20": ModelPricing(inputPer1M: 2.50, outputPer1M: 10.0, cacheReadPer1M: 1.25, cacheWritePer1M: nil),
        "gpt-4o-mini": ModelPricing(inputPer1M: 0.15, outputPer1M: 0.60, cacheReadPer1M: 0.075, cacheWritePer1M: nil),
        "gpt-4o-mini-2024-07-18": ModelPricing(inputPer1M: 0.15, outputPer1M: 0.60, cacheReadPer1M: 0.075, cacheWritePer1M: nil),

        // GPT-4 Turbo
        "gpt-4-turbo": ModelPricing(inputPer1M: 10.0, outputPer1M: 30.0, cacheReadPer1M: nil, cacheWritePer1M: nil),
        "gpt-4-turbo-preview": ModelPricing(inputPer1M: 10.0, outputPer1M: 30.0, cacheReadPer1M: nil, cacheWritePer1M: nil),

        // GPT-4
        "gpt-4": ModelPricing(inputPer1M: 30.0, outputPer1M: 60.0, cacheReadPer1M: nil, cacheWritePer1M: nil),

        // GPT-3.5 Turbo
        "gpt-3.5-turbo": ModelPricing(inputPer1M: 0.50, outputPer1M: 1.50, cacheReadPer1M: nil, cacheWritePer1M: nil),
    ]

    // MARK: - Persistence

    private let usageHistoryKey = "cost_usage_history"

    struct UsageRecord: Codable {
        let timestamp: Date
        let model: String
        let inputTokens: Int
        let outputTokens: Int
        let cacheReadTokens: Int?
        let cacheWriteTokens: Int?
        let cost: Double
        let conversationId: UUID?
    }

    private var usageHistory: [UsageRecord] = []

    // MARK: - Initialization

    private init() {
        loadUsageHistory()
        loadCacheStats()
        calculateAggregates()
    }

    // MARK: - Cost Calculation

    /// Calculate cost for a given usage
    func calculateCost(
        model: String,
        inputTokens: Int,
        outputTokens: Int,
        cacheReadTokens: Int? = nil,
        cacheWriteTokens: Int? = nil
    ) -> Double {
        let pricing = modelPricing[model] ?? ModelPricing.defaultPricing

        // Clamp negative values to 0
        let safeInputTokens = max(0, inputTokens)
        let safeOutputTokens = max(0, outputTokens)

        var cost = 0.0

        // Input tokens
        cost += Double(safeInputTokens) / 1_000_000 * pricing.inputPer1M

        // Output tokens
        cost += Double(safeOutputTokens) / 1_000_000 * pricing.outputPer1M

        // Cache read tokens
        if let cacheRead = cacheReadTokens, let cacheReadPrice = pricing.cacheReadPer1M {
            cost += Double(cacheRead) / 1_000_000 * cacheReadPrice
        }

        // Cache write tokens
        if let cacheWrite = cacheWriteTokens, let cacheWritePrice = pricing.cacheWritePer1M {
            cost += Double(cacheWrite) / 1_000_000 * cacheWritePrice
        }

        return cost
    }

    /// Record usage and update costs
    func recordUsage(
        model: String,
        inputTokens: Int,
        outputTokens: Int,
        cacheReadTokens: Int? = nil,
        cacheWriteTokens: Int? = nil,
        conversationId: UUID? = nil
    ) {
        let cost = calculateCost(
            model: model,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheReadTokens: cacheReadTokens,
            cacheWriteTokens: cacheWriteTokens
        )

        let record = UsageRecord(
            timestamp: Date(),
            model: model,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheReadTokens: cacheReadTokens,
            cacheWriteTokens: cacheWriteTokens,
            cost: cost,
            conversationId: conversationId
        )

        usageHistory.append(record)
        saveUsageHistory()

        // Update aggregates
        currentSessionCost += cost

        if let convId = conversationId {
            conversationCosts[convId, default: 0] += cost
        }

        calculateAggregates()

        // Check budget alerts
        checkBudgetAlerts()
    }

    // MARK: - Aggregates

    private func calculateAggregates() {
        let calendar = Calendar.current
        let now = Date()

        // Today's cost
        let startOfDay = calendar.startOfDay(for: now)
        todayCost = usageHistory
            .filter { $0.timestamp >= startOfDay }
            .reduce(0) { $0 + $1.cost }

        // This month's cost
        let components = calendar.dateComponents([.year, .month], from: now)
        if let startOfMonth = calendar.date(from: components) {
            monthCost = usageHistory
                .filter { $0.timestamp >= startOfMonth }
                .reduce(0) { $0 + $1.cost }
        }

        // Conversation costs
        conversationCosts = Dictionary(grouping: usageHistory) { $0.conversationId }
            .compactMapValues { records -> Double? in
                guard records.first?.conversationId != nil else { return nil }
                return records.reduce(0) { $0 + $1.cost }
            }
            .reduce(into: [:]) { result, pair in
                if let key = pair.key {
                    result[key] = pair.value
                }
            }
    }

    /// Get cost for a specific conversation
    func costForConversation(_ id: UUID) -> Double {
        return conversationCosts[id] ?? 0
    }

    /// Get total all-time cost
    var allTimeCost: Double {
        usageHistory.reduce(0) { $0 + $1.cost }
    }

    /// Get usage history for a date range
    func usageHistory(from: Date, to: Date) -> [UsageRecord] {
        usageHistory.filter { $0.timestamp >= from && $0.timestamp <= to }
    }

    /// Get daily costs for the past N days
    func dailyCosts(days: Int) -> [(date: Date, cost: Double)] {
        let calendar = Calendar.current
        let now = Date()

        return (0..<days).compactMap { dayOffset -> (Date, Double)? in
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { return nil }
            let startOfDay = calendar.startOfDay(for: date)
            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return nil }

            let dayCost = usageHistory
                .filter { $0.timestamp >= startOfDay && $0.timestamp < endOfDay }
                .reduce(0) { $0 + $1.cost }

            return (startOfDay, dayCost)
        }.reversed()
    }

    // MARK: - Budget Alerts

    private func checkBudgetAlerts() {
        let settings = AppSettings.shared
        guard settings.enableBudgetAlerts else { return }

        if monthCost >= settings.monthlyBudgetAlert * 0.8 {
            // Would trigger notification - placeholder for now
            AppLogger.shared.log("Budget alert: Monthly spending at \(String(format: "%.0f%%", monthCost / settings.monthlyBudgetAlert * 100)) of limit", level: .warning)
        }
    }

    // MARK: - Persistence

    private func saveUsageHistory() {
        // Keep only last 90 days
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        usageHistory = usageHistory.filter { $0.timestamp >= cutoff }

        if let data = try? JSONEncoder().encode(usageHistory) {
            UserDefaults.standard.set(data, forKey: usageHistoryKey)
        }
    }

    private func loadUsageHistory() {
        if let data = UserDefaults.standard.data(forKey: usageHistoryKey),
           let history = try? JSONDecoder().decode([UsageRecord].self, from: data) {
            usageHistory = history
        }
    }

    /// Clear all usage history
    func clearHistory() {
        usageHistory = []
        currentSessionCost = 0
        todayCost = 0
        monthCost = 0
        conversationCosts = [:]
        saveUsageHistory()
    }

    /// Reset session cost
    func resetSessionCost() {
        currentSessionCost = 0
    }

    // MARK: - Cache Statistics

    /// Record cache statistics for a request
    func recordCacheStats(cacheHit: Bool, cacheReadTokens: Int, cacheWriteTokens: Int) {
        if cacheHit {
            sessionCacheHits += 1
            totalCacheHits += 1
        } else if cacheWriteTokens > 0 {
            sessionCacheMisses += 1
            totalCacheMisses += 1
        }

        sessionCacheReadTokens += cacheReadTokens
        sessionCacheWriteTokens += cacheWriteTokens
        totalCacheReadTokens += cacheReadTokens
        totalCacheWriteTokens += cacheWriteTokens

        // Calculate estimated savings (cache reads are 10% of normal cost)
        // So savings = 90% of what those tokens would have cost at full price
        if cacheReadTokens > 0 {
            // Use average pricing for estimation (roughly $3/MTok for input)
            let normalCost = Double(cacheReadTokens) / 1_000_000 * 3.0
            let cachedCost = Double(cacheReadTokens) / 1_000_000 * 0.30
            estimatedCacheSavings += (normalCost - cachedCost)
        }

        saveCacheStats()
    }

    /// Get cache hit rate as a percentage
    var cacheHitRate: Double {
        let total = sessionCacheHits + sessionCacheMisses
        guard total > 0 else { return 0 }
        return Double(sessionCacheHits) / Double(total) * 100
    }

    /// Get total cache hit rate as a percentage
    var totalCacheHitRate: Double {
        let total = totalCacheHits + totalCacheMisses
        guard total > 0 else { return 0 }
        return Double(totalCacheHits) / Double(total) * 100
    }

    /// Reset session cache statistics
    func resetSessionCacheStats() {
        sessionCacheHits = 0
        sessionCacheMisses = 0
        sessionCacheReadTokens = 0
        sessionCacheWriteTokens = 0
    }

    /// Reset all cache statistics
    func resetAllCacheStats() {
        resetSessionCacheStats()
        totalCacheHits = 0
        totalCacheMisses = 0
        totalCacheReadTokens = 0
        totalCacheWriteTokens = 0
        estimatedCacheSavings = 0
        saveCacheStats()
    }

    private let cacheStatsKey = "prompt_cache_stats"

    private func saveCacheStats() {
        let stats: [String: Any] = [
            "totalCacheHits": totalCacheHits,
            "totalCacheMisses": totalCacheMisses,
            "totalCacheReadTokens": totalCacheReadTokens,
            "totalCacheWriteTokens": totalCacheWriteTokens,
            "estimatedCacheSavings": estimatedCacheSavings
        ]
        UserDefaults.standard.set(stats, forKey: cacheStatsKey)
    }

    private func loadCacheStats() {
        if let stats = UserDefaults.standard.dictionary(forKey: cacheStatsKey) {
            totalCacheHits = stats["totalCacheHits"] as? Int ?? 0
            totalCacheMisses = stats["totalCacheMisses"] as? Int ?? 0
            totalCacheReadTokens = stats["totalCacheReadTokens"] as? Int ?? 0
            totalCacheWriteTokens = stats["totalCacheWriteTokens"] as? Int ?? 0
            estimatedCacheSavings = stats["estimatedCacheSavings"] as? Double ?? 0
        }
    }
}

// MARK: - Cost Display View

struct CostDisplayView: View {
    @ObservedObject private var tracker = CostTracker.shared
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        if settings.showCost {
            HStack(spacing: 4) {
                Image(systemName: "dollarsign.circle")
                    .font(.system(size: 10))
                Text(formatCost(tracker.currentSessionCost))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))

                // Show cache indicator if caching is active
                if settings.enablePromptCaching && tracker.sessionCacheHits > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 8))
                        Text(String(format: "%.0f%%", tracker.cacheHitRate))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                    }
                    .foregroundStyle(Color(hex: "00976d"))
                }
            }
            .foregroundStyle(.secondary)
            .help(buildTooltip())
        }
    }

    private func buildTooltip() -> String {
        var tooltip = """
        Session cost: \(formatCost(tracker.currentSessionCost))
        Today: \(formatCost(tracker.todayCost))
        This month: \(formatCost(tracker.monthCost))
        """

        if settings.enablePromptCaching {
            tooltip += "\n\nCache Statistics:"
            tooltip += "\nHit rate: \(String(format: "%.1f%%", tracker.cacheHitRate))"
            tooltip += "\nCached tokens: \(formatTokens(tracker.sessionCacheReadTokens))"
            tooltip += "\nSavings: \(formatCost(tracker.estimatedCacheSavings))"
        }

        return tooltip
    }

    private func formatCost(_ cost: Double) -> String {
        if cost < 0.01 {
            return String(format: "$%.4f", cost)
        } else if cost < 1 {
            return String(format: "$%.3f", cost)
        } else {
            return String(format: "$%.2f", cost)
        }
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

// MARK: - Cost Details View

private let costDarkBase = Color(hex: "1c1d1f")
private let costDarkSurface = Color(hex: "232426")
private let costDarkBorder = Color(hex: "2d2e30")
private let costTextPrimary = Color.white
private let costTextSecondary = Color(hex: "808080")
private let costAccent = Color(hex: "00976d")

struct CostDetailsView: View {
    @ObservedObject private var tracker = CostTracker.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Cost & Usage")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(costTextPrimary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(costTextSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(costDarkBase)

            Rectangle().fill(costDarkBorder).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Summary cards
                    HStack(spacing: 16) {
                        CostCard(title: "Session", cost: tracker.currentSessionCost, icon: "clock")
                        CostCard(title: "Today", cost: tracker.todayCost, icon: "sun.max")
                        CostCard(title: "This Month", cost: tracker.monthCost, icon: "calendar")
                    }

                    Rectangle().fill(costDarkBorder).frame(height: 1)

                    // Daily chart
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Last 7 Days")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(costTextPrimary)

                        DailyCostChart(data: tracker.dailyCosts(days: 7))
                            .frame(height: 150)
                    }

                    Rectangle().fill(costDarkBorder).frame(height: 1)

                    // All time
                    HStack {
                        Text("All Time Total")
                            .font(.system(size: 13))
                            .foregroundStyle(costTextSecondary)
                        Spacer()
                        Text(formatCost(tracker.allTimeCost))
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundStyle(costAccent)
                    }

                    HStack {
                        Spacer()
                        Button("Clear History") {
                            tracker.clearHistory()
                        }
                        .buttonStyle(.bordered)
                        .foregroundStyle(costTextSecondary)
                    }
                }
                .padding()
            }
            .background(costDarkBase)
        }
        .frame(width: 400, height: 450)
        .background(costDarkBase)
    }

    private func formatCost(_ cost: Double) -> String {
        if cost < 0.01 {
            return String(format: "$%.4f", cost)
        } else if cost < 1 {
            return String(format: "$%.3f", cost)
        } else {
            return String(format: "$%.2f", cost)
        }
    }
}

struct CostCard: View {
    let title: String
    let cost: Double
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(costTextSecondary)
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(costTextSecondary)
            }
            Text(formatCost(cost))
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundStyle(costTextPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(costDarkSurface)
        .cornerRadius(10)
    }

    private func formatCost(_ cost: Double) -> String {
        if cost < 0.01 {
            return String(format: "$%.4f", cost)
        } else if cost < 1 {
            return String(format: "$%.3f", cost)
        } else {
            return String(format: "$%.2f", cost)
        }
    }
}

struct DailyCostChart: View {
    let data: [(date: Date, cost: Double)]

    var body: some View {
        GeometryReader { geometry in
            let maxCost = data.map(\.cost).max() ?? 1
            let barWidth = (geometry.size.width - CGFloat(data.count - 1) * 4) / CGFloat(data.count)

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                    VStack(spacing: 4) {
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [costAccent, Color(hex: "5a9bd5")],
                                startPoint: .bottom,
                                endPoint: .top
                            ))
                            .frame(
                                width: barWidth,
                                height: max(4, (item.cost / maxCost) * (geometry.size.height - 30))
                            )
                            .cornerRadius(4)

                        Text(dayLabel(item.date))
                            .font(.system(size: 9))
                            .foregroundStyle(costTextSecondary)
                    }
                }
            }
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}

#Preview {
    CostDetailsView()
}
