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
