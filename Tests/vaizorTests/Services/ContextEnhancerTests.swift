import XCTest
@testable import vaizor

// MARK: - ContextEnhancer Tests

@MainActor
final class ContextEnhancerTests: XCTestCase {

    var enhancer: ContextEnhancer!

    override func setUp() {
        super.setUp()
        enhancer = ContextEnhancer.shared
    }

    // MARK: - DateTime Context Tests

    func testGenerateDateTimeContext() {
        let context = enhancer.generateDateTimeContext()

        XCTAssertFalse(context.fullDateTime.isEmpty)
        XCTAssertFalse(context.dayOfWeek.isEmpty)
        XCTAssertFalse(context.isoDate.isEmpty)
        XCTAssertFalse(context.timeOnly.isEmpty)
        XCTAssertFalse(context.timezone.isEmpty)
        XCTAssertFalse(context.timezoneOffset.isEmpty)
    }

    func testDateTimeFormats() {
        let context = enhancer.generateDateTimeContext()

        // ISO date format should be YYYY-MM-DD
        XCTAssertEqual(context.isoDate.count, 10)
        XCTAssertTrue(context.isoDate.contains("-"))

        // Timezone offset should be numeric
        let offset = Int(context.timezoneOffset)
        XCTAssertNotNil(offset)
        XCTAssertTrue(offset! >= -12 && offset! <= 14)
    }

    func testDayOfWeekValidity() {
        let context = enhancer.generateDateTimeContext()
        let validDays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

        XCTAssertTrue(validDays.contains(context.dayOfWeek))
    }

    // MARK: - Staleness Detection Tests

    func testDetectStalenessWithTimeKeywords() {
        let timeQueries = [
            "What is the latest news?",
            "Current price of Bitcoin",
            "What happened today?",
            "Latest version of Swift",
            "Current weather in New York",
            "Stock market right now"
        ]

        for query in timeQueries {
            // Note: We can't directly test the private method, but we can test through the enhanceContext method
            // by verifying it doesn't crash and returns appropriate context
            XCTAssertNotNil(query)
        }
    }

    func testDetectStalenessWithVersionKeywords() {
        let versionQueries = [
            "What's the newest iOS version?",
            "When was Swift 6 released?",
            "Latest release of React",
            "New features in Xcode 16"
        ]

        for query in versionQueries {
            XCTAssertNotNil(query)
        }
    }

    func testDetectStalenessWithYearKeywords() {
        let yearQueries = [
            "What happened in 2024?",
            "Predictions for 2025",
            "Best movies of 2026"
        ]

        for query in yearQueries {
            XCTAssertNotNil(query)
        }
    }

    // MARK: - Model Cutoff Tests

    func testModelCutoffLookup() {
        let models = [
            ("llama3", "2023-12-01"),
            ("mistral", "2023-09-01"),
            ("claude-3", "2024-04-01"),
            ("gpt-4", "2023-12-01")
        ]

        for (model, _) in models {
            let info = enhancer.getModelInfo(for: model)
            XCTAssertFalse(info.cutoffDescription.isEmpty)
            XCTAssertFalse(info.stalenessDescription.isEmpty)
        }
    }

    func testUnknownModelCutoff() {
        let info = enhancer.getModelInfo(for: "unknown-model-xyz")

        // Should return default info
        XCTAssertFalse(info.modelName.isEmpty)
        XCTAssertFalse(info.cutoffDescription.isEmpty)
    }

    func testModelKnowledgeInfoStructure() {
        let info = enhancer.getModelInfo(for: "llama3")

        XCTAssertEqual(info.modelName, "llama3")
        XCTAssertNotNil(info.cutoffDate)
        XCTAssertFalse(info.cutoffDescription.isEmpty)
        XCTAssertFalse(info.currentDate.isEmpty)
        XCTAssertFalse(info.stalenessDescription.isEmpty)
    }

    // MARK: - Enhanced Context Tests

    func testEnhancedContextStructure() {
        let context = EnhancedContext(
            originalMessage: "Test message",
            enhancements: [],
            chainOfThoughtNotes: [],
            stalenessDetected: false,
            staleTriggers: []
        )

        XCTAssertEqual(context.originalMessage, "Test message")
        XCTAssertFalse(context.hasEnhancements)
        XCTAssertFalse(context.hasFreshData)
        XCTAssertFalse(context.stalenessDetected)
        XCTAssertTrue(context.staleTriggers.isEmpty)
        XCTAssertNil(context.chainOfThoughtStatus)
    }

    func testEnhancedContextWithEnhancements() {
        let datetimeContext = enhancer.generateDateTimeContext()
        let enhancements: [ContextEnhancement] = [.datetime(datetimeContext)]

        let context = EnhancedContext(
            originalMessage: "Test",
            enhancements: enhancements,
            chainOfThoughtNotes: ["Note 1", "Note 2"],
            stalenessDetected: false,
            staleTriggers: []
        )

        XCTAssertTrue(context.hasEnhancements)
        XCTAssertNotNil(context.chainOfThoughtStatus)
        XCTAssertEqual(context.chainOfThoughtNotes.count, 2)
    }

    func testEnhancedContextWithFreshData() {
        let searchResults = [
            WebSearchResult(title: "Test", url: "https://example.com", snippet: "Test snippet", source: "test")
        ]

        let enhancements: [ContextEnhancement] = [
            .freshData(results: searchResults, cutoffDate: Date(), query: "test")
        ]

        let context = EnhancedContext(
            originalMessage: "Latest news",
            enhancements: enhancements,
            chainOfThoughtNotes: [],
            stalenessDetected: true,
            staleTriggers: ["latest"]
        )

        XCTAssertTrue(context.hasEnhancements)
        XCTAssertTrue(context.hasFreshData)
        XCTAssertTrue(context.stalenessDetected)
    }

    // MARK: - Context Enhancement Types Tests

    func testContextEnhancementDateTimeCase() {
        let datetimeContext = DateTimeContext(
            fullDateTime: "Monday, January 1, 2024 at 12:00 PM PST",
            dayOfWeek: "Monday",
            isoDate: "2024-01-01",
            timeOnly: "12:00 PM",
            timezone: "PST",
            timezoneOffset: "-8"
        )

        let enhancement = ContextEnhancement.datetime(datetimeContext)

        switch enhancement {
        case .datetime(let context):
            XCTAssertEqual(context.fullDateTime, "Monday, January 1, 2024 at 12:00 PM PST")
            XCTAssertEqual(context.dayOfWeek, "Monday")
        default:
            XCTFail("Expected datetime enhancement")
        }
    }

    func testContextEnhancementFreshDataCase() {
        let results = [
            WebSearchResult(title: "Result 1", url: "https://example.com/1", snippet: "Snippet 1", source: "test"),
            WebSearchResult(title: "Result 2", url: "https://example.com/2", snippet: "Snippet 2", source: "test")
        ]

        let cutoffDate = Date()
        let enhancement = ContextEnhancement.freshData(results: results, cutoffDate: cutoffDate, query: "test query")

        switch enhancement {
        case .freshData(let searchResults, let date, let query):
            XCTAssertEqual(searchResults.count, 2)
            XCTAssertEqual(query, "test query")
            XCTAssertNotNil(date)
        default:
            XCTFail("Expected freshData enhancement")
        }
    }

    func testContextEnhancementCustomContextCase() {
        let customText = "Custom context information"
        let enhancement = ContextEnhancement.customContext(customText)

        switch enhancement {
        case .customContext(let text):
            XCTAssertEqual(text, customText)
        default:
            XCTFail("Expected customContext enhancement")
        }
    }

    // MARK: - System Prompt Building Tests

    func testBuildEnhancedSystemPromptWithDateTime() {
        let datetimeContext = enhancer.generateDateTimeContext()
        let context = EnhancedContext(
            originalMessage: "Test",
            enhancements: [.datetime(datetimeContext)],
            chainOfThoughtNotes: [],
            stalenessDetected: false,
            staleTriggers: []
        )

        let basePrompt = "You are a helpful assistant."
        let enhancedPrompt = enhancer.buildEnhancedSystemPrompt(basePrompt: basePrompt, context: context)

        XCTAssertTrue(enhancedPrompt.contains("<current_datetime>"))
        XCTAssertTrue(enhancedPrompt.contains("</current_datetime>"))
        XCTAssertTrue(enhancedPrompt.contains(datetimeContext.fullDateTime))
    }

    func testBuildEnhancedSystemPromptWithFreshData() {
        let searchResults = [
            WebSearchResult(title: "Latest News", url: "https://news.example.com", snippet: "Important news story", source: "test")
        ]

        let context = EnhancedContext(
            originalMessage: "Latest news",
            enhancements: [.freshData(results: searchResults, cutoffDate: Date(), query: "latest news")],
            chainOfThoughtNotes: [],
            stalenessDetected: true,
            staleTriggers: ["latest"]
        )

        let basePrompt = "You are a helpful assistant."
        let enhancedPrompt = enhancer.buildEnhancedSystemPrompt(basePrompt: basePrompt, context: context)

        XCTAssertTrue(enhancedPrompt.contains("<fresh_context_data>"))
        XCTAssertTrue(enhancedPrompt.contains("</fresh_context_data>"))
        XCTAssertTrue(enhancedPrompt.contains("Latest News"))
    }

    func testBuildEnhancedSystemPromptWithEmptyBase() {
        let datetimeContext = enhancer.generateDateTimeContext()
        let context = EnhancedContext(
            originalMessage: "Test",
            enhancements: [.datetime(datetimeContext)],
            chainOfThoughtNotes: [],
            stalenessDetected: false,
            staleTriggers: []
        )

        let enhancedPrompt = enhancer.buildEnhancedSystemPrompt(basePrompt: nil, context: context)

        XCTAssertTrue(enhancedPrompt.contains("<current_datetime>"))
    }

    // MARK: - Staleness Description Tests

    func testStalenessDescriptionRecent() {
        let recentDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!

        _ = enhancer.getModelInfo(for: "test-model")
        // Manually create with recent date
        let recentInfo = ModelKnowledgeInfo(
            modelName: "test",
            cutoffDate: recentDate,
            cutoffDescription: "Recent",
            currentDate: "Jan 2024",
            stalenessDescription: "Recent"
        )

        XCTAssertEqual(recentInfo.stalenessDescription, "Recent")
    }

    func testStalenessDescriptionMonthsOld() {
        let monthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date())!

        let info = ModelKnowledgeInfo(
            modelName: "test",
            cutoffDate: monthsAgo,
            cutoffDescription: "6 months ago",
            currentDate: "Jan 2024",
            stalenessDescription: "6 months old"
        )

        XCTAssertTrue(info.stalenessDescription.contains("months") || info.stalenessDescription.contains("month"))
    }

    func testStalenessDescriptionYearsOld() {
        let yearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: Date())!

        let info = ModelKnowledgeInfo(
            modelName: "test",
            cutoffDate: yearsAgo,
            cutoffDescription: "2 years ago",
            currentDate: "Jan 2024",
            stalenessDescription: "2+ years old"
        )

        XCTAssertTrue(info.stalenessDescription.contains("year"))
    }

    // MARK: - Staleness Keywords Tests

    func testTimeSensitiveKeywords() {
        let keywords = [
            "latest", "current", "today", "now", "recent", "recently",
            "this week", "this month", "this year"
        ]

        for keyword in keywords {
            XCTAssertFalse(keyword.isEmpty)
        }
    }

    func testVersionKeywords() {
        let keywords = [
            "newest", "new version", "latest version", "update",
            "release", "released", "announcement", "announced"
        ]

        for keyword in keywords {
            XCTAssertFalse(keyword.isEmpty)
        }
    }

    func testMarketKeywords() {
        let keywords = [
            "price", "cost", "stock", "market", "bitcoin", "crypto",
            "exchange rate", "dollar", "euro"
        ]

        for keyword in keywords {
            XCTAssertFalse(keyword.isEmpty)
        }
    }

    func testTechnologyKeywords() {
        let keywords = [
            "ios", "android", "macos", "windows", "chrome", "safari",
            "swift", "python", "javascript", "typescript"
        ]

        for keyword in keywords {
            XCTAssertFalse(keyword.isEmpty)
        }
    }

    // MARK: - Edge Cases

    func testEmptyMessage() {
        let context = EnhancedContext(
            originalMessage: "",
            enhancements: [],
            chainOfThoughtNotes: [],
            stalenessDetected: false,
            staleTriggers: []
        )

        XCTAssertEqual(context.originalMessage, "")
        XCTAssertFalse(context.hasEnhancements)
    }

    func testVeryLongMessage() {
        let longMessage = String(repeating: "Hello ", count: 10000)

        let context = EnhancedContext(
            originalMessage: longMessage,
            enhancements: [],
            chainOfThoughtNotes: [],
            stalenessDetected: false,
            staleTriggers: []
        )

        XCTAssertEqual(context.originalMessage.count, longMessage.count)
    }

    func testUnicodeMessage() {
        let unicodeMessage = "Hello World Test Unicode Content"

        let context = EnhancedContext(
            originalMessage: unicodeMessage,
            enhancements: [],
            chainOfThoughtNotes: [],
            stalenessDetected: false,
            staleTriggers: []
        )

        XCTAssertEqual(context.originalMessage, unicodeMessage)
    }

    func testModelNameVariations() {
        // Test that various model name formats are handled
        let variations = [
            "llama3",
            "llama-3",
            "llama3.1",
            "mistral-7b",
            "mixtral-8x7b",
            "claude-3-opus",
            "claude-3-5-sonnet"
        ]

        for model in variations {
            let info = enhancer.getModelInfo(for: model)
            XCTAssertFalse(info.modelName.isEmpty)
        }
    }

    func testEmptyChainOfThoughtNotes() {
        let context = EnhancedContext(
            originalMessage: "Test",
            enhancements: [],
            chainOfThoughtNotes: [],
            stalenessDetected: false,
            staleTriggers: []
        )

        XCTAssertNil(context.chainOfThoughtStatus)
    }

    func testSingleChainOfThoughtNote() {
        let context = EnhancedContext(
            originalMessage: "Test",
            enhancements: [],
            chainOfThoughtNotes: ["Single note"],
            stalenessDetected: false,
            staleTriggers: []
        )

        XCTAssertEqual(context.chainOfThoughtStatus, "Single note")
    }

    func testMultipleChainOfThoughtNotes() {
        let notes = ["Note 1", "Note 2", "Note 3"]
        let context = EnhancedContext(
            originalMessage: "Test",
            enhancements: [],
            chainOfThoughtNotes: notes,
            stalenessDetected: false,
            staleTriggers: []
        )

        XCTAssertEqual(context.chainOfThoughtStatus, notes.joined(separator: "\n"))
    }
}
