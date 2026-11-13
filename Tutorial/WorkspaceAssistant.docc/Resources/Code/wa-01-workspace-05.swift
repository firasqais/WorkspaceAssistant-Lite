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

    // MARK: - Commands (shared by taps and tools)

    @discardableResult
    func addTask(title: String, category: TaskCategory, highPriority: Bool, by: ChangedBy) -> String {
        tasks.append(TaskItem(title: title, category: category, isHighPriority: highPriority))
        let detail = highPriority ? " (high priority)" : ""
        return record("plus.circle.fill", "Added “\(title)”\(detail)", by: by)
    }

    @discardableResult
    func complete(_ id: TaskItem.ID, by: ChangedBy) -> String {
        guard let index = index(of: id) else { return "That task no longer exists." }
        guard !tasks[index].isDone else { return "“\(tasks[index].title)” was already done. Nothing changed." }
        tasks[index].isDone = true
        tasks[index].revision += 1
        return record("checkmark.circle.fill", "Completed “\(tasks[index].title)”", by: by)
    }

    @discardableResult
    func prioritize(_ id: TaskItem.ID, by: ChangedBy) -> String {
        guard let index = index(of: id) else { return "That task no longer exists." }
        guard !tasks[index].isHighPriority else { return "“\(tasks[index].title)” is already high priority. Nothing changed." }
        tasks[index].isHighPriority = true
        tasks[index].revision += 1
        return record("star.fill", "Prioritised “\(tasks[index].title)”", by: by)
    }

    @discardableResult
    func delete(_ id: TaskItem.ID, by: ChangedBy) -> String {
        guard let index = index(of: id) else { return "That task no longer exists." }
        let title = tasks.remove(at: index).title
        return record("trash.fill", "Deleted “\(title)”", by: by)
    }

    @discardableResult
    func switchLayout(to newLayout: BoardLayout, by: ChangedBy) -> String {
        guard layout != newLayout else { return "The board is already in \(newLayout.rawValue) view. Nothing changed." }
        layout = newLayout
        return record("rectangle.3.group.fill", "Switched to \(newLayout.rawValue) view", by: by)
    }

    /// A tap on a tile: done ↔ open.
    func toggleDone(_ id: TaskItem.ID) {
        guard let index = index(of: id) else { return }
        tasks[index].isDone.toggle()
        tasks[index].revision += 1
    }

    /// Puts the demo back to the start.
    func reset() {
        tasks = TaskItem.samples
        layout = .grid
        actions = []
    }

    // MARK: - Helpers

    /// Returns the summary as a sentence for the model. Agent changes are also logged as chat chips.
    func record(_ symbol: String, _ summary: String, by: ChangedBy) -> String {
        if by == .agent {
            actions.append(AgentAction(symbol: symbol, summary: summary))
        }
        return summary + "."
    }

    func index(of id: TaskItem.ID) -> Int? {
        tasks.firstIndex { $0.id == id }
    }

    /// Finds the one task the user means, e.g. "unit tests" → "Write Unit Test Suite".
    /// Returns nil when nothing matches or more than one task does.
    func findTask(_ query: String) -> TaskItem.ID? {
        let wanted = Self.words(in: query).filter { !["the", "a", "my", "task"].contains($0) }
        guard !wanted.isEmpty else { return nil }
        let matches = tasks.filter { task in
            let titleWords = Self.words(in: task.title)
            return wanted.allSatisfy { word in
                titleWords.contains { $0.hasPrefix(word) || (word.hasPrefix($0) && $0.count >= 4) }
            }
        }
        let open = matches.filter { !$0.isDone }
        let candidates = open.isEmpty ? matches : open
        return candidates.count == 1 ? candidates[0].id : nil
    }

    /// Tells the model honestly why nothing happened, so it can ask the user instead of pretending.
    func problem(_ query: String) -> String {
        actions.append(AgentAction(symbol: "questionmark.circle.fill", summary: "Couldn’t pick a task for “\(query)”"))
        let titles = tasks.filter { !$0.isDone }.map { "“\($0.title)”" }.joined(separator: ", ")
        return "No single task matches “\(query)”, so nothing changed. Open tasks: \(titles). Ask the user which one they mean."
    }

    private static func words(in text: String) -> [String] {
        text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }
}
