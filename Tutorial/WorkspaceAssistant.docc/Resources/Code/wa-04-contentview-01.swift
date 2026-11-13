import SwiftUI

/// The board, with the agent one tap away in a half-height sheet so you can watch it work.
struct ContentView: View {
    @Environment(Workspace.self) private var workspace
    @State private var showsAgent = false

    var body: some View {
        @Bindable var workspace = workspace
        NavigationStack {
            BoardView()
                .navigationTitle("My Tasks")
                .toolbar {
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
                    Button { showsAgent = true } label: {
                        Label("Ask the Agent", systemImage: "sparkles")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.glassProminent)
                    .padding(.horizontal)
                }
        }
        .sheet(isPresented: $showsAgent) {
            AgentPanel()
                .presentationDetents([.fraction(0.45), .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.45)))
        }
    }
}

#Preview {
    let workspace = Workspace()
    ContentView()
        .environment(workspace)
        .environment(TaskAgent(workspace: workspace))
}
