import SwiftUI

struct TemplateManagementView: View {
    @ObservedObject var conversationManager: ConversationManager
    @State private var showCreateTemplate = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Templates")
                    .font(.headline)
                Spacer()
                Button {
                    showCreateTemplate = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color(hex: "00976d"))
                }
                .buttonStyle(.plain)
            }
            
            if conversationManager.templates.isEmpty {
                Text("No templates yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(conversationManager.templates) { template in
                    TemplateRow(
                        template: template,
                        conversationManager: conversationManager
                    )
                }
            }
        }
        .padding()
        .sheet(isPresented: $showCreateTemplate) {
            CreateTemplateView(
                isPresented: $showCreateTemplate,
                conversationManager: conversationManager
            )
        }
    }
}

struct TemplateRow: View {
    let template: ConversationTemplate
    @ObservedObject var conversationManager: ConversationManager
    @State private var showDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(template.name)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(template.prompt.prefix(50) + (template.prompt.count > 50 ? "..." : ""))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .contextMenu {
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .alert("Delete Template", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                conversationManager.deleteTemplate(template.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this template?")
        }
    }
}

struct CreateTemplateView: View {
    @Binding var isPresented: Bool
    @ObservedObject var conversationManager: ConversationManager
    @State private var templateName = ""
    @State private var templatePrompt = ""
    @State private var systemPrompt = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("New Template")
                .font(.title2)
                .fontWeight(.semibold)
            
            TextField("Template Name", text: $templateName)
                .textFieldStyle(.roundedBorder)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Prompt")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextEditor(text: $templatePrompt)
                    .frame(height: 100)
                    .border(Color.secondary.opacity(0.2))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("System Prompt (Optional)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextEditor(text: $systemPrompt)
                    .frame(height: 60)
                    .border(Color.secondary.opacity(0.2))
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Button("Create") {
                    conversationManager.createTemplate(
                        name: templateName,
                        prompt: templatePrompt,
                        systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt
                    )
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                         templatePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 500, height: 400)
    }
}
