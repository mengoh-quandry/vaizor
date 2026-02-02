import SwiftUI
import WebKit

struct BrowserPanelView: View {
    @ObservedObject var automation: BrowserAutomation
    
    @State private var address: String = "https://www.apple.com"
    @State private var script: String = ""
    @State private var status: String = "Ready"

    var body: some View {
        VStack(spacing: 0) {
            // Navigation bar
            HStack(spacing: 8) {
                Button(action: { automation.goBack() }) {
                    Image(systemName: "chevron.left")
                }
                .disabled(!automation.webView.canGoBack)
                
                Button(action: { automation.goForward() }) {
                    Image(systemName: "chevron.right")
                }
                .disabled(!automation.webView.canGoForward)
                
                Button(action: { automation.reload() }) {
                    Image(systemName: "arrow.clockwise")
                }

                TextField("Enter URL", text: $address, onCommit: openAddress)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 300)

                ProgressView(value: automation.progress)
                    .frame(width: 80)

                Spacer()

                Button("Capture") {
                    Task { try? await captureSnapshot() }
                }
                .buttonStyle(.bordered)
            }
            .padding(8)
            .background(Material.thin)

            Divider()

            // Browser view
            BrowserView(automation: automation)
                .frame(minHeight: 400)

            Divider()

            // JavaScript console
            HStack(alignment: .top, spacing: 8) {
                TextEditor(text: $script)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 120)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))

                VStack(alignment: .leading, spacing: 8) {
                    Button("Run JS") {
                        Task { await runJS() }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Spacer()
                    
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 200)
            }
            .padding(8)
            .background(Material.ultraThin)
        }
        .onAppear {
            if let url = URL(string: address) {
                automation.load(url)
            }
        }
    }

    private func openAddress() {
        guard let url = URL(string: address) else { return }
        automation.load(url)
    }

    private func runJS() async {
        do {
            _ = try await automation.eval(script)
            status = "Executed successfully"
        } catch {
            status = "Error: \(error.localizedDescription)"
        }
    }

    private func captureSnapshot() async throws {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "snapshot.png"
        
        if panel.runModal() == .OK, let url = panel.url {
            let image = try await automation.takeSnapshot()
            guard let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else {
                throw NSError(domain: "BrowserPanel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode image"])
            }
            try png.write(to: url)
            status = "Saved snapshot to \(url.lastPathComponent)"
        }
    }
}
