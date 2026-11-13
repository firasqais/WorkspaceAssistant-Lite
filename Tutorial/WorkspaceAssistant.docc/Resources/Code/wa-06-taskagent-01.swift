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
            DeprioritizeTaskTool(workspace: workspace),
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

    // MARK: - Talking to the model

    /// What the tools have done so far in the current turn, shown live while the model works.
    var liveActions: [AgentAction] {
        isWorking ? Array(workspace.actions.dropFirst(firstActionOfTurn)) : []
    }

    func send(_ text: String) async {
        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isWorking else { return }
        messages.append(Message(role: .user, text: prompt))
        firstActionOfTurn = workspace.actions.count
        isWorking = true
        defer { isWorking = false }

        // No Apple Intelligence (e.g. a simulator on a Mac without it)? Use the keyword stand-in.
        if unavailableReason != nil {
            let reply = await SimulatedAgent.respond(to: prompt, workspace: workspace)
            messages.append(Message(role: .agent, text: reply, actions: liveActions))
            return
        }

        do {
            let response = try await session.respond(to: prompt)
            messages.append(Message(role: .agent, text: response.content, actions: liveActions))
        } catch let error as LanguageModelSession.GenerationError {
            var text = error.localizedDescription
            if case .exceededContextWindowSize = error {
                // The on-device model has a small context window. Start fresh and let the user retry.
                session = Self.makeSession(for: workspace)
                text = "This conversation got too long for the on-device model, so I started a fresh one. Please try again."
            }
            messages.append(Message(role: .problem, text: text, actions: liveActions))
        } catch {
            messages.append(Message(role: .problem, text: error.localizedDescription, actions: liveActions))
        }
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
