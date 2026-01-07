import SwiftUI

extension Notification.Name {
    static let showUnderConstructionToast = Notification.Name("showUnderConstructionToast")
}

/// A reusable component to show "under construction" feedback for unimplemented features
struct UnderConstructionView: View {
    let featureName: String
    @State private var showToast = false
    
    var body: some View {
        EmptyView()
            .onAppear {
                showToastMessage()
            }
    }
    
    private func showToastMessage() {
        // Show a brief toast notification
        // In a real implementation, this would use a toast system
        AppLogger.shared.log("Feature '\(featureName)' is under construction", level: .info)
        
        // Trigger a notification that can be displayed in UI
        NotificationCenter.default.post(
            name: .showUnderConstructionToast,
            object: featureName
        )
    }
}

/// Toast notification view for displaying temporary messages
struct ToastView: View {
    let message: String
    @Binding var isPresented: Bool
    
    var body: some View {
        if isPresented {
            HStack(spacing: 8) {
                Image(systemName: "hammer.fill")
                    .foregroundStyle(.orange)
                
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Button {
                    withAnimation {
                        isPresented = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color.orange.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                // Auto-dismiss after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        isPresented = false
                    }
                }
            }
        }
    }
}
