import Foundation
import AppKit

/// Service for ingesting local project folders and generating AI-powered configurations
@MainActor
class ProjectIngestionService: ObservableObject {
    @Published var isAnalyzing = false
    @Published var analysisProgress: Double = 0
    @Published var analysisStatus: String = ""

    struct ProjectAnalysis: Codable {
        var projectPath: String
        var projectName: String
        var detectedLanguages: [String]
        var detectedFrameworks: [String]
        var projectType: ProjectType
        var fileCount: Int
        var directoryStructure: [String]
        var keyFiles: [KeyFile]
        var suggestedSystemPrompt: String?
        var suggestedInstructions: [String]

        struct KeyFile: Codable {
            var path: String
            var type: String
            var significance: String
        }

        enum ProjectType: String, Codable {
            case swiftPackage = "Swift Package"
            case xcodeProject = "Xcode Project"
            case nodeJS = "Node.js"
            case python = "Python"
            case rust = "Rust"
            case go = "Go"
            case web = "Web (HTML/CSS/JS)"
            case unknown = "Unknown"
        }
    }

    /// Scan a project directory and return analysis
    func analyzeProject(at path: URL) async throws -> ProjectAnalysis {
        isAnalyzing = true
        analysisProgress = 0
        analysisStatus = "Scanning directory..."

        defer {
            isAnalyzing = false
            analysisProgress = 1.0
        }

        let fm = FileManager.default
        guard fm.fileExists(atPath: path.path) else {
            throw IngestionError.pathNotFound
        }

        // Gather basic info
        let projectName = path.lastPathComponent
        var detectedLanguages: Set<String> = []
        var detectedFrameworks: Set<String> = []
        var projectType: ProjectAnalysis.ProjectType = .unknown
        var fileCount = 0
        var directoryStructure: [String] = []
        var keyFiles: [ProjectAnalysis.KeyFile] = []

        analysisProgress = 0.1
        analysisStatus = "Detecting project type..."

        // Detect project type by looking for key files
        let contents = try fm.contentsOfDirectory(at: path, includingPropertiesForKeys: nil)
        let fileNames = contents.map { $0.lastPathComponent }

        if fileNames.contains("Package.swift") {
            projectType = .swiftPackage
            detectedLanguages.insert("Swift")
            keyFiles.append(.init(path: "Package.swift", type: "manifest", significance: "Swift Package Manager manifest"))
        } else if fileNames.contains(where: { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }) {
            projectType = .xcodeProject
            detectedLanguages.insert("Swift")
        } else if fileNames.contains("package.json") {
            projectType = .nodeJS
            detectedLanguages.insert("JavaScript")
            keyFiles.append(.init(path: "package.json", type: "manifest", significance: "Node.js package manifest"))
            if fileNames.contains("tsconfig.json") {
                detectedLanguages.insert("TypeScript")
            }
        } else if fileNames.contains("requirements.txt") || fileNames.contains("setup.py") || fileNames.contains("pyproject.toml") {
            projectType = .python
            detectedLanguages.insert("Python")
        } else if fileNames.contains("Cargo.toml") {
            projectType = .rust
            detectedLanguages.insert("Rust")
            keyFiles.append(.init(path: "Cargo.toml", type: "manifest", significance: "Rust/Cargo manifest"))
        } else if fileNames.contains("go.mod") {
            projectType = .go
            detectedLanguages.insert("Go")
            keyFiles.append(.init(path: "go.mod", type: "manifest", significance: "Go module manifest"))
        } else if fileNames.contains("index.html") {
            projectType = .web
            detectedLanguages.insert("HTML")
        }

        // Check for common config files
        if fileNames.contains("CLAUDE.md") {
            keyFiles.append(.init(path: "CLAUDE.md", type: "ai-config", significance: "Claude AI configuration"))
        }
        if fileNames.contains("README.md") {
            keyFiles.append(.init(path: "README.md", type: "documentation", significance: "Project documentation"))
        }
        if fileNames.contains(".env") || fileNames.contains(".env.example") {
            keyFiles.append(.init(path: ".env", type: "config", significance: "Environment configuration"))
        }

        analysisProgress = 0.3
        analysisStatus = "Scanning files..."

        // Scan directory structure (limited depth)
        try scanDirectory(at: path, relativeTo: path, depth: 0, maxDepth: 3,
                         fileCount: &fileCount,
                         languages: &detectedLanguages,
                         frameworks: &detectedFrameworks,
                         structure: &directoryStructure)

        analysisProgress = 0.7
        analysisStatus = "Generating configuration..."

        // Detect frameworks based on files found
        if detectedLanguages.contains("Swift") {
            if directoryStructure.contains(where: { $0.contains("SwiftUI") }) {
                detectedFrameworks.insert("SwiftUI")
            }
            if directoryStructure.contains(where: { $0.contains("UIKit") }) {
                detectedFrameworks.insert("UIKit")
            }
        }
        if detectedLanguages.contains("JavaScript") || detectedLanguages.contains("TypeScript") {
            if fileNames.contains("next.config.js") || fileNames.contains("next.config.mjs") {
                detectedFrameworks.insert("Next.js")
            }
            if directoryStructure.contains(where: { $0.contains("react") }) {
                detectedFrameworks.insert("React")
            }
            if directoryStructure.contains(where: { $0.contains("vue") }) {
                detectedFrameworks.insert("Vue.js")
            }
        }

        analysisProgress = 0.9

        // Generate suggested system prompt
        let suggestedPrompt = generateSystemPrompt(
            projectName: projectName,
            projectType: projectType,
            languages: Array(detectedLanguages),
            frameworks: Array(detectedFrameworks)
        )

        // Generate suggested instructions
        let suggestedInstructions = generateInstructions(
            projectType: projectType,
            languages: Array(detectedLanguages),
            frameworks: Array(detectedFrameworks)
        )

        analysisStatus = "Complete"

        return ProjectAnalysis(
            projectPath: path.path,
            projectName: projectName,
            detectedLanguages: Array(detectedLanguages).sorted(),
            detectedFrameworks: Array(detectedFrameworks).sorted(),
            projectType: projectType,
            fileCount: fileCount,
            directoryStructure: directoryStructure,
            keyFiles: keyFiles,
            suggestedSystemPrompt: suggestedPrompt,
            suggestedInstructions: suggestedInstructions
        )
    }

    private func scanDirectory(
        at url: URL,
        relativeTo base: URL,
        depth: Int,
        maxDepth: Int,
        fileCount: inout Int,
        languages: inout Set<String>,
        frameworks: inout Set<String>,
        structure: inout [String]
    ) throws {
        guard depth < maxDepth else { return }

        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey])

        for item in contents {
            let name = item.lastPathComponent

            // Skip hidden files and common ignore patterns
            if name.hasPrefix(".") || name == "node_modules" || name == ".build" ||
               name == "Pods" || name == "DerivedData" || name == "__pycache__" ||
               name == "target" || name == "vendor" {
                continue
            }

            let relativePath = item.path.replacingOccurrences(of: base.path + "/", with: "")

            var isDirectory: ObjCBool = false
            if fm.fileExists(atPath: item.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    structure.append("📁 " + relativePath)
                    try scanDirectory(at: item, relativeTo: base, depth: depth + 1, maxDepth: maxDepth,
                                    fileCount: &fileCount, languages: &languages,
                                    frameworks: &frameworks, structure: &structure)
                } else {
                    fileCount += 1
                    detectLanguage(from: name, into: &languages)
                }
            }
        }
    }

    private func detectLanguage(from filename: String, into languages: inout Set<String>) {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": languages.insert("Swift")
        case "m", "mm", "h": languages.insert("Objective-C")
        case "py": languages.insert("Python")
        case "js", "mjs", "cjs": languages.insert("JavaScript")
        case "ts", "tsx": languages.insert("TypeScript")
        case "jsx": languages.insert("React/JSX")
        case "go": languages.insert("Go")
        case "rs": languages.insert("Rust")
        case "rb": languages.insert("Ruby")
        case "java": languages.insert("Java")
        case "kt", "kts": languages.insert("Kotlin")
        case "cpp", "cc", "cxx", "c": languages.insert("C/C++")
        case "cs": languages.insert("C#")
        case "php": languages.insert("PHP")
        case "html", "htm": languages.insert("HTML")
        case "css", "scss", "sass", "less": languages.insert("CSS")
        case "sql": languages.insert("SQL")
        case "sh", "bash", "zsh": languages.insert("Shell")
        default: break
        }
    }

    private func generateSystemPrompt(
        projectName: String,
        projectType: ProjectAnalysis.ProjectType,
        languages: [String],
        frameworks: [String]
    ) -> String {
        var prompt = "You are an expert software developer working on \(projectName), "

        switch projectType {
        case .swiftPackage, .xcodeProject:
            prompt += "a \(projectType.rawValue) project. "
        case .nodeJS:
            prompt += "a Node.js application. "
        case .python:
            prompt += "a Python project. "
        case .rust:
            prompt += "a Rust project built with Cargo. "
        case .go:
            prompt += "a Go project. "
        case .web:
            prompt += "a web application. "
        case .unknown:
            prompt += "a software project. "
        }

        if !languages.isEmpty {
            prompt += "The project uses \(languages.joined(separator: ", ")). "
        }

        if !frameworks.isEmpty {
            prompt += "Key frameworks include \(frameworks.joined(separator: ", ")). "
        }

        prompt += "\n\nWhen helping with this project:\n"
        prompt += "- Follow the existing code style and patterns\n"
        prompt += "- Consider the project's architecture and conventions\n"
        prompt += "- Provide idiomatic solutions for the languages used\n"
        prompt += "- Be mindful of dependencies and compatibility"

        return prompt
    }

    private func generateInstructions(
        projectType: ProjectAnalysis.ProjectType,
        languages: [String],
        frameworks: [String]
    ) -> [String] {
        var instructions: [String] = []

        switch projectType {
        case .swiftPackage:
            instructions.append("Use Swift Package Manager for dependencies")
            instructions.append("Follow Swift API Design Guidelines")
        case .xcodeProject:
            instructions.append("Consider iOS/macOS platform requirements")
            instructions.append("Use proper access control and encapsulation")
        case .nodeJS:
            instructions.append("Use npm/yarn for package management")
            instructions.append("Follow Node.js best practices for async code")
        case .python:
            instructions.append("Follow PEP 8 style guidelines")
            instructions.append("Use virtual environments for dependencies")
        case .rust:
            instructions.append("Follow Rust idioms and ownership patterns")
            instructions.append("Use proper error handling with Result types")
        case .go:
            instructions.append("Follow Go conventions and gofmt")
            instructions.append("Handle errors explicitly")
        case .web:
            instructions.append("Consider browser compatibility")
            instructions.append("Follow accessibility best practices")
        case .unknown:
            instructions.append("Analyze the codebase to understand conventions")
        }

        if frameworks.contains("SwiftUI") {
            instructions.append("Use declarative SwiftUI patterns")
        }
        if frameworks.contains("React") || frameworks.contains("Next.js") {
            instructions.append("Use React hooks and functional components")
        }

        return instructions
    }

    /// Show folder picker and analyze selected project
    func selectAndAnalyzeProject() async throws -> ProjectAnalysis? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a project folder to analyze"
        panel.prompt = "Analyze Project"

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        return try await analyzeProject(at: url)
    }

    /// Create a Project from analysis results
    func createProjectFromAnalysis(_ analysis: ProjectAnalysis, projectManager: ProjectManager) -> Project {
        let project = projectManager.createProject(
            name: analysis.projectName,
            iconName: iconForProjectType(analysis.projectType),
            color: colorForProjectType(analysis.projectType)
        )

        // Update with context
        var context = ProjectContext()
        context.systemPrompt = analysis.suggestedSystemPrompt
        context.instructions = analysis.suggestedInstructions

        // Add project path as a file reference
        context.files = [
            ProjectFile(
                name: analysis.projectName,
                path: analysis.projectPath,
                type: .data,
                sizeBytes: nil
            )
        ]

        var updatedProject = project
        updatedProject.context = context
        projectManager.updateProject(updatedProject)

        return updatedProject
    }

    private func iconForProjectType(_ type: ProjectAnalysis.ProjectType) -> String {
        switch type {
        case .swiftPackage, .xcodeProject: return "swift"
        case .nodeJS: return "shippingbox"
        case .python: return "chevron.left.forwardslash.chevron.right"
        case .rust: return "gearshape.2"
        case .go: return "arrow.right.circle"
        case .web: return "globe"
        case .unknown: return "folder.fill"
        }
    }

    private func colorForProjectType(_ type: ProjectAnalysis.ProjectType) -> String {
        switch type {
        case .swiftPackage, .xcodeProject: return "F05138"  // Swift orange
        case .nodeJS: return "339933"  // Node green
        case .python: return "3776AB"  // Python blue
        case .rust: return "DEA584"  // Rust orange
        case .go: return "00ADD8"  // Go blue
        case .web: return "E34F26"  // HTML orange
        case .unknown: return "00976d"  // Default green
        }
    }

    enum IngestionError: LocalizedError {
        case pathNotFound
        case analysisFailedversionChange
        case llmError(String)

        var errorDescription: String? {
            switch self {
            case .pathNotFound: return "Project path not found"
            case .analysisFailedversionChange: return "Analysis failed"
            case .llmError(let msg): return "LLM error: \(msg)"
            }
        }
    }
}
