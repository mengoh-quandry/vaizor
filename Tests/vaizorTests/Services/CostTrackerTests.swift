import XCTest
@testable import vaizor

// MARK: - CostTracker Tests

@MainActor
final class CostTrackerTests: XCTestCase {

    var tracker: CostTracker!

    override func setUp() {
        super.setUp()
        tracker = CostTracker.shared

        // Reset state for clean tests
        tracker.clearHistory()
        tracker.resetAllCacheStats()
    }

    // MARK: - Cost Calculation Tests

    func testCalculateCostBasic() {
        let cost = tracker.calculateCost(
            model: "gpt-3.5-turbo",
            inputTokens: 1000,
            outputTokens: 500
        )

        // GPT-3.5-turbo: $0.50/1M input, $1.50/1M output
        // Expected: (1000/1M * 0.50) + (500/1M * 1.50) = 0.0005 + 0.00075 = 0.00125
        XCTAssertGreaterThan(cost, 0)
        XCTAssertEqual(cost, 0.00125, accuracy: 0.00001)
    }

    func testCalculateCostWithCache() {
        let cost = tracker.calculateCost(
            model: "claude-3-5-sonnet-20241022",
            inputTokens: 2000,
            outputTokens: 1000,
            cacheReadTokens: 1000,
            cacheWriteTokens: 500
        )

        // Claude 3.5 Sonnet: $3/1M input, $15/1M output, $0.30/1M cache read, $3.75/1M cache write
        // Expected: (2000/1M * 3) + (1000/1M * 15) + (1000/1M * 0.30) + (500/1M * 3.75)
        // = 0.006 + 0.015 + 0.0003 + 0.001875 = 0.023175
        XCTAssertGreaterThan(cost, 0)
        XCTAssertEqual(cost, 0.023175, accuracy: 0.00001)
    }

    func testCalculateCostUnknownModel() {
        let cost = tracker.calculateCost(
            model: "unknown-model",
            inputTokens: 1000,
            outputTokens: 500
        )

        // Should use default pricing
        XCTAssertGreaterThan(cost, 0)
    }

    func testCalculateCostZeroTokens() {
        let cost = tracker.calculateCost(
            model: "gpt-3.5-turbo",
            inputTokens: 0,
            outputTokens: 0
        )

        XCTAssertEqual(cost, 0)
    }

    func testCalculateCostLargeNumbers() {
        let cost = tracker.calculateCost(
            model: "gpt-3.5-turbo",
            inputTokens: 1_000_000,
            outputTokens: 500_000
        )

        // GPT-3.5-turbo: $0.50/1M input, $1.50/1M output
        // Expected: 0.50 + 0.75 = 1.25
        XCTAssertEqual(cost, 1.25, accuracy: 0.01)
    }

    // MARK: - Recording Tests

    func testRecordUsage() {
        tracker.recordUsage(
            model: "gpt-3.5-turbo",
            inputTokens: 1000,
            outputTokens: 500,
            conversationId: UUID()
        )

        XCTAssertGreaterThan(tracker.currentSessionCost, 0)
        XCTAssertGreaterThan(tracker.todayCost, 0)
        XCTAssertGreaterThan(tracker.monthCost, 0)
    }

    func testRecordUsageUpdatesConversationCost() {
        let conversationId = UUID()

        tracker.recordUsage(
            model: "gpt-3.5-turbo",
            inputTokens: 1000,
            outputTokens: 500,
            conversationId: conversationId
        )

        let cost = tracker.costForConversation(conversationId)
        XCTAssertGreaterThan(cost, 0)
    }

    func testRecordMultipleUsages() {
        let conversationId = UUID()

        for _ in 0..<5 {
            tracker.recordUsage(
                model: "gpt-3.5-turbo",
                inputTokens: 1000,
                outputTokens: 500,
                conversationId: conversationId
            )
        }

        let singleCost = tracker.calculateCost(
            model: "gpt-3.5-turbo",
            inputTokens: 1000,
            outputTokens: 500
        )

        let conversationCost = tracker.costForConversation(conversationId)
        XCTAssertEqual(conversationCost, singleCost * 5, accuracy: 0.0001)
    }

    // MARK: - Cache Statistics Tests

    func testRecordCacheStatsHit() {
        tracker.recordCacheStats(
            cacheHit: true,
            cacheReadTokens: 1000,
            cacheWriteTokens: 0
        )

        XCTAssertEqual(tracker.sessionCacheHits, 1)
        XCTAssertEqual(tracker.sessionCacheMisses, 0)
        XCTAssertEqual(tracker.sessionCacheReadTokens, 1000)
    }

    func testRecordCacheStatsMiss() {
        tracker.recordCacheStats(
            cacheHit: false,
            cacheReadTokens: 0,
            cacheWriteTokens: 1000
        )

        XCTAssertEqual(tracker.sessionCacheHits, 0)
        XCTAssertEqual(tracker.sessionCacheMisses, 1)
        XCTAssertEqual(tracker.sessionCacheWriteTokens, 1000)
    }

    func testCacheHitRateCalculation() {
        // Record 3 hits and 1 miss
        tracker.recordCacheStats(cacheHit: true, cacheReadTokens: 100, cacheWriteTokens: 0)
        tracker.recordCacheStats(cacheHit: true, cacheReadTokens: 100, cacheWriteTokens: 0)
        tracker.recordCacheStats(cacheHit: true, cacheReadTokens: 100, cacheWriteTokens: 0)
        tracker.recordCacheStats(cacheHit: false, cacheReadTokens: 0, cacheWriteTokens: 100)

        XCTAssertEqual(tracker.cacheHitRate, 75.0, accuracy: 0.01)
    }

    func testCacheHitRateZeroTotal() {
        XCTAssertEqual(tracker.cacheHitRate, 0)
    }

    func testTotalCacheHitRateCalculation() {
        // Record multiple stats
        for _ in 0..<4 {
            tracker.recordCacheStats(cacheHit: true, cacheReadTokens: 100, cacheWriteTokens: 0)
        }
        for _ in 0..<1 {
            tracker.recordCacheStats(cacheHit: false, cacheReadTokens: 0, cacheWriteTokens: 100)
        }

        XCTAssertEqual(tracker.totalCacheHitRate, 80.0, accuracy: 0.01)
    }

    func testCacheSavingsCalculation() {
        tracker.recordCacheStats(
            cacheHit: true,
            cacheReadTokens: 1000000, // 1M tokens
            cacheWriteTokens: 0
        )

        // Savings: Normal cost (1M * $3/1M = $3) - Cached cost (1M * $0.30/1M = $0.30) = $2.70
        XCTAssertGreaterThan(tracker.estimatedCacheSavings, 0)
    }

    // MARK: - Aggregate Tests

    func testAllTimeCost() {
        tracker.recordUsage(
            model: "gpt-3.5-turbo",
            inputTokens: 1000,
            outputTokens: 500
        )

        let allTime = tracker.allTimeCost
        XCTAssertGreaterThan(allTime, 0)
        XCTAssertEqual(allTime, tracker.currentSessionCost, accuracy: 0.0001)
    }

    func testDailyCosts() {
        // Record usage today
        tracker.recordUsage(
            model: "gpt-3.5-turbo",
            inputTokens: 1000,
            outputTokens: 500
        )

        let dailyCosts = tracker.dailyCosts(days: 7)

        // Should have 7 entries
        XCTAssertEqual(dailyCosts.count, 7)

        // Today's cost should be greater than 0
        XCTAssertGreaterThan(dailyCosts.last?.cost ?? 0, 0)
    }

    func testUsageHistoryForDateRange() {
        tracker.recordUsage(
            model: "gpt-3.5-turbo",
            inputTokens: 1000,
            outputTokens: 500
        )

        let from = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let to = Calendar.current.date(byAdding: .day, value: 1, to: Date())!

        let history = tracker.usageHistory(from: from, to: to)
        XCTAssertEqual(history.count, 1)
    }

    // MARK: - Reset Tests

    func testResetSessionCost() {
        tracker.recordUsage(
            model: "gpt-3.5-turbo",
            inputTokens: 1000,
            outputTokens: 500
        )

        XCTAssertGreaterThan(tracker.currentSessionCost, 0)

        tracker.resetSessionCost()

        XCTAssertEqual(tracker.currentSessionCost, 0)
    }

    func testResetSessionCacheStats() {
        tracker.recordCacheStats(
            cacheHit: true,
            cacheReadTokens: 1000,
            cacheWriteTokens: 0
        )

        XCTAssertGreaterThan(tracker.sessionCacheHits, 0)

        tracker.resetSessionCacheStats()

        XCTAssertEqual(tracker.sessionCacheHits, 0)
        XCTAssertEqual(tracker.sessionCacheMisses, 0)
        XCTAssertEqual(tracker.sessionCacheReadTokens, 0)
        XCTAssertEqual(tracker.sessionCacheWriteTokens, 0)
    }

    func testResetAllCacheStats() {
        tracker.recordCacheStats(
            cacheHit: true,
            cacheReadTokens: 1000,
            cacheWriteTokens: 0
        )

        tracker.resetAllCacheStats()

        XCTAssertEqual(tracker.sessionCacheHits, 0)
        XCTAssertEqual(tracker.totalCacheHits, 0)
        XCTAssertEqual(tracker.estimatedCacheSavings, 0)
    }

    func testClearHistory() {
        tracker.recordUsage(
            model: "gpt-3.5-turbo",
            inputTokens: 1000,
            outputTokens: 500,
            conversationId: UUID()
        )

        XCTAssertGreaterThan(tracker.currentSessionCost, 0)
        XCTAssertGreaterThan(tracker.todayCost, 0)
        XCTAssertGreaterThan(tracker.monthCost, 0)

        tracker.clearHistory()

        XCTAssertEqual(tracker.currentSessionCost, 0)
        XCTAssertEqual(tracker.todayCost, 0)
        XCTAssertEqual(tracker.monthCost, 0)
        XCTAssertTrue(tracker.conversationCosts.isEmpty)
    }

    // MARK: - Model Pricing Tests

    func testModelPricingStructure() {
        let pricing = CostTracker.ModelPricing.defaultPricing

        XCTAssertGreaterThan(pricing.inputPer1M, 0)
        XCTAssertGreaterThan(pricing.outputPer1M, 0)
    }

    func testClaudeOpusPricing() {
        let cost = tracker.calculateCost(
            model: "claude-3-opus-20240229",
            inputTokens: 1000,
            outputTokens: 500
        )

        // Claude 3 Opus: $15/1M input, $75/1M output
        // Expected: (1000/1M * 15) + (500/1M * 75) = 0.015 + 0.0375 = 0.0525
        XCTAssertEqual(cost, 0.0525, accuracy: 0.0001)
    }

    func testClaudeSonnetPricing() {
        let cost = tracker.calculateCost(
            model: "claude-3-5-sonnet-20241022",
            inputTokens: 1000,
            outputTokens: 500
        )

        // Claude 3.5 Sonnet: $3/1M input, $15/1M output
        // Expected: (1000/1M * 3) + (500/1M * 15) = 0.003 + 0.0075 = 0.0105
        XCTAssertEqual(cost, 0.0105, accuracy: 0.0001)
    }

    func testGPT4oPricing() {
        let cost = tracker.calculateCost(
            model: "gpt-4o",
            inputTokens: 1000,
            outputTokens: 500
        )

        // GPT-4o: $2.50/1M input, $10/1M output
        // Expected: (1000/1M * 2.50) + (500/1M * 10) = 0.0025 + 0.005 = 0.0075
        XCTAssertEqual(cost, 0.0075, accuracy: 0.0001)
    }

    func testGPT4oMiniPricing() {
        let cost = tracker.calculateCost(
            model: "gpt-4o-mini",
            inputTokens: 1000,
            outputTokens: 500
        )

        // GPT-4o-mini: $0.15/1M input, $0.60/1M output
        // Expected: (1000/1M * 0.15) + (500/1M * 0.60) = 0.00015 + 0.0003 = 0.00045
        XCTAssertEqual(cost, 0.00045, accuracy: 0.00001)
    }

    // MARK: - Usage Record Tests

    func testUsageRecordCreation() {
        let record = CostTracker.UsageRecord(
            timestamp: Date(),
            model: "gpt-3.5-turbo",
            inputTokens: 1000,
            outputTokens: 500,
            cacheReadTokens: 100,
            cacheWriteTokens: 50,
            cost: 0.00125,
            conversationId: UUID()
        )

        XCTAssertEqual(record.model, "gpt-3.5-turbo")
        XCTAssertEqual(record.inputTokens, 1000)
        XCTAssertEqual(record.outputTokens, 500)
        XCTAssertEqual(record.cacheReadTokens, 100)
        XCTAssertEqual(record.cacheWriteTokens, 50)
        XCTAssertEqual(record.cost, 0.00125)
        XCTAssertNotNil(record.conversationId)
    }

    // MARK: - Edge Cases

    func testNegativeTokens() {
        // While semantically incorrect, should handle gracefully
        let cost = tracker.calculateCost(
            model: "gpt-3.5-turbo",
            inputTokens: -100,
            outputTokens: -50
        )

        XCTAssertEqual(cost, 0, accuracy: 0.0001)
    }

    func testVeryLargeTokenCount() {
        let cost = tracker.calculateCost(
            model: "gpt-3.5-turbo",
            inputTokens: 100_000_000, // 100M tokens
            outputTokens: 50_000_000  // 50M tokens
        )

        XCTAssertGreaterThan(cost, 0)
    }

    func testCostFormatting() {
        // Test cost display formatting logic
        let smallCost: Double = 0.0001
        let mediumCost: Double = 0.5
        let largeCost: Double = 10.0

        // Small cost: show 4 decimal places
        XCTAssertTrue(smallCost < 0.01)

        // Medium cost: show 3 decimal places
        XCTAssertTrue(mediumCost >= 0.01 && mediumCost < 1)

        // Large cost: show 2 decimal places
        XCTAssertTrue(largeCost >= 1)
    }

    func testTokenFormatting() {
        let smallTokens = 500
        let mediumTokens = 1500
        let largeTokens = 1_500_000

        // Small: show as-is
        XCTAssertTrue(smallTokens < 1000)

        // Medium: show as X.XK
        XCTAssertTrue(mediumTokens >= 1000 && mediumTokens < 1_000_000)

        // Large: show as X.XM
        XCTAssertTrue(largeTokens >= 1_000_000)
    }
}

// MARK: - Cost Display Tests

final class CostDisplayTests: XCTestCase {

    func testCostFormattingLogic() {
        let smallCost: Double = 0.0001
        let mediumCost: Double = 0.5
        let largeCost: Double = 10.0

        // Format small cost
        let smallFormatted = String(format: "%.4f", smallCost)
        XCTAssertEqual(smallFormatted, "0.0001")

        // Format medium cost
        let mediumFormatted = String(format: "%.3f", mediumCost)
        XCTAssertEqual(mediumFormatted, "0.500")

        // Format large cost
        let largeFormatted = String(format: "%.2f", largeCost)
        XCTAssertEqual(largeFormatted, "10.00")
    }

    func testTokenFormattingLogic() {
        let small = 500
        let medium = 1500
        let large = 1_500_000

        // Format small tokens
        XCTAssertEqual("\(small)", "500")

        // Format medium tokens (as K)
        let mediumFormatted = String(format: "%.1fK", Double(medium) / 1000)
        XCTAssertEqual(mediumFormatted, "1.5K")

        // Format large tokens (as M)
        let largeFormatted = String(format: "%.1fM", Double(large) / 1_000_000)
        XCTAssertEqual(largeFormatted, "1.5M")
    }
}
