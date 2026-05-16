# iOSAgentSDK

A small, opinionated agent harness for iOS — `while`-loop + tools + streaming
events — built around Anthropic's [building-effective-agents](https://www.anthropic.com/research/building-effective-agents)
shape. Same `model + harness + tools` triple you'd see in a CLI agent, but the
*environment* is iOS: HealthKit, EventKit, CoreLocation, Contacts, MapKit,
WeatherKit, Reminders, Shortcuts, AVFoundation — each behind the system's
per-data-type permission prompt.

The companion writeup: [blog/推特长文_iOS_Agent_2026-05-16_v1.md](blog/推特长文_iOS_Agent_2026-05-16_v1.md).

## Status

Early. The SDK runs, the demo app runs, three providers are wired. There are
no unit tests yet and the API will move. Use it to learn from, not to ship.

## Requirements

- iOS 17+ / macOS 14+
- Swift 5.9 / Xcode 15
- An API key for one of: Anthropic, GLM (智谱), MiniMax

## Install

Swift Package Manager:

```swift
.package(url: "https://github.com/cxjwin/ios-agent-sdk", branch: "main")
```

Then add `iOSAgentSDK` to your target's dependencies.

## Quick start

```swift
import iOSAgentSDK

let agent = Agent(
    client: AnthropicClient(apiKey: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""),
    model: "claude-opus-4-7",
    systemPrompt: "You are a helpful iOS assistant. Tools may run in parallel.",
    tools: [
        CurrentDateTimeTool(),
        CurrentLocationTool(),
        WeatherTool(),
        EventKitTodayTool(),
        HealthKitSleepTool(),
    ],
    maxTurns: 10
)

for try await event in agent.runStreaming("早上好，给我一份晨间播报") {
    switch event {
    case .turnStarted(let n):                          print("— turn \(n)")
    case .toolCallStarted(_, let name, let input):     print("→ \(name) \(input)")
    case .toolCallFinished(_, let name, _, let err):   print("← \(name) \(err ? "ERR" : "ok")")
    case .finalAnswer(let text):                       print("\n\(text)")
    default: break
    }
}
```

## Three providers

```swift
// Anthropic (native tool-use protocol)
let anthropic = AnthropicClient(apiKey: key)

// GLM via OpenAI-compatible endpoint
let glm = OpenAICompatibleClient.glm(apiKey: key)

// MiniMax via OpenAI-compatible endpoint
let minimax = OpenAICompatibleClient.minimax(apiKey: key)
```

`AnthropicClient` speaks Anthropic's `tool_use` / `tool_result` blocks
directly. `OpenAICompatibleClient` translates OpenAI-style `tool_calls` into
the same internal shape so the rest of the harness doesn't care which
provider it's talking to. MiniMax exposes both protocols — pick whichever
one's behaving better that week.

## Architecture

Four pieces, same names as the Anthropic essay:

| Piece           | File(s)                                                                |
| --------------- | ---------------------------------------------------------------------- |
| **model**       | `LLMClient` protocol + `AnthropicClient` / `OpenAICompatibleClient`    |
| **harness**     | `Agent` (actor, loop + streaming) + `ToolExecutor` (parallel dispatch) |
| **tools**       | `ToolProtocol` + `Sources/iOSAgentSDK/Tools/*`                         |
| **environment** | the host iOS app — Info.plist usage strings, entitlements, UI         |

The loop:

1. Append user message → call LLM.
2. If `stop_reason == end_turn`, emit `.finalAnswer` and return.
3. Otherwise extract `tool_use` blocks, run them **concurrently** via
   `withTaskGroup`, append the `tool_result` blocks, go to 1.
4. Bail with `maxTurnsExceeded` if the budget runs out.

Every step emits an `AgentEvent` — `turnStarted`, `llmRequestStarted`,
`llmResponseReceived`, `toolCallStarted`, `toolCallFinished`, `finalAnswer` —
so the UI can show a live "在查睡眠… 在查日程… 在查天气…" trace. That trace
doubles as a profiler when you're tuning prompts or tool latency.

## Tools shipped

19 tools in `Sources/iOSAgentSDK/Tools/`:

**Read** — `CurrentDateTimeTool`, `CurrentLocationTool`, `HealthKitSleepTool`,
`HealthKitStepsTool`, `HealthKitWorkoutsTool`, `HealthKitHRVTool`,
`EventKitTodayTool`, `ReminderListTool`, `WeatherTool`, `MapsSearchTool`,
`ContactsTool`, `ReadSandboxFileTool`

**Write — system-mediated** (each opens the relevant system UI for the user to
confirm — the sandbox forbids silent send/run) — `CreateReminderTool`,
`CreateCalendarEventTool`, `ComposeMessageTool`, `ComposeEmailTool`,
`RunShortcutTool`

**Write — direct** (no system prompt; gate at the host-app level if you need
human-in-the-loop) — `WriteSandboxFileTool`

**Output** — `SpeakTool` (AVSpeechSynthesizer)

Each tool conforms to `ToolProtocol`:

```swift
public protocol ToolProtocol: Sendable {
    var name: String { get }
    var description: String { get }
    var inputSchema: [String: Any] { get }
    var isReadOnly: Bool { get }
    func execute(input: [String: Any]) async throws -> String
}
```

Read-only tools default `isReadOnly = true` via a protocol extension. The
harness doesn't currently gate on it — it's there for hosts that want to
auto-approve safe tools and prompt on writes.

## Permissions

Tools that touch user data trigger Apple's system permission prompt on first
call. The host app needs the matching `Info.plist` usage strings, e.g.:

- `NSHealthShareUsageDescription` (HealthKit reads)
- `NSCalendarsFullAccessUsageDescription` (EventKit)
- `NSRemindersFullAccessUsageDescription`
- `NSLocationWhenInUseUsageDescription`
- `NSContactsUsageDescription`
- `NSSpeechRecognitionUsageDescription` (if you add STT)

If the user revokes any of them later, the corresponding tool returns an
error string the model can read and react to.

## Demo app

`DemoApp/iOSAgentSDKDemo/` is a SwiftUI app that wires up all 18 tools and
streams the event log to the screen. Open it in Xcode and add your API key.

## Examples (Swift Package executables)

- `swift run MockSmokeTest` — no network, exercises the loop with a fake
  client.
- `ANTHROPIC_API_KEY=... swift run RealAnthropic` — hits Anthropic for real.

## Roadmap

Borrowed from the blog post, grouped by component:

- **tools**: MCP client; App Intents bridge; web search; persistent
  scratchpad.
- **harness**: Agent Skills (lazy-loaded knowledge packs); session
  persistence across launches; per-tool approval policy.
- **model**: Foundation Models routing for iOS 26+ on-device inference.
- **environment**: drop-in integration for first-party host apps.

## License

MIT. See [LICENSE](LICENSE).
