import SwiftUI

/// The board, with a menu to change the layout or start again.
struct ContentView: View {
    @Environment(Workspace.self) private var workspace

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
        }
    }
}

#Preview {
    ContentView()
        .environment(Workspace())
}
