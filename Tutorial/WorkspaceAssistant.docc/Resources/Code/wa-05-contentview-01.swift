import SwiftUI

/// The board, with the agent one tap away in a half-height sheet so you can watch it work.
struct ContentView: View {
    /// One sheet at a time: opening one closes the other.
    enum Sheet: String, Identifiable {
        case agent, newTask
        var id: String { rawValue }
    }

    @Environment(Workspace.self) private var workspace
    @State private var sheet: Sheet?

    var body: some View {
        @Bindable var workspace = workspace
        NavigationStack {
            BoardView()
                .navigationTitle("My Tasks")
                .toolbar {
                    Button("New Task", systemImage: "plus") { sheet = .newTask }
                    Menu {
                        Picker("Layout", selection: $workspace.layout) {
                            ForEach(BoardLayout.allCases, id: \.self) { layout in
                                Label(layout.rawValue.capitalized, systemImage: layout.symbol).tag(layout)
                            }
                        }
                        Button("Reset Board", systemImage: "arrow.counterclockwise") { workspace.reset() }
                    } label: {
                        Image(systemName: workspace.layout.symbol)
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    Button { sheet = .agent } label: {
                        Label("Ask the Agent", systemImage: "sparkles")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.glassProminent)
                    .padding(.horizontal)
                }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .agent:
                AgentPanel()
                    .presentationDetents([.fraction(0.45), .large])
                    .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.45)))
            case .newTask:
                NewTaskSheet()
            }
        }
    }
}

#Preview {
    let workspace = Workspace()
    ContentView()
        .environment(workspace)
        .environment(TaskAgent(workspace: workspace))
}
