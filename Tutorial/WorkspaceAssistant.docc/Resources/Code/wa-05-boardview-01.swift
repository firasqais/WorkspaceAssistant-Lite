import SwiftUI

/// Draws the board in the current layout. Because it only reads `Workspace`,
/// any change the agent makes animates in here automatically.
struct BoardView: View {
    @Environment(Workspace.self) private var workspace
    @Namespace private var tiles

    var body: some View {
        ScrollView {
            Group {
                switch workspace.layout {
                case .grid:
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                        ForEach(workspace.orderedTasks) { tile($0, style: .tile) }
                    }
                case .list:
                    VStack(spacing: 10) {
                        ForEach(workspace.orderedTasks) { tile($0, style: .row) }
                    }
                case .board:
                    HStack(alignment: .top, spacing: 8) {
                        column("Priority", workspace.tasks.filter { $0.isHighPriority && !$0.isDone })
                        column("To Do", workspace.tasks.filter { !$0.isHighPriority && !$0.isDone })
                        column("Done", workspace.tasks.filter(\.isDone))
                    }
                }
            }
            .padding()
        }
        .animation(.spring(duration: 0.6, bounce: 0.25), value: workspace.tasks)
        .animation(.spring(duration: 0.6, bounce: 0.25), value: workspace.layout)
        .sensoryFeedback(.success, trigger: workspace.actions.count)
    }

    private func column(_ title: String, _ tasks: [TaskItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            ForEach(tasks) { tile($0, style: .compact) }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func tile(_ task: TaskItem, style: TaskTile.Style) -> some View {
        TaskTile(task: task, style: style)
            .matchedGeometryEffect(id: task.id, in: tiles)
            .transition(.scale(scale: 0.5).combined(with: .opacity))
            .onTapGesture { workspace.toggleDone(task.id) }
            // Press and hold: the user's versions of the agent's commands.
            .contextMenu {
                if !task.isDone && !task.isHighPriority {
                    Button("Prioritise", systemImage: "star") { workspace.prioritize(task.id, by: .user) }
                }
                Button(task.isDone ? "Reopen" : "Complete", systemImage: task.isDone ? "arrow.uturn.backward" : "checkmark.circle") {
                    workspace.toggleDone(task.id)
                }
                Button("Delete", systemImage: "trash", role: .destructive) { workspace.delete(task.id, by: .user) }
            }
    }
}

/// One coloured task tile. It pulses whenever its task changes.
struct TaskTile: View {
    enum Style { case tile, row, compact }

    let task: TaskItem
    let style: Style

    var body: some View {
        content
            .foregroundStyle(.white)
            .padding(style == .compact ? 10 : 14)
            .frame(maxWidth: .infinity, minHeight: style == .tile ? 120 : nil, alignment: .topLeading)
            .background(task.category.color.gradient, in: .rect(cornerRadius: style == .compact ? 14 : 22))
            .saturation(task.isDone ? 0.1 : 1)
            .opacity(task.isDone ? 0.7 : 1)
            .phaseAnimator([false, true], trigger: task.revision) { tile, pulsing in
                tile
                    .scaleEffect(pulsing ? 1.07 : 1)
                    .shadow(color: task.category.color.opacity(pulsing ? 0.7 : 0), radius: pulsing ? 18 : 0)
            } animation: { _ in
                .spring(duration: 0.35, bounce: 0.5)
            }
    }

    @ViewBuilder private var content: some View {
        switch style {
        case .tile:
            VStack(alignment: .leading, spacing: 6) {
                HStack { glyph; Spacer(); badge }
                Spacer(minLength: 0)
                Text(task.title).font(.headline)
                Text(task.category.rawValue.capitalized).font(.caption.weight(.medium)).opacity(0.8)
            }
        case .row:
            HStack(spacing: 12) {
                glyph
                VStack(alignment: .leading) {
                    Text(task.title).font(.headline)
                    Text(task.category.rawValue.capitalized).font(.caption.weight(.medium)).opacity(0.8)
                }
                Spacer()
                badge
            }
        case .compact:
            VStack(alignment: .leading, spacing: 6) {
                HStack { Image(systemName: symbol).font(.subheadline.bold()); Spacer(); badge }
                Text(task.title).font(.caption.weight(.semibold)).lineLimit(3)
            }
        }
    }

    private var symbol: String { task.isDone ? "checkmark" : task.category.symbol }

    private var glyph: some View {
        Image(systemName: symbol)
            .font(.title3.weight(.semibold))
            .frame(width: 40, height: 40)
            .background(.black.opacity(0.15), in: .circle)
            .symbolEffect(.bounce, value: task.revision)
    }

    @ViewBuilder private var badge: some View {
        if task.isHighPriority && !task.isDone {
            Image(systemName: "star.fill").foregroundStyle(.yellow)
        }
    }
}

extension TaskCategory {
    var color: Color {
        switch self {
        case .development: .blue
        case .testing: .green
        case .design: .pink
        case .operations: .orange
        }
    }

    var symbol: String {
        switch self {
        case .development: "hammer.fill"
        case .testing: "checkmark.seal.fill"
        case .design: "paintbrush.pointed.fill"
        case .operations: "gearshape.2.fill"
        }
    }
}

extension BoardLayout {
    var symbol: String {
        switch self {
        case .grid: "square.grid.2x2"
        case .list: "list.bullet"
        case .board: "rectangle.split.3x1"
        }
    }
}
