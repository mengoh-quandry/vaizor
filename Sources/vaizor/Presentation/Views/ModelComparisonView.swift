import SwiftUI
import MarkdownUI

struct ModelComparisonView: View {
    let responses: [LLMProvider: String]
    let errors: [LLMProvider: Error]
    let isStreaming: Bool
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(Array(responses.keys.sorted(by: { $0.displayName < $1.displayName })), id: \.self) { provider in
                    ModelResponseCard(
                        provider: provider,
                        response: responses[provider] ?? "",
                        error: errors[provider],
                        isStreaming: isStreaming && responses[provider] != nil
                    )
                }
            }
            .padding()
        }
    }
}

struct ModelResponseCard: View {
    let provider: LLMProvider
    let response: String
    let error: Error?
    let isStreaming: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                // Provider icon/indicator
                ZStack {
                    Circle()
                        .fill(providerColor.opacity(0.15))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: providerIcon)
                        .foregroundStyle(providerColor)
                        .font(.system(size: 14, weight: .semibold))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.displayName)
                        .font(.system(size: 15, weight: .semibold))
                    
                    if isStreaming {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Streaming...")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                if error != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.system(size: 14))
                }
            }
            
            Divider()
            
            // Response content
            if let error = error {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Error")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Text(error.localizedDescription)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else if response.isEmpty && isStreaming {
                HStack {
                    ProgressView()
                    Text("Waiting for response...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                MarkdownUI.Markdown(response)
                    .markdownTextStyle(\.text) {
                        ForegroundColor(Color(nsColor: .textColor))
                        FontSize(14)
                    }
                    .markdownTextStyle(\.code) {
                        FontFamilyVariant(.monospaced)
                        FontSize(13)
                        ForegroundColor(.purple)
                        BackgroundColor(Color.purple.opacity(0.1))
                    }
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(providerColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var providerColor: Color {
        switch provider {
        case .ollama:
            return .blue
        case .anthropic:
            return .orange
        case .openai:
            return .green
        case .gemini:
            return .purple
        case .custom:
            return .gray
        }
    }
    
    private var providerIcon: String {
        switch provider {
        case .ollama:
            return "sparkles"
        case .anthropic:
            return "brain.head.profile"
        case .openai:
            return "bolt.fill"
        case .gemini:
            return "star.fill"
        case .custom:
            return "gearshape"
        }
    }
}

struct ParallelModeToggle: View {
    @EnvironmentObject private var container: DependencyContainer
    @Binding var isEnabled: Bool
    @Binding var selectedModels: Set<LLMProvider>
    let availableProviders: [LLMProvider]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Parallel Mode", isOn: $isEnabled)
                .font(.system(size: 14, weight: .semibold))
            
            if isEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select models to compare:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                        ForEach(availableProviders, id: \.self) { provider in
                            ModelSelectionButton(
                                provider: provider,
                                isSelected: selectedModels.contains(provider),
                                isAvailable: isProviderAvailable(provider)
                            ) {
                                if selectedModels.contains(provider) {
                                    selectedModels.remove(provider)
                                } else {
                                    selectedModels.insert(provider)
                                }
                            }
                        }
                    }
                }
                .padding(.leading, 20)
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
    }
    
    private func isProviderAvailable(_ provider: LLMProvider) -> Bool {
        // Ollama is always available, others need API keys
        guard provider != .ollama else { return true }
        let key = (container.apiKeys[provider] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !key.isEmpty
    }
}

struct ModelSelectionButton: View {
    let provider: LLMProvider
    let isSelected: Bool
    let isAvailable: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .font(.system(size: 12))
                
                Text(provider.shortDisplayName)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isAvailable ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? Color.blue.opacity(0.3) : Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
    }
}
