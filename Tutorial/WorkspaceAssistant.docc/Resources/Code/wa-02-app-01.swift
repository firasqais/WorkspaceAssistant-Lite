import SwiftUI

@main
struct WorkspaceAssistantApp: App {
    @State private var workspace = Workspace()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(workspace)
        }
    }
}
