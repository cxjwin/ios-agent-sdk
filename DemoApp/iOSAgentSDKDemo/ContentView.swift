import SwiftUI
import iOSAgentSDK

struct StampedEvent: Identifiable {
    let id = UUID()
    let event: AgentEvent
    let elapsedMs: Int
}

struct ContentView: View {
    enum Provider: String, CaseIterable, Identifiable {
        case glm = "GLM"
        case minimax = "MiniMax (OpenAI)"
        case minimaxAnthropic = "MiniMax (Anthropic)"
        var id: String { rawValue }
    }

    @State private var provider: Provider = .glm
    @State private var apiKey: String = ""
    @State private var baseURLOverride: String = ""
    @State private var model: String = ""
    @State private var question: String = "给我做个晨间播报: 我昨晚睡得怎么样、今天日程多不多、当前位置天气如何、要不要多走几步。顺便记一下下午3点给妈妈打电话。"
    @State private var response: String = ""
    @State private var error: String = ""
    @State private var isRunning: Bool = false
    @State private var elapsedMs: Int = 0
    @State private var events: [StampedEvent] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Provider") {
                    Picker("提供商", selection: $provider) {
                        ForEach(Provider.allCases) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .onChange(of: provider) { _, new in
                        model = defaultModel(for: new)
                        baseURLOverride = defaultBaseURL(for: new)
                        apiKey = UserDefaults.standard.string(forKey: keyName(for: new)) ?? ""
                    }

                    SecureField("API Key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: apiKey) { _, new in
                            UserDefaults.standard.set(new, forKey: keyName(for: provider))
                        }

                    TextField("Model", text: $model)
                        .textInputAutocapitalization(.never)
                    TextField("Base URL", text: $baseURLOverride)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.caption, design: .monospaced))
                }

                Section("Question") {
                    TextField("问题", text: $question, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section {
                    Button {
                        Task { await run() }
                    } label: {
                        HStack {
                            if isRunning {
                                ProgressView()
                                Text("运行中... \(elapsedMs)ms")
                            } else {
                                Image(systemName: "play.fill")
                                Text("Run Agent")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isRunning || apiKey.isEmpty)
                }

                if !events.isEmpty {
                    Section("Progress") {
                        ForEach(events) { stamped in
                            EventRow(event: stamped.event, elapsedMs: stamped.elapsedMs)
                        }
                    }
                }

                if !response.isEmpty {
                    Section("Final Answer (\(elapsedMs) ms)") {
                        Text(response)
                            .font(.system(.body))
                            .textSelection(.enabled)
                    }
                }

                if !error.isEmpty {
                    Section("Error") {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("iOS Agent SDK Demo")
            .onAppear {
                model = defaultModel(for: provider)
                baseURLOverride = defaultBaseURL(for: provider)
                apiKey = UserDefaults.standard.string(forKey: keyName(for: provider)) ?? ""
            }
        }
    }

    func defaultModel(for p: Provider) -> String {
        switch p {
        case .glm: return "glm-4.6"
        case .minimax, .minimaxAnthropic: return "MiniMax-M2"
        }
    }

    func defaultBaseURL(for p: Provider) -> String {
        switch p {
        case .glm: return "https://open.bigmodel.cn/api/coding/paas/v4"
        case .minimax: return "https://api.minimaxi.com/v1"
        case .minimaxAnthropic: return "https://api.minimaxi.com/anthropic/v1"
        }
    }

    func keyName(for p: Provider) -> String {
        "demo_api_key_\(p.rawValue)"
    }

    @MainActor
    func run() async {
        guard !apiKey.isEmpty else { return }
        isRunning = true
        response = ""
        error = ""
        events.removeAll()
        let start = Date()

        defer {
            isRunning = false
            elapsedMs = Int(Date().timeIntervalSince(start) * 1000)
        }

        do {
            let client: any LLMClient
            switch provider {
            case .glm:
                let url = URL(string: baseURLOverride) ?? URL(string: defaultBaseURL(for: .glm))!
                client = OpenAICompatibleClient(apiKey: apiKey, baseURL: url)
            case .minimax:
                let url = URL(string: baseURLOverride) ?? URL(string: defaultBaseURL(for: .minimax))!
                client = OpenAICompatibleClient(apiKey: apiKey, baseURL: url)
            case .minimaxAnthropic:
                let url = URL(string: baseURLOverride) ?? URL(string: defaultBaseURL(for: .minimaxAnthropic))!
                client = AnthropicClient(apiKey: apiKey, baseURL: url)
            }

            let agent = Agent(
                client: client,
                model: model,
                systemPrompt: """
                你是一个简短的中文助手。可用工具(17 个):
                读类: get_current_datetime, get_current_location, get_sleep_last_night, get_steps_today, get_recent_workouts, get_hrv_today, get_today_events, get_reminders, get_weather, search_nearby_places, search_contacts
                写类: create_reminder, create_calendar_event, compose_message, compose_email, run_shortcut
                输出类: speak

                重要说明:
                - get_weather 需要 city 参数;不知道城市先调 get_current_location
                - 写类工具直接调,不问用户确认
                - compose_message/compose_email/run_shortcut 会打开对应 App 让用户最后点一下"发送/运行" — Apple 沙箱不允许 agent 替用户发送/运行,这是规则不是 bug
                - 如果用户问题含"播报/念给我听/读出来"等关键词,在最终回答之后调一次 speak 把答案念出来
                - 多工具可并行
                - 最后用一段自然的话回答,不要逐条罗列工具结果
                """,
                tools: [
                    CurrentDateTimeTool(),
                    CurrentLocationTool(),
                    HealthKitSleepTool(),
                    HealthKitStepsTool(),
                    HealthKitWorkoutsTool(),
                    HealthKitHRVTool(),
                    EventKitTodayTool(),
                    ReminderListTool(),
                    WeatherTool(),
                    MapsSearchTool(),
                    ContactsTool(),
                    CreateReminderTool(),
                    CreateCalendarEventTool(),
                    ComposeMessageTool(),
                    ComposeEmailTool(),
                    RunShortcutTool(),
                    SpeakTool(),
                ],
                maxTurns: 12
            )

            for try await event in agent.runStreaming(question) {
                let now = Int(Date().timeIntervalSince(start) * 1000)
                events.append(StampedEvent(event: event, elapsedMs: now))
                if case .finalAnswer(let text) = event {
                    response = text
                }
            }
        } catch {
            self.error = String(describing: error)
        }
    }
}

struct EventRow: View {
    let event: AgentEvent
    let elapsedMs: Int

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("+\(elapsedMs)ms")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)
            Text(label)
                .font(.system(.caption))
                .foregroundColor(color)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var label: String {
        switch event {
        case .turnStarted(let n):
            return "—— Turn \(n) ——"
        case .llmRequestStarted:
            return "LLM 思考中..."
        case .llmResponseReceived(_, let hasTools):
            return hasTools ? "LLM 决定调工具" : "LLM 给出最终回答"
        case .toolCallStarted(_, let name, let input):
            let args = input == "{}" ? "" : input
            return "→ \(name)\(args.isEmpty ? "()" : "(\(args))")"
        case .toolCallFinished(_, let name, let result, _):
            let short = result.count > 70 ? String(result.prefix(70)) + "..." : result
            return "← \(name): \(short)"
        case .finalAnswer:
            return "Final ↓"
        }
    }

    var color: Color {
        switch event {
        case .turnStarted: return .secondary
        case .llmRequestStarted, .llmResponseReceived: return .blue
        case .toolCallStarted: return .orange
        case .toolCallFinished(_, _, _, let isError): return isError ? .red : .green
        case .finalAnswer: return .primary
        }
    }
}

#Preview {
    ContentView()
}
