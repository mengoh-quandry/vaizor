import SwiftUI

struct ConversationModelSelector: View {
    let conversation: Conversation
    let conversationManager: ConversationManager
    let container: DependencyContainer

    private var effectiveProvider: LLMProvider {
        conversation.selectedProvider ?? container.currentProvider
    }

    private var effectiveModel: String {
        conversation.selectedModel ?? ""
    }

    private var availableModels: [String] {
        if effectiveProvider == container.currentProvider, !container.availableModels.isEmpty {
            return container.availableModels
        }
        return effectiveProvider.defaultModels
    }

    var body: some View {
        Menu {
            Button("Use Global Default") {
                conversationManager.updateModelSettings(conversation.id, provider: nil, model: nil)
            }

            Divider()

            if availableModels.isEmpty {
                Text("No models available")
            } else {
                ForEach(availableModels, id: \.self) { model in
                    Button {
                        conversationManager.updateModelSettings(conversation.id, provider: effectiveProvider, model: model)
                    } label: {
                        HStack {
                            Text(model)
                            if model == effectiveModel {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(effectiveModel.isEmpty ? effectiveProvider.shortDisplayName : effectiveModel)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 150)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8))
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Select model")
        .frame(maxWidth: 170)
    }
}
