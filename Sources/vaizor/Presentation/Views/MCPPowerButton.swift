import SwiftUI

struct MCPPowerButton: View {
    let isEnabled: Bool
    let onToggle: (Bool) -> Void
    @State private var isProcessing = false

    var body: some View {
        Button {
            guard !isProcessing else { return }
            isProcessing = true
            onToggle(!isEnabled)
            // Reset processing state after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isProcessing = false
            }
        } label: {
            ZStack {
                Circle()
                    .fill(isEnabled ? Color(hex: "00976d").opacity(0.15) : Color.gray.opacity(0.1))
                    .frame(width: 32, height: 32)

                Image(systemName: "power")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isEnabled ? Color(hex: "00976d") : Color.gray)
                    .opacity(isProcessing ? 0.5 : 1.0)
            }
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
        .help(isEnabled ? "Disable MCP Server" : "Enable MCP Server")
    }
}

struct MCPServerToggleRow: View {
    let server: MCPServer
    let isEnabled: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(isEnabled ? Color(hex: "00976d") : Color.gray)
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(server.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !server.description.isEmpty {
                    Text(server.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            MCPPowerButton(isEnabled: isEnabled, onToggle: onToggle)
                .padding(.top, 2)
        }
    }
}
