import Foundation
import Observation

/// Something the agent did, shown as a chip in the chat.
struct AgentAction: Identifiable, Hashable {
    let id = UUID()
    let symbol: String
    let summary: String
}

/// Who made a change: a tap in the UI, or a tool call by the agent.
enum ChangedBy {
    case user, agent
}

/// The app's state, and the only place it changes.
///
/// Every change is a "command" method. Taps in the UI and the agent's tools call the SAME methods,
/// only `by:` differs, so the AI can never do anything the user couldn't do. Each command returns
/// a short, truthful sentence: that sentence is what the model reads back after calling a tool.
@MainActor
@Observable
final class Workspace {
    var tasks: [TaskItem] = TaskItem.samples
    var layout: BoardLayout = .grid
    /// Everything the agent has done, in order.
    private(set) var actions: [AgentAction] = []

    /// Priority first, then to-do, then done.
    var orderedTasks: [TaskItem] {
        let open = tasks.filter { !$0.isDone }
        return open.filter(\.isHighPriority) + open.filter { !$0.isHighPriority } + tasks.filter(\.isDone)
    }
}
