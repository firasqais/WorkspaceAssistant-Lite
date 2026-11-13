import Foundation
import FoundationModels

/// One task on the board.
struct TaskItem: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var category: TaskCategory
    var isHighPriority = false
    var isDone = false
    /// Goes up by one on every change, so the tile knows when to pulse.
    var revision = 0
}

/// The kind of work a task is.
///
/// `@Generable` lets this enum be used directly as a tool argument:
/// the model can only ever pick one of these four values.
@Generable
enum TaskCategory: String, CaseIterable {
    case development, testing, design, operations
}

/// How the board is drawn. Also `@Generable`, so the agent can change it.
@Generable
enum BoardLayout: String, CaseIterable {
    case grid, list, board
}

extension TaskItem {
    /// The board every demo starts from.
    static let samples: [TaskItem] = [
        TaskItem(title: "Refactor Network Layer", category: .development),
        TaskItem(title: "Write Unit Test Suite", category: .testing),
        TaskItem(title: "Redesign Onboarding Flow", category: .design),
        TaskItem(title: "Set Up CI/CD Pipeline", category: .operations),
        TaskItem(title: "Fix Memory Leak in Feed", category: .development),
        TaskItem(title: "Accessibility Audit", category: .testing),
    ]
}
