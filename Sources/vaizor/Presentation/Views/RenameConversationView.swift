import SwiftUI

struct RenameConversationView: View {
    let conversation: Conversation
    let onRename: (String) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var newTitle: String
    
    init(conversation: Conversation, onRename: @escaping (String) -> Void) {
        self.conversation = conversation
        self.onRename = onRename
        _newTitle = State(initialValue: conversation.title)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Rename Conversation")
                .font(.headline)
            
            TextField("Conversation Title", text: $newTitle)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    save()
                }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Save") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
    
    private func save() {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onRename(trimmed)
        dismiss()
    }
}
