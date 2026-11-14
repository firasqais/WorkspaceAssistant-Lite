# Swift Code Guide

@Metadata {
    @TechnologyRoot
}

Every keyword and `@` attribute you meet in the WorkspaceAssistant tutorials, explained with the app's own code. Examples come from **WorkspaceAssistant Lite**; a few items marked *Full only* appear only in the Full version. In Full, the same keywords appear in different files: `WorkspaceStore`, the view models and the services.

Most of these appear together in one place. The top of `Workspace.swift` reads like this:

```swift
@MainActor               // all of its code runs on the main thread, like the UI
@Observable              // SwiftUI redraws any view that reads a property when it changes
final class Workspace {  // a class (shared, by reference) that nothing may subclass
    var tasks: [TaskItem] = TaskItem.samples
    private(set) var actions: [AgentAction] = []   // anyone can read it; only Workspace can change it
}
```

The table is the quick index. The sections below explain each item.

| You see | In one line | Section |
| --- | --- | --- |
| `struct` | A value type: copying it makes an independent copy | Types |
| `class` / `final class` | A reference type, shared by everyone holding it; `final` forbids subclasses | Types |
| `enum` | A fixed set of cases, e.g. `grid, list, board` | Types |
| `extension` | Adds code to an existing type, often in another file | Types |
| `protocol` | A list of requirements a type promises to meet, e.g. `Tool`, `Identifiable` | Types |
| `static` | Belongs to the type itself, not to one instance | Types |
| `private` | Visible only inside the type (and its file) | Access control |
| `private(set)` | Anyone can read it, only the type can change it | Access control |
| `public` | Visible outside the module (*Full only*) | Access control |
| `@Observable` | Views that read a property redraw when it changes | Observation |
| `@State` | A view's own value that survives redraws | Observation |
| `@Environment` | Reads a shared object handed down from a parent view | Observation |
| `@Bindable` | Makes `$workspace.layout` bindings from an observable object | Observation |
| `@Binding` | A read-write link to a value owned by another view (*Full only*) | Observation |
| `@FocusState` | Tracks whether a text field has the keyboard | Observation |
| `async` / `await` | A function that can pause; `await` marks where it may | Concurrency |
| `Task { }` | Starts async work from ordinary code, such as a button tap | Concurrency |
| `@MainActor` | Runs on the main thread, where all UI updates must happen | Concurrency |
| `Sendable` | Safe to pass between threads (*Full only*) | Concurrency |
| `@Generable` | The model can generate this type, and only valid values of it | Foundation Models |
| `@Guide` | Describes or limits one generated property | Foundation Models |
| `Tool` | A Swift function the model can decide to call | Foundation Models |
| `LanguageModelSession` | One conversation with the on-device model | Foundation Models |
| `@Model` / `@Query` | SwiftData storage (*Full only*) | SwiftData |
| `some View` | "Some specific view type; the compiler knows which" | SwiftUI syntax |
| `@ViewBuilder` | Lets a property or function return different views from `if`/`switch` | SwiftUI syntax |
| `#Preview` | A canvas preview in Xcode, not part of the app | SwiftUI syntax |
| `guard`, `if let`, `defer`, `??`, `$0`, `\.title` | Everyday Swift shorthand | Everyday syntax |

## Types: struct, class, enum, protocol, extension

The app uses `struct` for data, `final class` for the two shared objects that change over time, and `enum` for fixed choices.

### struct: a value you copy

```swift
struct TaskItem: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var isDone = false
}
```

Assigning a struct makes an independent copy, so changing the copy never changes the original. That makes data predictable, and it's why `TaskItem`, `AgentAction` and every tool are structs. `let` properties never change after creation; `var` properties can.

SwiftUI views are structs too (`struct ContentView: View`). They're cheap descriptions of the screen, rebuilt whenever data changes.

### class and final class: one shared object

```swift
final class Workspace { … }
final class TaskAgent { … }
```

A class is a reference type: everyone who holds a `Workspace` holds the *same* one. The board, the agent's tools and the new-task sheet must all change the same tasks, so `Workspace` is a class.

`final` means no other class can inherit from it. It documents that subclassing isn't planned, and lets the compiler call methods a little faster. In app code, make classes `final` unless you have a reason not to.

### enum: a fixed set of choices

```swift
enum BoardLayout: String, CaseIterable {
    case grid, list, board
}
```

A `BoardLayout` can only be one of those three values, so a typo can't create a fourth. `: String` gives each case a `rawValue` (`"grid"`), and `CaseIterable` provides `BoardLayout.allCases`, which the layout picker loops over. Enums can also carry code, like the `symbol` property each layout uses for its icon.

Enums with no cases can't be created at all. `SimulatedAgent` is written as an `enum` on purpose: it's just a namespace for `static` functions.

### protocol and conformance: promises a type keeps

The names after the colon are protocols the type promises to satisfy:

| Protocol | Promise | Why the app needs it |
| --- | --- | --- |
| `Identifiable` | Has an `id` | `ForEach(workspace.orderedTasks)` can tell tasks apart and animate them |
| `Hashable` | Can be compared and hashed | `.animation(value: workspace.tasks)` detects changes |
| `CaseIterable` | Lists all its cases | `ForEach(BoardLayout.allCases, …)` in the picker |
| `Tool` | Has `name`, `description`, `Arguments`, `call` | The model can call it |
| `View` | Has a `body` | SwiftUI can draw it |
| `App` | Has a `body` that returns a `Scene` | It can be the app's entry point |

Swift writes the code for `Hashable` and `CaseIterable` automatically when every property allows it. In the Full version, `TaskRepository` is the app's own protocol, so SwiftData and in-memory storage can be swapped (*Full only*).

### extension: more code for an existing type

```swift
extension TaskItem {
    static let samples: [TaskItem] = [ … ]
}
```

An extension adds properties or functions to a type, even one you didn't write. The app uses them to keep sample data and display code (icons, colours) out of the main type.

### static: belongs to the type

`TaskItem.samples` is written on the type, not on one task, because there's one list of samples for the whole app. Inside the type you can write `Self.samples`. `TaskAgent.makeSession` is `static` because it builds a session before the agent itself exists.

## Access control: who may see and change what

Access control keeps the rule "only `Workspace` changes the board" true: other code can read its state, but must go through its methods to change it.

```swift
final class TaskAgent {
    let workspace: Workspace                  // anyone can read; nobody can replace it
    private(set) var messages: [Message] = [] // anyone can read; only TaskAgent can change
    private(set) var isWorking = false
    private var session: LanguageModelSession // nobody outside TaskAgent can even see it
}
```

| Keyword | Who can read it | Who can change it | In the app |
| --- | --- | --- | --- |
| *(nothing)*, which means `internal` | Any file in the app | Any file in the app, if it's a `var` | `Workspace.tasks`, `layout` |
| `private(set) var` | Any file in the app | Only code inside the type | `messages`, `isWorking`, `actions` |
| `private` | Only code inside the type, in that file | Only code inside the type | `session`, `firstActionOfTurn`, `words(in:)` |
| `fileprivate` | Any code in the same file | Same | Not used in Lite |
| `public` | Other modules too | Other modules too, if `var` | Used widely in Full (*Full only*) |

**Why `private(set)` matters here.** The chat view shows `agent.messages` and the spinner reads `agent.isWorking`, so they can't be `private`. But if a view could write `agent.isWorking = false`, the screen could lie about what the agent is doing. `private(set)` allows reading everywhere and writing only inside `TaskAgent`.

**`private` on view properties.** You'll see `@State private var draft = ""` and `@Environment(Workspace.self) private var workspace` in every view. Apple recommends making view state `private`, because it belongs to that view alone and must not be set from outside.

**`let` vs `private(set) var`.** `let` can never change, even inside the type. `private(set) var` changes, but only from inside. `workspace` is a `let` because an agent always works on the same workspace; `messages` grows during a conversation.

## Observation and SwiftUI state

SwiftUI redraws a view when data it reads changes. These attributes tell SwiftUI which data to watch, who owns it, and how views share it.

### @Observable: a class SwiftUI can watch

```swift
@Observable
final class Workspace {
    var tasks: [TaskItem] = TaskItem.samples
    var layout: BoardLayout = .grid
}
```

`@Observable` is a macro: at compile time it adds tracking code to every property. When `BoardView` reads `workspace.layout` and the agent's tool later changes it, SwiftUI redraws only the views that read `layout`. That's why the board changes live while the agent works, with no extra code.

It goes on the line before `class` because it's an attribute of the whole class, like `@MainActor`. The order of the two doesn't matter. It only works on classes, not structs.

In the Full version, `@ObservationIgnored` marks a property SwiftUI shouldn't watch, such as the engine or a running `Task` (*Full only*).

### @State: a value the view owns

```swift
@State private var sheet: Sheet?          // ContentView: which sheet is open
@State private var draft = ""             // AgentPanel: what you're typing
```

A view struct is recreated on every redraw, so a plain `var` would be reset. `@State` keeps the value alive for as long as the view is on screen. Use it for small, local UI state.

The app also keeps its two main objects in `@State`, in `WorkspaceAssistantApp`, so they're created once and live as long as the app:

```swift
@State private var workspace: Workspace
@State private var agent: TaskAgent

init() {
    let workspace = Workspace()
    _workspace = State(initialValue: workspace)
    _agent = State(initialValue: TaskAgent(workspace: workspace))
}
```

The underscore form, `_workspace`, is the `State` wrapper itself. It's needed here because the agent must be built with the *same* workspace, so both are created together in `init`.

### .environment(...) and @Environment: share an object with every view below

```swift
ContentView()
    .environment(workspace)          // in the App: hand it down

@Environment(Workspace.self) private var workspace   // in any view below: pick it up
```

Instead of passing `workspace` through every initializer, the app puts it in the environment once, and any view underneath can read it by type. `@Environment(\.dismiss)` in `NewTaskSheet` uses the same mechanism for a value SwiftUI provides: the action that closes the sheet.

### @Bindable and $: two-way connections

```swift
var body: some View {
    @Bindable var workspace = workspace
    …
    Picker("Layout", selection: $workspace.layout) { … }
}
```

A control like `Picker`, `Toggle` or `TextField` needs a **binding**: something it can both read and write. The `$` prefix makes one. `$draft` works directly on `@State`, but an object from `@Environment` can't make bindings by itself, so `@Bindable var workspace = workspace` wraps it first. Choosing a layout in the picker then writes straight into `workspace.layout`.

### Other wrappers you'll meet

| Wrapper | What it does | Where |
| --- | --- | --- |
| `@FocusState` | True while a text field has the keyboard; set it to `false` to hide the keyboard | `AgentPanel` composer |
| `@Namespace` | An ID space for `matchedGeometryEffect`, so tiles glide between layouts | `BoardView` |
| `@Binding` | A read-write link to a value another view owns | `BoardView`'s navigation path (*Full only*) |
| `@ScaledMetric` | A size that grows with the user's text size setting | Tiles and pills (*Full only*) |
| `@Previewable` | Lets a `#Preview` use `@State` | Previews (*Full only*) |

## Concurrency: async, await, Task and @MainActor

The model takes seconds to answer, so asking it must not freeze the screen. Swift concurrency lets that work wait without blocking, and `@MainActor` keeps every change to the board on the main thread, where SwiftUI expects it.

### async and await: functions that can pause

```swift
func send(_ text: String) async {
    …
    let response = try await session.respond(to: prompt)
    messages.append(Message(role: .agent, text: response.content))
}
```

`async` on a function means it can pause while it waits for something slow. `await` marks each place where it may pause. While `send` waits for the model, the app keeps scrolling, animating and redrawing; when the answer arrives, `send` carries on from the next line.

`throws` means a function can fail with an error, and `try` marks the call that might fail. `try await` is both: it may pause, and it may throw. The `do { … } catch { … }` around it in `send` turns a thrown error into a chat message.

### Task { }: start async work from a button

```swift
Button("Send") {                      // simplified from AgentPanel
    Task { await agent.send(text) }
}
```

A button's action is ordinary, non-async code, so it can't `await` directly. `Task { … }` starts a new piece of async work and returns at once. The modifier `.task { agent.prewarm() }` on `AgentPanel` is the view version: it runs when the view appears and is cancelled when it disappears.

### @MainActor: run on the main thread

```swift
@MainActor
@Observable
final class Workspace { … }
```

All UI updates must happen on the main thread. `@MainActor` on the class makes every property and method of `Workspace` and `TaskAgent` run there, and the compiler checks it: code that isn't on the main actor must `await` to reach them.

That's why each tool has an `await` that looks unnecessary:

```swift
struct AddTaskTool: Tool {
    func call(arguments: Arguments) async throws -> String {
        await workspace.addTask(title: arguments.title, …, by: .agent)
    }
}
```

Foundation Models calls tools away from the main thread. `addTask` belongs to the main actor, so the call must hop over to it, and `await` marks that hop. Without `@MainActor`, a tool and a tap could change `tasks` at the same moment and corrupt it; with it, they take turns.

### defer: run this when the function exits

```swift
isWorking = true
defer { isWorking = false }
```

The `defer` block runs when `send` returns, by any path: a normal reply, the simulated agent's early `return`, or an error. The spinner can never get stuck on.

### In the Full version (*Full only*)

| You see | Meaning |
| --- | --- |
| `Sendable` | The type is safe to pass between threads; most value types qualify automatically |
| `nonisolated` | Not tied to the main actor, so it can be used from any thread, e.g. constants like `Spacing` |
| `Task<Void, Never>?` | A stored handle to running work, so it can be cancelled with `.cancel()` |
| `Task { [weak self] in … }` | The task doesn't keep the view model alive if the screen goes away |

## Foundation Models: @Generable, @Guide, Tool and the session

These come from Apple's `FoundationModels` framework, which runs the on-device model. `@Generable` is the most important: it lets the model produce a Swift value instead of free text.

### @Generable: a type the model can fill in

```swift
@Generable
enum TaskCategory: String, CaseIterable {
    case development, testing, design, operations
}
```

`@Generable` is a macro that describes the type to the model and constrains its output while it generates. The model normally writes any text it likes; for a `@Generable` type it can only produce valid values. For `TaskCategory` that means exactly one of the four cases, never "Dev" or "Testing work". This is called **guided generation**.

It's used in two ways in the app:

1. **On the enums** `TaskCategory` and `BoardLayout`, so the model can pick them as tool arguments.
2. **On each tool's `Arguments` struct**, so every tool call arrives as a typed Swift value.

In TaskSynthesiser the same macro goes on a whole result struct, and `respond(to:generating: ProjectBlueprint.self)` returns a filled-in `ProjectBlueprint`.

### @Guide: describe or limit one property

```swift
@Generable
struct Arguments {
    @Guide(description: "A short task title in Title Case, e.g. 'Review Pull Requests'")
    var title: String
    var category: TaskCategory
    @Guide(description: "True only if the user says the task is important, urgent or high priority")
    var highPriority: Bool
}
```

`@Guide` tells the model what a property means, in plain English. It can also add hard limits: `@Guide(.range(1...30))` for numbers, or `@Guide(.count(3))` for arrays. A property without `@Guide`, like `category`, is described by its name and type alone.

### Tool: a function the model may call

```swift
struct AddTaskTool: Tool {
    let name = "addTask"
    let description = "Adds a new task to the board."
    let workspace: Workspace

    @Generable struct Arguments { … }

    func call(arguments: Arguments) async throws -> String {
        await workspace.addTask(title: arguments.title, category: arguments.category,
                                highPriority: arguments.highPriority, by: .agent)
    }
}
```

`Tool` is a protocol with four requirements:

| Part | Read by | Purpose |
| --- | --- | --- |
| `name` | The model | How it refers to the tool |
| `description` | The model | When it should use it |
| `Arguments` | The model fills it in | What it must provide; `@Generable`, so always valid |
| `call(arguments:)` | Your Swift code | Does the real work and returns what happened |

The returned `String` goes back to the model, which reads it before answering. That's why `Workspace` commands return honest sentences like "“X” was already done. Nothing changed."

### LanguageModelSession: one conversation

```swift
let tools: [any Tool] = [AddTaskTool(workspace: workspace), …]
let session = LanguageModelSession(model: SystemLanguageModel.default, tools: tools, instructions: instructions)

let response = try await session.respond(to: prompt)
let reply = response.content
```

A session holds the instructions, the tools and the whole conversation so far, so follow-ups like "and the other one" make sense. `respond(to:)` is where the agent loop happens: the model may call several tools, read each result, and only then write `response.content`.

`[any Tool]` means "an array of values of *any* type that conforms to `Tool`"; the four tools are different structs, so `any` is needed to put them in one array.

| Also in TaskAgent | Meaning |
| --- | --- |
| `SystemLanguageModel.default.availability` | Whether the model can run, and if not, why |
| `session.prewarm()` | Loads the model early so the first reply is faster |
| `LanguageModelSession.GenerationError` | Errors such as `.exceededContextWindowSize` (conversation too long) or `.guardrailViolation` |

## SwiftData: saving tasks (Full only)

Lite keeps tasks in memory, and they reset when the app restarts. Full saves them with SwiftData, behind its own `TaskRepository` protocol, so the rest of the app never touches the database directly.

### @Model: a class SwiftData stores

```swift
@Model
final class TaskRecord {
    var id: UUID = UUID()
    var title: String = ""
    var categoryRaw: String = TaskCategory.development.rawValue
    var stepsData: Data = Data()
    …
}
```

`@Model` is a macro, like `@Observable`, that turns a class into a stored table: each property becomes a column. It must be a class, which is why `TaskRecord` is a `final class` while the app's own `TaskItem` stays a struct. Enums are stored as their raw strings (`categoryRaw`) and the steps as encoded `Data`, so the stored format doesn't depend on app types. Every property has a default, which is what CloudKit sync would need later.

### ModelContainer, ModelContext and #Predicate

```swift
container = try ModelContainer(for: TaskRecord.self, configurations: configuration)

try context.fetch(FetchDescriptor<TaskRecord>(sortBy: [SortDescriptor(\.sortIndex)]))
try context.delete(model: TaskRecord.self, where: #Predicate { ids.contains($0.id) })
try context.save()
```

| Piece | Role |
| --- | --- |
| `ModelContainer` | The database itself, set up for `TaskRecord`; `isStoredInMemoryOnly: true` for tests |
| `ModelContext` | The workspace you read and change records through: `fetch`, `insert`, `delete`, `save` |
| `FetchDescriptor` | What to fetch, filtered and sorted |
| `#Predicate { … }` | A filter the database can run, written as Swift; here, records whose `id` is in `ids` |

You'll often see `@Query` in SwiftData tutorials: a view property that fetches and stays up to date. Full doesn't use it, because views get tasks from the view models, not from the database. TaskSynthesiser stores its blueprints with SwiftData too.

## SwiftUI view syntax

A SwiftUI view is a struct with a `body` that *describes* the screen. SwiftUI calls `body` again whenever data it reads changes, and works out what to redraw.

### @main, App and Scene: where the app starts

```swift
@main
struct WorkspaceAssistantApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

`@main` marks the app's entry point; there's exactly one. An `App`'s body returns a `Scene`, and `WindowGroup` is the scene that shows your first view.

### some View: "a specific view, I won't spell it out"

```swift
var body: some View { … }
private func column(_ title: String, _ tasks: [TaskItem]) -> some View { … }
```

Every view's real type is long and nested, such as a `ScrollView` of a `Group` of a `LazyVGrid`. `some View` means "one specific type that conforms to `View`; the compiler knows which". You get the speed of a concrete type without writing it. Compare `any Tool`, which allows a *different* type for each element.

### @ViewBuilder: return different views from if or switch

```swift
@ViewBuilder private var badge: some View {
    if task.isHighPriority && !task.isDone {
        Image(systemName: "star.fill").foregroundStyle(.yellow)
    }
}
```

`body` already allows `if`, `switch` and several views in a row. A property or function you write yourself needs `@ViewBuilder` to work the same way. Here `badge` is a star, or nothing; in `TaskTile`, `content` is a different layout for each `style`.

### Modifiers: each line wraps the view in another

```swift
Text(title)
    .font(.caption.bold())
    .textCase(.uppercase)
    .foregroundStyle(.secondary)
```

Each `.modifier()` returns a new view wrapping the previous one, so order matters: `.padding()` then `.background()` colours the padding too, while the reverse doesn't. A few modifiers in the app that are worth knowing:

| Modifier | What it does |
| --- | --- |
| `.animation(.spring(…), value: workspace.tasks)` | Animates every change caused by `tasks` changing, including the agent's |
| `.matchedGeometryEffect(id: task.id, in: tiles)` | Moves the same tile smoothly between grid, list and board |
| `.sheet(item: $sheet)` | Shows a sheet while `sheet` isn't `nil`; setting it back to `nil` closes it |
| `.safeAreaInset(edge: .bottom)` | Pins the "Ask the Agent" button above the bottom edge, and scrolls content clear of it |
| `.sensoryFeedback(.success, trigger: …)` | A haptic tap each time the agent does something |
| `.task { … }` | Runs async work when the view appears |

### ForEach: one view per item

```swift
ForEach(workspace.orderedTasks) { tile($0, style: .tile) }
ForEach(BoardLayout.allCases, id: \.self) { layout in … }
```

`ForEach` needs to tell items apart. `TaskItem` is `Identifiable`, so its `id` is used. Enum cases have no `id`, so `id: \.self` says "each value is its own ID".

### #Preview: a canvas preview

```swift
#Preview {
    let workspace = Workspace()
    ContentView()
        .environment(workspace)
        .environment(TaskAgent(workspace: workspace))
}
```

`#Preview` is a macro that shows the view in Xcode's canvas. It isn't part of the running app. A preview must provide everything the view reads from the environment, or it crashes.

## Everyday Swift syntax

The shorthand below appears on almost every page of the tutorials. Most of it is in `Workspace.swift`.

### Optionals: a value that might be missing

```swift
func index(of id: TaskItem.ID) -> Int? {          // Int? = an Int, or nil
    tasks.firstIndex { $0.id == id }
}

guard let index = index(of: id) else { return "That task no longer exists." }
tasks[index].isDone = true                         // from here on, index is a plain Int
```

| You see | Meaning |
| --- | --- |
| `Int?`, `Sheet?` | Optional: holds a value or `nil` |
| `guard let x = … else { return }` | Unwrap, or leave early; `x` is usable for the rest of the function. The app uses it to reject bad input first |
| `if let x = … { }` | Unwrap; `x` exists only inside the braces |
| `a ?? b` | `a` if it isn't `nil`, otherwise `b` |
| `if case .exceededContextWindowSize = error` | Checks whether a value matches one enum case |
| `catch let error as GenerationError` | Catches only that error type, already cast |

### Closures: short inline functions

```swift
tasks.filter { !$0.isDone }          // $0 = the first argument: each task
tasks.filter(\.isDone)               // key path: "the isDone of each task"
tasks.map(\.title).joined(separator: ", ")
```

A closure is a function without a name, written in braces. When it's the last argument, it goes after the parentheses (a **trailing closure**), which is why you see `Button("Delete") { … }` and `filter { … }`. `$0`, `$1` are the closure's arguments when you don't name them; `{ layout in … }` names it. `\.isDone` is a **key path**, a shorter way to say "read this property from each item".

### Functions and properties

| You see | Meaning | Example |
| --- | --- | --- |
| Argument labels | Names used at the call site | `switchLayout(to: .list, by: .agent)` |
| `_` before a parameter | No label at the call site | `complete(_ id:)` is called as `complete(id, by: .user)` |
| `@discardableResult` | No warning if the caller ignores the return value | Taps ignore the sentence; tools return it to the model |
| Computed property | Calculated each time it's read, not stored | `var orderedTasks: [TaskItem] { … }` |
| `init(…)` | Sets up a new instance | `TaskAgent.init(workspace:)` |
| `self.workspace = workspace` | `self.` separates the property from the parameter with the same name | `TaskAgent.init` |
| `Self.words(in:)` | Calls a `static` member of the current type | `Workspace.findTask` |
| `.toggle()` | Flips a `Bool` | `tasks[index].isDone.toggle()` |

### Strings and expressions

| You see | Meaning |
| --- | --- |
| `"Added \(title)"` | String interpolation: inserts a value into the text |
| `""" … """` | A multi-line string, used for the agent's instructions |
| `condition ? a : b` | `a` if true, else `b`: `highPriority ? " (high priority)" : ""` |
| `!` before a value | "not": `!$0.isDone` |
| `// MARK: - Commands` | Not code: a heading in Xcode's jump bar |
| `///` | A documentation comment; Xcode shows it when you Option-click the name |
