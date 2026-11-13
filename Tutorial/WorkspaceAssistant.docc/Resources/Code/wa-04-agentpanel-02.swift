import SwiftUI

/// The chat with the agent. Each reply shows the actions the agent took as chips,
/// and while the model is working the chips appear live, one per tool call.
struct AgentPanel: View {
    @Environment(TaskAgent.self) private var agent
    @State private var draft = ""
    @FocusState private var isTyping: Bool

    private let suggestions = [
        "Add a high-priority task to review pull requests",
        "Prioritise the memory leak and show my tasks as a board",
        "I finished the unit tests and the CI pipeline",
        "Add a design review task, then switch to list view",
    ]

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let reason = agent.unavailableReason {
                            Label(reason, systemImage: "exclamationmark.triangle.fill")
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.yellow.opacity(0.2), in: .rect(cornerRadius: 14))
                        }
                        if agent.messages.isEmpty {
                            suggestionList
                        }
                        ForEach(agent.messages) { MessageRow(message: $0) }
                        if agent.isWorking {
                            WorkingRow(actions: agent.liveActions)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding()
                }
                .onChange(of: agent.messages.count) { withAnimation { proxy.scrollTo("bottom") } }
                .onChange(of: agent.liveActions.count) { withAnimation { proxy.scrollTo("bottom") } }
            }
            .safeAreaInset(edge: .bottom) { composer }
            .navigationTitle("Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("New Chat", systemImage: "square.and.pencil") { agent.newConversation() }
                    .disabled(agent.messages.isEmpty || agent.isWorking)
            }
        }
        .task { agent.prewarm() }
    }

    private var suggestionList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try asking…")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(suggestions, id: \.self) { suggestion in
                Button { submit(suggestion) } label: {
                    Label(suggestion, systemImage: "sparkles")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.quaternary, in: .rect(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var composer: some View {
        HStack(spacing: 8) {
            TextField("Ask the agent to do something…", text: $draft)
                .focused($isTyping)
                .submitLabel(.send)
                .onSubmit { submit(draft) }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect()
            Button { submit(draft) } label: {
                Image(systemName: "arrow.up")
                    .font(.headline)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .disabled(draft.isEmpty || agent.isWorking)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func submit(_ text: String) {
        draft = ""
        isTyping = false   // drop the keyboard so the board is visible while the agent works
        Task { await agent.send(text) }
    }
}

private struct MessageRow: View {
    let message: TaskAgent.Message

    var body: some View {
        switch message.role {
        case .user:
            Text(message.text)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.tint, in: .rect(cornerRadius: 18))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.leading, 48)
        case .agent, .problem:
            VStack(alignment: .leading, spacing: 8) {
                ForEach(message.actions) { ActionChip(action: $0) }
                Label(message.text, systemImage: message.role == .agent ? "sparkles" : "exclamationmark.triangle")
                    .foregroundStyle(message.role == .agent ? Color.primary : Color.secondary)
            }
        }
    }
}

private struct WorkingRow: View {
    let actions: [AgentAction]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(actions) { ActionChip(action: $0) }
            HStack(spacing: 8) {
                ProgressView()
                Text("Working on it…").foregroundStyle(.secondary)
            }
        }
        .animation(.spring, value: actions)
    }
}

private struct ActionChip: View {
    let action: AgentAction

    var body: some View {
        Label(action.summary, systemImage: action.symbol)
            .font(.footnote.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.quaternary, in: .capsule)
            .transition(.move(edge: .leading).combined(with: .opacity))
    }
}
