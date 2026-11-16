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
    private var session: LanguageModelSession //The core Apple FoundationModels object that remembers the ongoing chat and runs the "agentic loop" (deciding when to call tools, reading their results, and writing a final reply).

    init(workspace: Workspace) {
        self.workspace = workspace
        session = Self.makeSession(for: workspace)
    }

    // MARK: - Session
/* Creates a fresh LanguageModelSession by handing it three things:
    1. The Model: SystemLanguageModel.default (Apple's built-in on-device LLM).
    2. The Tools: The array of 4 tools (AddTaskTool, CompleteTaskTool, etc.)—this is where you'll add DeprioritizeTaskTool for the lab!
    3. The Instructions (System Prompt): Strict rules telling the AI how to behave (e.g., never lie about changing the board unless a tool actually confirmed it, keep replies to one short friendly sentence) plus a snapshot of the starting task titles. */
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
    /// Clears the chat bubbles and creates a fresh session so the AI forgets previous messages without deleting any tasks on your board.
    func newConversation() {
        messages.removeAll()
        session = Self.makeSession(for: workspace)
    }

    /// Loads the model early so the first reply is faster.
    /// Quietly wakes up the on-device model in the background (likely called when the app launches) so the user doesn't experience a delay on their first message.
    func prewarm() {
        if unavailableReason == nil { session.prewarm() }
    }

    // MARK: - Talking to the model

    /// What the tools have done so far in the current turn, shown live while the model works.
    /// Tracks actions added to workspace.actions since the current turn started (dropFirst(firstActionOfTurn)), letting your UI show live badges (like "Added 'Fix Bug'") while the AI is still thinking.
    var liveActions: [AgentAction] {
        isWorking ? Array(workspace.actions.dropFirst(firstActionOfTurn)) : []
    }

    /* send(_ text:):
    1. Guard & Setup: Trims whitespace, ignores empty messages or double-taps while isWorking is true, adds the user's message bubble, and uses defer { isWorking = false } to guarantee the loading spinner turns off when the function finishes.
    2. Simulator Fallback: If Apple Intelligence isn't available (unavailableReason != nil), it falls back to SimulatedAgent so you can still test the app on an older Mac or Xcode Simulator.
    3. Running the AI (try await session.respond(to: prompt)): Sends the prompt to the model. Behind the scenes, the model may call multiple tools in a row before returning response.content, which gets appended as an .agent message.
    4. Context Window Recovery: On-device models have a relatively small memory limit. If the chat gets too long (exceededContextWindowSize), it automatically resets session and asks the user to retry. */
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
///Inspects SystemLanguageModel.default.availability and translates Apple's status codes into friendly, human-readable messages explaining why Apple Intelligence isn't ready (unsupported hardware, turned off in Settings, or still downloading).
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

