import FoundationModels

// The agent's four tools.
//
// A tool is a function the model may decide to call. You give it:
//   • a name and a description  → how the model knows WHEN to use it
//   • @Generable Arguments      → what the model must fill in (it can't invent other fields)
//   • call(arguments:)          → your Swift code, which returns what really happened
//
// Each tool here is a thin adapter over one Workspace command.

struct AddTaskTool: Tool {
    let name = "addTask"
    let description = "Adds a new task to the board."
    let workspace: Workspace

    @Generable //Because it uses @Generable, the model is guaranteed to return valid Swift types (like a TaskCategory or Bool) instead of messy, unpredictable text.
    struct Arguments {
        @Guide(description: "A short task title in Title Case, e.g. 'Review Pull Requests'") //@Guide(description: ...): Fine-grained hints attached to specific fields to steer the AI's formatting (e.g., forcing Title Case or clarifying when highPriority should be true).
        var title: String
        var category: TaskCategory
        @Guide(description: "True only if the user says the task is important, urgent or high priority")
        var highPriority: Bool
    }

    func call(arguments: Arguments) async throws -> String {
        await workspace.addTask(title: arguments.title, category: arguments.category, highPriority: arguments.highPriority, by: .agent)
    }
}

struct CompleteTaskTool: Tool {
    let name = "completeTask"
    let description = "Marks an existing task as done."
    let workspace: Workspace

    @Generable
    struct Arguments {
        @Guide(description: "The user's words for the task, e.g. 'unit tests'")
        var task: String
    }
//func call(arguments:): The actual Swift code that runs once the AI fills in the arguments. It passes those values into workspace, updates the UI (triggering those bounce and pulse animations from BoardView), and returns a String confirming what happened so the AI can reply naturally to the user.
    func call(arguments: Arguments) async throws -> String {
        await workspace.completeTask(arguments.task)
    }
}

struct PrioritizeTaskTool: Tool {
    let name = "prioritizeTask"
    let description = "Marks an existing task as high priority so it moves to the top."
    let workspace: Workspace

    @Generable
    struct Arguments {
        @Guide(description: "The user's words for the task, e.g. 'memory leak'")
        var task: String
    }

    func call(arguments: Arguments) async throws -> String {
        await workspace.prioritizeTask(arguments.task)
    }
}

struct SwitchLayoutTool: Tool {
    let name = "switchLayout"
    let description = "Changes how the board looks: grid of tiles, list of rows, or board with Priority / To Do / Done columns."
    let workspace: Workspace

    @Generable
    struct Arguments {
        var layout: BoardLayout
    }

    func call(arguments: Arguments) async throws -> String {
        await workspace.switchLayout(to: arguments.layout, by: .agent)
    }
}

// 🧪 LAB: add a DeprioritizeTaskTool here, then register it in TaskAgent.makeSession().
