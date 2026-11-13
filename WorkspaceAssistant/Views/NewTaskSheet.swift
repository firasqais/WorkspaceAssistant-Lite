import SwiftUI

/// The user's way to add a task. It calls the same `addTask` command as the agent's tool.
struct NewTaskSheet: View {
    @Environment(Workspace.self) private var workspace
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var category: TaskCategory = .development
    @State private var highPriority = false

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                Picker("Category", selection: $category) {
                    ForEach(TaskCategory.allCases, id: \.self) { option in
                        Label(option.rawValue.capitalized, systemImage: option.symbol).tag(option)
                    }
                }
                Toggle("High priority", isOn: $highPriority)
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        workspace.addTask(title: trimmedTitle, category: category, highPriority: highPriority, by: .user)
                        dismiss()
                    }
                    .disabled(trimmedTitle.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
