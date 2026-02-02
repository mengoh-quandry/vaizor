import SwiftUI

struct FolderManagementView: View {
    @ObservedObject var conversationManager: ConversationManager
    @State private var showCreateFolder = false
    @State private var newFolderName = ""
    @State private var newFolderColor: String = "00976d"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Folders")
                    .font(.headline)
                Spacer()
                Button {
                    showCreateFolder = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color(hex: "00976d"))
                }
                .buttonStyle(.plain)
            }
            
            if conversationManager.folders.isEmpty {
                Text("No folders yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(conversationManager.folders) { folder in
                    FolderRow(
                        folder: folder,
                        conversationManager: conversationManager
                    )
                }
            }
        }
        .padding()
        .sheet(isPresented: $showCreateFolder) {
            CreateFolderView(
                isPresented: $showCreateFolder,
                conversationManager: conversationManager
            )
        }
    }
}

struct FolderRow: View {
    let folder: Folder
    @ObservedObject var conversationManager: ConversationManager
    @State private var showDeleteAlert = false
    
    var body: some View {
        HStack {
            if let color = folder.color {
                Circle()
                    .fill(Color(hex: color))
                    .frame(width: 12, height: 12)
            }
            Text(folder.name)
                .font(.subheadline)
            Spacer()
            Button {
                showDeleteAlert = true
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .alert("Delete Folder", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                conversationManager.deleteFolder(folder.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Conversations in this folder will be moved to 'Uncategorized'")
        }
    }
}

struct CreateFolderView: View {
    @Binding var isPresented: Bool
    @ObservedObject var conversationManager: ConversationManager
    @State private var folderName = ""
    @State private var selectedColor: String = "00976d"
    
    let colors = ["00976d", "007AFF", "FF3B30", "FF9500", "FFCC00", "34C759", "5856D6", "AF52DE"]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("New Folder")
                .font(.title2)
                .fontWeight(.semibold)
            
            TextField("Folder Name", text: $folderName)
                .textFieldStyle(.roundedBorder)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 12) {
                    ForEach(colors, id: \.self) { color in
                        Button {
                            selectedColor = color
                        } label: {
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary.opacity(selectedColor == color ? 0.5 : 0), lineWidth: 3)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Button("Create") {
                    conversationManager.createFolder(name: folderName, color: selectedColor)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
