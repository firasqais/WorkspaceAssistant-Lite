import SwiftUI

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
