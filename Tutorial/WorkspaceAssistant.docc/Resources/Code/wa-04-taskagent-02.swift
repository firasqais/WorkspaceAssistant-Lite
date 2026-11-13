import Foundation
import FoundationModels
import Observation

/// The agent: one on-device `LanguageModelSession` that holds the conversation and the tools.
///
/// The agentic loop lives inside `session.respond(to:)`. For one prompt the model may call several
/// tools, read what each one returned, and only then write its reply. We just watch it happen.
@MainActor
@Observable
final class TaskAgent {
    struct Message: Identifiable {
        enum Role { case user, agent, problem }
        let id = UUID()
        let role: Role
        let text: String
        var actions: [AgentAction] = []
    }

    let workspace: Workspace
    private(set) var messages: [Message] = []
    private(set) var isWorking = false
    private var firstActionOfTurn = 0
    private var session: LanguageModelSession

    init(workspace: Workspace) {
        self.workspace = workspace
        session = Self.makeSession(for: workspace)
    }

    // MARK: - Session

    private static func makeSession(for workspace: Workspace) -> LanguageModelSession {
        let tools: [any Tool] = [
            AddTaskTool(workspace: workspace),
            CompleteTaskTool(workspace: workspace),
            PrioritizeTaskTool(workspace: workspace),
            SwitchLayoutTool(workspace: workspace),
        ]
        let titles = workspace.tasks.map(\.title).joined(separator: ", ")
        let instructions = """
        You are an agent inside a task-board app. You change the board ONLY by calling tools.
        - Call a tool for every change the user asks for. One request may need several tools.
        - To refer to a task, pass the user's own words for it.
        - Read every tool result. Only say something happened if a tool result says it did.
        - Reply in one short, friendly sentence.
        Tasks on the board when this conversation started: \(titles).
        """
        return LanguageModelSession(model: SystemLanguageModel.default, tools: tools, instructions: instructions)
    }

    /// Forgets the conversation. The board is not touched.
    func newConversation() {
        messages.removeAll()
        session = Self.makeSession(for: workspace)
    }

    /// Loads the model early so the first reply is faster.
    func prewarm() {
        if unavailableReason == nil { session.prewarm() }
    }

    // MARK: - Availability

    /// `nil` when Apple Intelligence is ready, otherwise what to tell the user.
    var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            nil
        case .unavailable(.deviceNotEligible):
            "This device doesn’t support Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            "Turn on Apple Intelligence in Settings to use the agent."
        case .unavailable(.modelNotReady):
            "Apple Intelligence is still downloading. Try again in a few minutes."
        case .unavailable:
            "Apple Intelligence isn’t available right now."
        }
    }
}
