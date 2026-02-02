import SwiftUI

/// View for ingesting and analyzing a local project folder
struct ProjectIngestionView: View {
    @EnvironmentObject var container: DependencyContainer
    @StateObject private var ingestionService = ProjectIngestionService()
    @Binding var isPresented: Bool

    @State private var analysis: ProjectIngestionService.ProjectAnalysis?
    @State private var error: Error?
    @State private var showError = false
    @State private var editedSystemPrompt: String = ""
    @State private var editedInstructions: [String] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if ingestionService.isAnalyzing {
                    analyzeProgressView
                } else if let analysis = analysis {
                    analysisResultView(analysis)
                } else {
                    selectProjectView
                }
            }
            .frame(minWidth: 600, minHeight: 500)
            .background(Color(nsColor: .windowBackgroundColor))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                if analysis != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create Project") {
                            createProject()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(error?.localizedDescription ?? "Unknown error")
        }
    }

    private var selectProjectView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Ingest Project")
                .font(.title)
                .fontWeight(.semibold)

            Text("Select a local project folder to analyze.\nThe AI will detect languages, frameworks, and generate a custom configuration.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 400)

            Button {
                Task {
                    await selectProject()
                }
            } label: {
                Label("Select Project Folder", systemImage: "folder")
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()

            // Info section
            VStack(alignment: .leading, spacing: 12) {
                Text("What gets analyzed:")
                    .font(.headline)

                HStack(spacing: 24) {
                    infoItem(icon: "doc.text", title: "Project Structure", desc: "Files & directories")
                    infoItem(icon: "chevron.left.forwardslash.chevron.right", title: "Languages", desc: "Swift, Python, JS...")
                    infoItem(icon: "shippingbox", title: "Frameworks", desc: "SwiftUI, React...")
                    infoItem(icon: "text.alignleft", title: "Config Files", desc: "README, package.json...")
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    private func infoItem(icon: String, title: String, desc: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            Text(desc)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var analyzeProgressView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)

            Text("Analyzing Project...")
                .font(.title2)
                .fontWeight(.semibold)

            Text(ingestionService.analysisStatus)
                .foregroundStyle(.secondary)

            ProgressView(value: ingestionService.analysisProgress)
                .frame(width: 300)

            Spacer()
        }
    }

    private func analysisResultView(_ analysis: ProjectIngestionService.ProjectAnalysis) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Image(systemName: iconForType(analysis.projectType))
                        .font(.title)
                        .foregroundStyle(Color(hex: colorForType(analysis.projectType)))
                        .frame(width: 48, height: 48)
                        .background(Color(hex: colorForType(analysis.projectType)).opacity(0.15))
                        .cornerRadius(10)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(analysis.projectName)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(analysis.projectType.rawValue)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("\(analysis.fileCount) files")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)

                // Detected info
                HStack(spacing: 16) {
                    detectedSection(title: "Languages", items: analysis.detectedLanguages, icon: "chevron.left.forwardslash.chevron.right")
                    detectedSection(title: "Frameworks", items: analysis.detectedFrameworks, icon: "shippingbox")
                }

                // Key files
                if !analysis.keyFiles.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Key Files Detected")
                            .font(.headline)

                        ForEach(analysis.keyFiles, id: \.path) { file in
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundStyle(.secondary)
                                Text(file.path)
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                Text(file.significance)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(6)
                        }
                    }
                }

                Divider()

                // System prompt (editable)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Generated System Prompt")
                            .font(.headline)
                        Spacer()
                        Button("Reset") {
                            editedSystemPrompt = analysis.suggestedSystemPrompt ?? ""
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }

                    TextEditor(text: $editedSystemPrompt)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 150)
                        .padding(8)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }

                // Instructions (editable)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Project Instructions")
                        .font(.headline)

                    ForEach(editedInstructions.indices, id: \.self) { index in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            TextField("Instruction", text: $editedInstructions[index])
                                .textFieldStyle(.plain)
                            Button {
                                editedInstructions.remove(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(8)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(6)
                    }

                    Button {
                        editedInstructions.append("")
                    } label: {
                        Label("Add Instruction", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding()
        }
        .onAppear {
            editedSystemPrompt = analysis.suggestedSystemPrompt ?? ""
            editedInstructions = analysis.suggestedInstructions
        }
    }

    private func detectedSection(title: String, items: [String], icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)

            if items.isEmpty {
                Text("None detected")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(items, id: \.self) { item in
                        Text(item)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundStyle(Color.accentColor)
                            .cornerRadius(12)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }

    private func selectProject() async {
        do {
            if let result = try await ingestionService.selectAndAnalyzeProject() {
                analysis = result
            }
        } catch {
            self.error = error
            showError = true
        }
    }

    private func createProject() {
        guard let analysis = analysis else { return }

        // Create modified analysis with edited values
        var modifiedAnalysis = analysis
        modifiedAnalysis.suggestedSystemPrompt = editedSystemPrompt
        modifiedAnalysis.suggestedInstructions = editedInstructions.filter { !$0.isEmpty }

        _ = ingestionService.createProjectFromAnalysis(modifiedAnalysis, projectManager: container.projectManager)

        isPresented = false
    }

    private func iconForType(_ type: ProjectIngestionService.ProjectAnalysis.ProjectType) -> String {
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

    private func colorForType(_ type: ProjectIngestionService.ProjectAnalysis.ProjectType) -> String {
        switch type {
        case .swiftPackage, .xcodeProject: return "F05138"
        case .nodeJS: return "339933"
        case .python: return "3776AB"
        case .rust: return "DEA584"
        case .go: return "00ADD8"
        case .web: return "E34F26"
        case .unknown: return "00976d"
        }
    }
}

// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

#Preview {
    ProjectIngestionView(isPresented: .constant(true))
        .frame(width: 700, height: 600)
}
