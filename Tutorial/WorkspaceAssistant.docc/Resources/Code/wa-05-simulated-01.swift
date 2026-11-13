import Foundation

/// A stand-in for the on-device model, used only when Apple Intelligence isn't available
/// (for example a simulator on a Mac with Apple Intelligence turned off).
///
/// It is NOT AI. It spots a few keywords and calls the same Workspace commands the real tools call,
/// so the demo still works. It only knows the four built-in tools; tools you add need the real model.
/// You never need to open this file while teaching.
@MainActor
enum SimulatedAgent {
    private enum Intent { case add, complete, prioritize }

    static func respond(to prompt: String, workspace: Workspace) async -> String {
        var results: [String] = []
        var lastIntent: Intent?

        // "Prioritise the leak and show the board" → one clause per action.
        for clause in clauses(in: prompt) {
            let words = tokens(in: clause)

            if let layout = detectedLayout(in: words) {
                await think()
                results.append(workspace.switchLayout(to: layout, by: .agent))
                continue
            }
            // "I finished the tests and the pipeline": the second clause reuses the last verb.
            guard let intent = detectedIntent(in: words) ?? lastIntent else { continue }
            lastIntent = intent
            await think()
            switch intent {
            case .add:
                results.append(workspace.addTask(title: makeTitle(from: words), category: category(for: words), highPriority: isUrgent(words), by: .agent))
            case .complete:
                results.append(workspace.completeTask(taskWords(words)))
            case .prioritize:
                results.append(workspace.prioritizeTask(taskWords(words)))
            }
        }

        await think()
        guard !results.isEmpty else {
            return "I’m the simulated agent, so I only understand simple requests, for example “prioritise the memory leak” or “show the board”."
        }
        return results.map(firstSentence).joined(separator: " ")
    }

    // MARK: - Keyword spotting

    private static func detectedIntent(in words: [String]) -> Intent? {
        if words.contains(where: { ["add", "create", "new"].contains($0) }) { return .add }
        if words.contains(where: { $0.hasPrefix("priorit") || ["important", "urgent"].contains($0) }) { return .prioritize }
        if words.contains(where: { ["done", "finished", "finish", "complete", "completed"].contains($0) }) { return .complete }
        return nil
    }

    private static func detectedLayout(in words: [String]) -> BoardLayout? {
        let wantsLayout = words.contains { ["show", "switch", "view", "layout", "display", "change"].contains($0) }
        guard wantsLayout || words.count <= 2 else { return nil }
        if words.contains("board") || words.contains("columns") || words.contains("kanban") { return .board }
        if words.contains("list") { return .list }
        if words.contains("grid") || words.contains("tiles") { return .grid }
        return nil
    }

    /// "add a high-priority task to review pull requests" → "Review Pull Requests"
    /// "add a design review task" → "Design Review"
    private static func makeTitle(from words: [String]) -> String {
        var rest = words
        if let taskIndex = rest.firstIndex(where: { $0 == "task" || $0 == "tasks" }) {
            let after = Array(rest[(taskIndex + 1)...])
            if let first = after.first, ["to", "for", "called", "named", "about"].contains(first), after.count > 1 {
                rest = Array(after.dropFirst())
            } else {
                rest = Array(rest[..<taskIndex])
            }
        }
        let filler: Set<String> = ["add", "create", "new", "a", "an", "the", "high", "priority", "urgent", "important", "please", "me", "my"]
        let kept = rest.filter { !filler.contains($0) }
        return kept.isEmpty ? "New Task" : kept.map(\.capitalized).joined(separator: " ")
    }

    /// The words that name the task, e.g. "i finished the unit tests" → "unit tests".
    private static func taskWords(_ words: [String]) -> String {
        let filler: Set<String> = [
            "i", "ve", "m", "s", "we", "the", "a", "an", "my", "mark", "set", "make", "as", "is", "are", "it", "to",
            "now", "too", "also", "please", "have", "has", "been", "just", "done", "finished", "finish",
            "complete", "completed", "important", "urgent", "high", "priority", "task", "tasks",
        ]
        return words.filter { !filler.contains($0) && !$0.hasPrefix("priorit") }.joined(separator: " ")
    }

    private static func category(for words: [String]) -> TaskCategory {
        if words.contains(where: { $0.hasPrefix("test") || ["qa", "bug", "audit"].contains($0) }) { return .testing }
        if words.contains(where: { ["design", "ui", "ux", "icon", "mockup", "onboarding"].contains($0) }) { return .design }
        if words.contains(where: { ["deploy", "release", "server", "pipeline", "ci", "build", "backup"].contains($0) }) { return .operations }
        return .development
    }

    private static func isUrgent(_ words: [String]) -> Bool {
        words.contains("urgent") || words.contains("important") || words.contains("priority")
    }

    // MARK: - Text helpers

    private static func clauses(in prompt: String) -> [String] {
        var text = prompt.lowercased()
        for separator in [" and then ", " then ", " and ", ",", ";", "."] {
            text = text.replacingOccurrences(of: separator, with: "|")
        }
        return text.split(separator: "|").map(String.init)
    }

    private static func tokens(in text: String) -> [String] {
        text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    private static func firstSentence(_ text: String) -> String {
        let sentence = text.components(separatedBy: ". ").first ?? text
        return sentence.hasSuffix(".") ? sentence : sentence + "."
    }

    /// A short pause so each change lands one at a time, like the real agent.
    private static func think() async {
        try? await Task.sleep(for: .milliseconds(700))
    }
}
