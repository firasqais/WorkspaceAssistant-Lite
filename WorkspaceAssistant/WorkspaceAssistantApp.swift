import SwiftUI

@main
struct WorkspaceAssistantApp: App {
    @State private var workspace: Workspace
    @State private var agent: TaskAgent

    init() {
        let workspace = Workspace()
        _workspace = State(initialValue: workspace)
        _agent = State(initialValue: TaskAgent(workspace: workspace))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(workspace)
                .environment(agent)
        }
    }
}
