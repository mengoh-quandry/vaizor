import Foundation

// MARK: - Skill System
// Self-directed skill acquisition, packaging, and management

// MARK: - Skill Gap Detection

/// Detects patterns indicating missing capabilities
actor SkillGapDetector {
    private let personalFileManager: PersonalFileManager
    private var recentFailures: [FailurePattern] = []
    private var userRequestPatterns: [RequestPattern] = []

    struct FailurePattern: Codable {
        let timestamp: Date
        let taskDescription: String
        let errorType: String
        let suggestedSkillDomain: String?
    }

    struct RequestPattern: Codable {
        let requestType: String
        var frequency: Int
        var currentCapability: Float  // 0.0-1.0
        var lastSeen: Date
    }

    init(personalFileManager: PersonalFileManager) {
        self.personalFileManager = personalFileManager
    }

    /// Analyze an interaction for potential skill gaps
    func analyzeInteraction(_ interaction: InteractionAnalysis) async -> [SkillGap]? {
        var gaps: [SkillGap] = []

        // Pattern 1: Repeated failures in same domain
        if let failure = interaction.failure {
            let pattern = FailurePattern(
                timestamp: Date(),
                taskDescription: interaction.description,
                errorType: failure.type,
                suggestedSkillDomain: inferDomain(from: failure)
            )
            recentFailures.append(pattern)

            // Clean old failures (older than 7 days)
            let weekAgo = Date().addingTimeInterval(-7 * 24 * 3600)
            recentFailures.removeAll { $0.timestamp < weekAgo }

            // If 3+ failures in same domain within 7 days
            if let domain = pattern.suggestedSkillDomain {
                let domainFailures = recentFailures.filter { $0.suggestedSkillDomain == domain }
                if domainFailures.count >= 3 {
                    gaps.append(SkillGap(
                        domain: domain,
                        severity: .high,
                        evidence: "Repeated failures: \(domainFailures.count) in 7 days",
                        suggestedAction: .acquireSkill
                    ))
                }
            }
        }

        // Pattern 2: User repeatedly asks for similar things agent can't do well
        if let request = interaction.userRequest {
            updateRequestPattern(request)

            if let pattern = userRequestPatterns.first(where: { $0.requestType == request.type }) {
                if pattern.frequency >= 5 && pattern.currentCapability < 0.5 {
                    gaps.append(SkillGap(
                        domain: request.type,
                        severity: .medium,
                        evidence: "User frequently requests (\(pattern.frequency)x) with low success",
                        suggestedAction: .acquireSkill
                    ))
                }
            }
        }

        // Pattern 3: Agent expresses uncertainty in area
        if interaction.containsUncertainty {
            let domain = interaction.uncertaintyDomain ?? "general"
            gaps.append(SkillGap(
                domain: domain,
                severity: .low,
                evidence: "Expressed uncertainty",
                suggestedAction: .research
            ))
        }

        return gaps.isEmpty ? nil : gaps
    }

    private func inferDomain(from failure: InteractionFailure) -> String? {
        // Simple domain inference based on error type
        let errorLower = failure.type.lowercased()

        if errorLower.contains("code") || errorLower.contains("syntax") || errorLower.contains("compile") {
            return "code_assistance"
        }
        if errorLower.contains("file") || errorLower.contains("path") || errorLower.contains("directory") {
            return "file_operations"
        }
        if errorLower.contains("network") || errorLower.contains("api") || errorLower.contains("http") {
            return "network_operations"
        }
        if errorLower.contains("git") || errorLower.contains("version") {
            return "version_control"
        }

        return failure.suggestedDomain
    }

    private func updateRequestPattern(_ request: UserRequest) {
        if let index = userRequestPatterns.firstIndex(where: { $0.requestType == request.type }) {
            userRequestPatterns[index].frequency += 1
            userRequestPatterns[index].lastSeen = Date()
            // Update capability based on success rate
            let successFactor: Float = request.wasSuccessful ? 0.1 : -0.05
            userRequestPatterns[index].currentCapability = max(0, min(1, userRequestPatterns[index].currentCapability + successFactor))
        } else {
            userRequestPatterns.append(RequestPattern(
                requestType: request.type,
                frequency: 1,
                currentCapability: request.wasSuccessful ? 0.6 : 0.3,
                lastSeen: Date()
            ))
        }
    }
}

// MARK: - Skill Gap Types

struct SkillGap {
    let domain: String
    let severity: GapSeverity
    let evidence: String
    let suggestedAction: GapAction
}

enum GapSeverity: Comparable {
    case low
    case medium
    case high
}

enum GapAction {
    case acquireSkill
    case research
    case askPartner
    case ignore
}

struct InteractionAnalysis {
    let description: String
    let failure: InteractionFailure?
    let userRequest: UserRequest?
    let containsUncertainty: Bool
    let uncertaintyDomain: String?
}

struct InteractionFailure {
    let type: String
    let suggestedDomain: String?
}

struct UserRequest {
    let type: String
    let wasSuccessful: Bool
}

// MARK: - Skill Acquisition Engine

/// Handles the process of acquiring new skills
actor SkillAcquisitionEngine {
    private let appendageCoordinator: AppendageCoordinator
    private let personalFileManager: PersonalFileManager
    private let skillPackageManager: SkillPackageManager

    init(
        appendageCoordinator: AppendageCoordinator,
        personalFileManager: PersonalFileManager,
        skillPackageManager: SkillPackageManager
    ) {
        self.appendageCoordinator = appendageCoordinator
        self.personalFileManager = personalFileManager
        self.skillPackageManager = skillPackageManager
    }

    /// Acquire a skill for a detected gap
    func acquireSkill(for gap: SkillGap) async throws -> AcquiredSkill {
        // Stage 1: Notify partner we're starting
        await personalFileManager.addNotification(AgentNotification(
            type: .skillAcquired,
            message: "I've noticed I struggle with \(gap.domain). I'll work on learning this in the background.",
            priority: .normal
        ))

        // Stage 2: Spawn research appendage
        let researchTask = AppendageTask(
            type: .backgroundResearch(topic: "skill development: \(gap.domain)"),
            description: "Researching \(gap.domain) capabilities",
            priority: .background,
            timeout: 300,
            notifyOnCompletion: false
        )

        let researchAppendageId = try await appendageCoordinator.spawnAppendage(for: researchTask)

        // Wait for research results
        let researchResults = try await appendageCoordinator.awaitResult(researchAppendageId)

        // Stage 3: Design skill based on research
        let skillDesign = designSkill(
            domain: gap.domain,
            research: researchResults
        )

        // Stage 4: Build skill package
        let skillPackage = try buildSkillPackage(from: skillDesign)

        // Stage 5: Test skill in sandbox
        let testResults = await testSkill(skillPackage)

        guard testResults.passRate > 0.8 else {
            throw SkillAcquisitionError.testsFailed(passRate: testResults.passRate)
        }

        // Stage 6: Install skill
        let acquiredSkill = try await skillPackageManager.install(skillPackage)
        await personalFileManager.registerSkill(acquiredSkill)

        // Stage 7: Inform partner
        await personalFileManager.addNotification(AgentNotification(
            type: .skillAcquired,
            message: "Good news! I've learned how to handle \(gap.domain). Here's what I can now do:\n\(acquiredSkill.capabilities.joined(separator: "\n- "))",
            priority: .high
        ))

        return acquiredSkill
    }

    private func designSkill(domain: String, research: AppendageResult) -> SkillDesign {
        // Use research findings to design skill structure
        return SkillDesign(
            name: domain.replacingOccurrences(of: " ", with: "_").lowercased(),
            description: "Skill for \(domain)",
            triggerPatterns: [
                ".*\(domain).*",
                "help.*(with|me).*\(domain).*"
            ],
            capabilities: research.outputData?.values.map { String($0) } ?? ["Handle \(domain) tasks"],
            dependencies: [],
            testCases: [
                SkillTestCase(
                    input: "Help me with \(domain)",
                    expectedBehavior: "Provide assistance with \(domain)",
                    successCriteria: ["Response is relevant", "No errors"]
                )
            ]
        )
    }

    private func buildSkillPackage(from design: SkillDesign) throws -> SkillPackage {
        let content = """
        ---
        name: \(design.name)
        description: \(design.description)
        triggers:
        \(design.triggerPatterns.map { "  - \($0)" }.joined(separator: "\n"))
        ---

        # \(design.name.replacingOccurrences(of: "_", with: " ").capitalized)

        ## When to Use
        This skill should be activated when the user needs help with \(design.name.replacingOccurrences(of: "_", with: " ")).

        ## Process
        1. Understand the user's specific need
        2. Analyze the context
        3. Provide appropriate assistance
        4. Verify the solution works

        ## Capabilities
        \(design.capabilities.map { "- \($0)" }.joined(separator: "\n"))

        ## Boundaries
        - Only assist with legitimate use cases
        - Ask for clarification when uncertain
        """

        return SkillPackage(
            manifest: SkillManifest(
                name: design.name,
                version: "1.0.0",
                description: design.description,
                author: "self-acquired",
                triggerPatterns: design.triggerPatterns,
                capabilities: design.capabilities,
                dependencies: design.dependencies
            ),
            content: content,
            testCases: design.testCases,
            metadata: SkillMetadata(
                acquisitionDate: Date(),
                acquisitionMethod: .selfDiscovered,
                gapThatPromptedAcquisition: design.description,
                researchSources: [],
                iterationCount: 1
            )
        )
    }

    private func testSkill(_ package: SkillPackage) async -> SkillTestResults {
        // Simple test validation - would be more sophisticated in practice
        var passed = 0
        var failed = 0

        for testCase in package.testCases {
            // Simulate testing
            let testPassed = !testCase.input.isEmpty && !testCase.expectedBehavior.isEmpty
            if testPassed {
                passed += 1
            } else {
                failed += 1
            }
        }

        let total = passed + failed
        let passRate = total > 0 ? Float(passed) / Float(total) : 0

        return SkillTestResults(
            passRate: passRate,
            passed: passed,
            failed: failed,
            errors: []
        )
    }
}

struct SkillTestResults {
    let passRate: Float
    let passed: Int
    let failed: Int
    let errors: [String]
}

enum SkillAcquisitionError: Error, LocalizedError {
    case testsFailed(passRate: Float)
    case researchFailed
    case buildFailed(String)
    case installFailed(String)

    var errorDescription: String? {
        switch self {
        case .testsFailed(let rate):
            return "Skill tests failed with pass rate: \(Int(rate * 100))%"
        case .researchFailed:
            return "Failed to research skill domain"
        case .buildFailed(let reason):
            return "Failed to build skill package: \(reason)"
        case .installFailed(let reason):
            return "Failed to install skill: \(reason)"
        }
    }
}

// MARK: - Skill Design

struct SkillDesign {
    let name: String
    let description: String
    let triggerPatterns: [String]
    let capabilities: [String]
    let dependencies: [String]
    let testCases: [SkillTestCase]
}

// MARK: - Skill Package Format

struct SkillPackage: Codable {
    let manifest: SkillManifest
    let content: String              // Markdown with prompts/instructions
    let testCases: [SkillTestCase]
    let metadata: SkillMetadata
}

struct SkillManifest: Codable {
    let name: String
    let version: String
    let description: String
    let author: String               // "self-acquired" or "partner-taught"
    let triggerPatterns: [String]    // Regex patterns that activate skill
    let capabilities: [String]
    let dependencies: [String]       // Required tools/other skills
}

struct SkillTestCase: Codable {
    let input: String
    let expectedBehavior: String
    let successCriteria: [String]
}

struct SkillMetadata: Codable {
    let acquisitionDate: Date
    let acquisitionMethod: AcquisitionMethod
    let gapThatPromptedAcquisition: String?
    let researchSources: [String]
    let iterationCount: Int          // How many attempts to get it right
}

// MARK: - Skill Package Manager

/// Manages installation and loading of skill packages
actor SkillPackageManager {
    private let skillsDirectory: URL
    private var installedSkills: [String: SkillPackage] = [:]

    init() {
        self.skillsDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".vaizor/agent/skills")

        try? FileManager.default.createDirectory(
            at: skillsDirectory,
            withIntermediateDirectories: true
        )
    }

    /// Install a skill package
    func install(_ package: SkillPackage) async throws -> AcquiredSkill {
        // Write to disk
        let skillDir = skillsDirectory.appendingPathComponent(package.manifest.name)
        try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)

        // Write manifest
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let manifestData = try encoder.encode(package.manifest)
        try manifestData.write(to: skillDir.appendingPathComponent("manifest.json"))

        // Write skill content
        try package.content.write(
            to: skillDir.appendingPathComponent("skill.md"),
            atomically: true,
            encoding: .utf8
        )

        // Write test cases
        let testData = try encoder.encode(package.testCases)
        try testData.write(to: skillDir.appendingPathComponent("tests.json"))

        // Write metadata
        let metaData = try encoder.encode(package.metadata)
        try metaData.write(to: skillDir.appendingPathComponent("metadata.json"))

        // Register in memory
        installedSkills[package.manifest.name] = package

        return AcquiredSkill(
            name: package.manifest.name,
            description: package.manifest.description,
            capabilities: package.manifest.capabilities,
            acquisitionMethod: package.metadata.acquisitionMethod,
            proficiency: 0.5,
            packagePath: skillDir.path
        )
    }

    /// Find a skill matching the input
    func findSkill(for input: String) async -> SkillPackage? {
        for (_, package) in installedSkills {
            for pattern in package.manifest.triggerPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(input.startIndex..., in: input)
                    if regex.firstMatch(in: input, range: range) != nil {
                        return package
                    }
                }
            }
        }
        return nil
    }

    /// Load all installed skills from disk
    func loadAllSkills() async throws {
        let contents = try FileManager.default.contentsOfDirectory(
            at: skillsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey]
        )

        for item in contents {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                if let package = try? await loadSkill(from: item) {
                    installedSkills[package.manifest.name] = package
                }
            }
        }
    }

    private func loadSkill(from directory: URL) async throws -> SkillPackage {
        let manifestURL = directory.appendingPathComponent("manifest.json")
        let contentURL = directory.appendingPathComponent("skill.md")
        let testsURL = directory.appendingPathComponent("tests.json")
        let metadataURL = directory.appendingPathComponent("metadata.json")

        let decoder = JSONDecoder()

        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try decoder.decode(SkillManifest.self, from: manifestData)

        let content = try String(contentsOf: contentURL, encoding: .utf8)

        var testCases: [SkillTestCase] = []
        if FileManager.default.fileExists(atPath: testsURL.path) {
            let testData = try Data(contentsOf: testsURL)
            testCases = try decoder.decode([SkillTestCase].self, from: testData)
        }

        var metadata = SkillMetadata(
            acquisitionDate: Date(),
            acquisitionMethod: .importedFromPackage,
            gapThatPromptedAcquisition: nil,
            researchSources: [],
            iterationCount: 1
        )
        if FileManager.default.fileExists(atPath: metadataURL.path) {
            let metaData = try Data(contentsOf: metadataURL)
            metadata = try decoder.decode(SkillMetadata.self, from: metaData)
        }

        return SkillPackage(
            manifest: manifest,
            content: content,
            testCases: testCases,
            metadata: metadata
        )
    }

    /// Get list of all installed skills
    func listInstalledSkills() -> [String] {
        Array(installedSkills.keys)
    }

    /// Uninstall a skill
    func uninstall(_ skillName: String) async throws {
        let skillDir = skillsDirectory.appendingPathComponent(skillName)
        try FileManager.default.removeItem(at: skillDir)
        installedSkills.removeValue(forKey: skillName)
    }
}

// MARK: - Skill Loader

/// Loads and matches skills for runtime use
actor SkillLoader {
    private let skillsDirectory: URL
    private var loadedSkills: [String: LoadedSkill] = [:]

    struct LoadedSkill {
        let manifest: SkillManifest
        let content: String
        let triggerRegexes: [NSRegularExpression]
    }

    init() {
        self.skillsDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".vaizor/agent/skills")
    }

    func loadAllSkills() async throws {
        guard FileManager.default.fileExists(atPath: skillsDirectory.path) else { return }

        let contents = try FileManager.default.contentsOfDirectory(
            at: skillsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey]
        )

        for item in contents {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                if let skill = try? await loadSkill(from: item) {
                    loadedSkills[skill.manifest.name] = skill
                }
            }
        }
    }

    private func loadSkill(from directory: URL) async throws -> LoadedSkill {
        let manifestURL = directory.appendingPathComponent("manifest.json")
        let contentURL = directory.appendingPathComponent("skill.md")

        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(SkillManifest.self, from: manifestData)

        let content = try String(contentsOf: contentURL, encoding: .utf8)

        let regexes = manifest.triggerPatterns.compactMap {
            try? NSRegularExpression(pattern: $0, options: .caseInsensitive)
        }

        return LoadedSkill(manifest: manifest, content: content, triggerRegexes: regexes)
    }

    func findMatchingSkill(for input: String) -> LoadedSkill? {
        let range = NSRange(input.startIndex..., in: input)

        for skill in loadedSkills.values {
            for regex in skill.triggerRegexes {
                if regex.firstMatch(in: input, range: range) != nil {
                    return skill
                }
            }
        }
        return nil
    }

    func getSkill(named name: String) -> LoadedSkill? {
        loadedSkills[name]
    }

    var skillCount: Int {
        loadedSkills.count
    }
}
