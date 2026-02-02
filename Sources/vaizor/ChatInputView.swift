import SwiftUI
import UniformTypeIdentifiers

struct ChatInputView: View {
    @Binding var messageText: String
    @Binding var showSlashCommands: Bool
    @Binding var showWhiteboard: Bool
    @Binding var selectedModel: String
    @Binding var pendingAttachments: [PendingAttachment]

    let isStreaming: Bool
    let container: DependencyContainer
    let onSend: () -> Void
    let onStop: () -> Void

    @AppStorage("defaultOllamaModel") private var defaultOllamaModel: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var isDropTargeted: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Slash command suggestions
            if showSlashCommands {
                SlashCommandView(
                    searchText: String(messageText.dropFirst()),
                    onSelect: { command in
                        handleSlashCommand(command)
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            Divider()

            VStack(spacing: 12) {
                // Attachment preview strip
                if !pendingAttachments.isEmpty {
                    AttachmentStripView(attachments: pendingAttachments) { attachment in
                        pendingAttachments.removeAll { $0.id == attachment.id }
                    }
                }

                // Top row: Icons and model selector
                HStack(spacing: 12) {
                    // Left icons
                    leftIcons

                    Spacer()

                    // Model selector
                    modelSelector

                    // Right icons
                    rightIcons
                }

                // Bottom row: Text input and send button
                inputRow
            }
            .padding(16)
            .background(Material.thin)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(inputBorder)
            .overlay(dropHighlight)
            .shadow(color: inputShadowColor, radius: 8, x: 0, y: 3)
            .animation(.easeInOut(duration: 0.3), value: messageText.isEmpty)
            .animation(.easeInOut(duration: 0.3), value: isStreaming)
            .animation(.easeInOut(duration: 0.2), value: isDropTargeted)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .onDrop(of: SupportedDropType.allTypes, isTargeted: $isDropTargeted) { providers in
                handleDrop(providers: providers)
                return true
            }
        }
        .background(Material.ultraThin)
    }

    // MARK: - Drop Highlight Overlay

    @ViewBuilder
    private var dropHighlight: some View {
        if isDropTargeted {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.accentColor, lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.accentColor.opacity(0.1))
                )
        }
    }
    
    private var leftIcons: some View {
        HStack(spacing: 8) {
            Button {
                openFilePicker()
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(pendingAttachments.isEmpty ? .secondary : Color.accentColor)
            }
            .buttonStyle(.plain)
            .help("Attach file (drag & drop or Cmd+V to paste images)")

            Button {
                openImagePicker()
            } label: {
                Image(systemName: "photo")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Add image")

            Button {
                showWhiteboard.toggle()
            } label: {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.system(size: 20))
                    .foregroundStyle(showWhiteboard ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            .help("Open whiteboard")

            mcpServersIndicator
        }
    }
    
    private var mcpServersIndicator: some View {
        Menu {
            if container.mcpManager.availableServers.isEmpty {
                Text("No MCP servers configured")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(container.mcpManager.availableServers) { server in
                    HStack {
                        Circle()
                            .fill(container.mcpManager.enabledServers.contains(server.id) ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)

                        Text(server.name)

                        Spacer()

                        if container.mcpManager.enabledServers.contains(server.id) {
                            Text("Running")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "server.rack")
                    .font(.system(size: 16))
                    .foregroundStyle(container.mcpManager.enabledServers.isEmpty ? Color.secondary : Color.green)

                if !container.mcpManager.enabledServers.isEmpty {
                    Text("\(container.mcpManager.enabledServers.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .help("MCP Servers: \(container.mcpManager.enabledServers.count) active")
    }
    
    private var modelSelector: some View {
        Menu {
            ForEach(container.configuredProviders, id: \.self) { provider in
                Button {
                    container.currentProvider = provider
                    Task {
                        await container.loadModelsForCurrentProvider()

                        if provider == .ollama && !defaultOllamaModel.isEmpty {
                            selectedModel = defaultOllamaModel
                        } else if !container.availableModels.isEmpty {
                            selectedModel = container.availableModels[0]
                        }
                    }
                } label: {
                    HStack {
                        Text(provider.shortDisplayName)
                        if provider == container.currentProvider {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            Divider()

            if !container.availableModels.isEmpty {
                ForEach(container.availableModels, id: \.self) { model in
                    Button {
                        selectedModel = model
                    } label: {
                        HStack {
                            Text(model)
                            if model == selectedModel {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedModel.isEmpty ? container.currentProvider.shortDisplayName : selectedModel)
                    .font(.caption)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8))
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Select model")
        .onAppear {
            if container.currentProvider == .ollama && !defaultOllamaModel.isEmpty {
                selectedModel = defaultOllamaModel
            }
        }
    }
    
    private var rightIcons: some View {
        HStack(spacing: 8) {
            Button {
                // Voice input
            } label: {
                Image(systemName: "mic")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Voice input")
        }
    }
    
    private var inputRow: some View {
        HStack(spacing: 12) {
            PasteableTextField(
                text: $messageText,
                placeholder: "Ask anything or type / for commands",
                onPasteImage: { attachment in
                    pendingAttachments.append(attachment)
                }
            )
            .font(.system(size: 14))
            .focused($isInputFocused)
            .onChange(of: messageText) { _, newValue in
                showSlashCommands = newValue.hasPrefix("/") && newValue.count > 1
            }
            .onSubmit {
                onSend()
            }

            Button {
                if isStreaming {
                    onStop()
                } else {
                    onSend()
                }
            } label: {
                Image(systemName: isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(isStreaming ? .red : .accentColor)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming && pendingAttachments.isEmpty)
            .keyboardShortcut(.return, modifiers: [])
        }
    }
    
    private var inputBorder: some View {
        RoundedRectangle(cornerRadius: 14)
            .strokeBorder(
                LinearGradient(
                    colors: (!messageText.isEmpty || isStreaming) ?
                        [Color.blue.opacity(0.5), Color.purple.opacity(0.5)] :
                        [Color.gray.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: (!messageText.isEmpty || isStreaming) ? 1.5 : 0.75
            )
    }
    
    private var inputShadowColor: Color {
        (!messageText.isEmpty || isStreaming) ? Color.blue.opacity(0.15) : Color.clear
    }
    
    private func handleSlashCommand(_ command: SlashCommand) {
        showSlashCommands = false

        switch command.name {
        case "whiteboard":
            showWhiteboard = true
            messageText = ""
        case "clear":
            messageText = ""
        default:
            messageText = "/\(command.name) "
        }
    }

    // MARK: - File Pickers

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .png, .jpeg, .gif, .webP, .heic, .tiff, .bmp,
            .pdf, .plainText, .json, .xml, .html, .sourceCode
        ]
        panel.message = "Select files to attach"
        panel.prompt = "Attach"

        if panel.runModal() == .OK {
            for url in panel.urls {
                if let attachment = ClipboardHandler.loadFile(from: url) {
                    pendingAttachments.append(attachment)
                }
            }
        }
    }

    private func openImagePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.png, .jpeg, .gif, .webP, .heic, .tiff, .bmp]
        panel.message = "Select images to attach"
        panel.prompt = "Add Images"

        if panel.runModal() == .OK {
            for url in panel.urls {
                if let attachment = ClipboardHandler.loadFile(from: url) {
                    pendingAttachments.append(attachment)
                }
            }
        }
    }

    // MARK: - Drop Handling

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            // Try to load as file URL first
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        DispatchQueue.main.async {
                            if let attachment = ClipboardHandler.loadFile(from: url) {
                                self.pendingAttachments.append(attachment)
                            }
                        }
                    }
                }
                continue
            }

            // Try to load as image data
            for imageType in SupportedDropType.imageTypes {
                if provider.hasItemConformingToTypeIdentifier(imageType.identifier) {
                    provider.loadDataRepresentation(forTypeIdentifier: imageType.identifier) { data, error in
                        if let data = data {
                            let mimeType = SupportedDropType.mimeType(for: imageType)
                            let ext = imageType.preferredFilenameExtension ?? "png"
                            DispatchQueue.main.async {
                                let attachment = PendingAttachment(
                                    data: data,
                                    filename: "dropped-image.\(ext)",
                                    mimeType: mimeType
                                )
                                self.pendingAttachments.append(attachment)
                            }
                        }
                    }
                    break
                }
            }
        }
    }
}

// MARK: - Pasteable TextField

/// A text field that intercepts Cmd+V to handle image paste
struct PasteableTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onPasteImage: (PendingAttachment) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textColor = NSColor.textColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 0, height: 4)

        // Set placeholder
        textView.setValue(
            NSAttributedString(
                string: placeholder,
                attributes: [
                    .foregroundColor: NSColor.placeholderTextColor,
                    .font: NSFont.systemFont(ofSize: 14)
                ]
            ),
            forKey: "placeholderAttributedString"
        )

        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            // Restore selection if valid
            if selectedRange.location <= text.count {
                textView.setSelectedRange(selectedRange)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PasteableTextField

        init(_ parent: PasteableTextField) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Intercept paste command
            if commandSelector == #selector(NSText.paste(_:)) {
                // Check if clipboard has an image
                if ClipboardHandler.hasImage() {
                    if let attachment = ClipboardHandler.getImage() {
                        parent.onPasteImage(attachment)
                        return true // Handled
                    }
                }

                // Check if clipboard has files
                if ClipboardHandler.hasFiles() {
                    let files = ClipboardHandler.getFiles()
                    for file in files {
                        parent.onPasteImage(file)
                    }
                    if !files.isEmpty {
                        return true // Handled
                    }
                }

                // Let default paste handle text
                return false
            }

            // Handle Enter key for submit
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                // Check if Shift is held - if so, insert newline
                if NSEvent.modifierFlags.contains(.shift) {
                    return false // Let default handle it
                }
                // Otherwise submit
                NotificationCenter.default.post(name: .submitChatInput, object: nil)
                return true
            }

            return false
        }
    }
}

// Notification for submit
extension Notification.Name {
    static let submitChatInput = Notification.Name("submitChatInput")
}
