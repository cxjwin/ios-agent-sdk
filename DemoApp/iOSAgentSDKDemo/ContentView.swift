import SwiftUI
import UIKit
import CoreLocation
import iOSAgentSDK

struct StampedEvent: Identifiable {
    let id = UUID()
    let event: AgentEvent
    let elapsedMs: Int
}

enum Provider: String, CaseIterable, Identifiable {
    case glm = "GLM"
    case minimax = "MiniMax (OpenAI)"
    case minimaxAnthropic = "MiniMax (Anthropic)"
    var id: String { rawValue }
}

struct PromptSample: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let toolHints: [String]
    let prompt: String
}

let promptSamples: [PromptSample] = [
    PromptSample(
        id: "morning",
        title: "晨间播报",
        icon: "sun.max.fill",
        toolHints: ["睡眠", "日程", "天气", "步数", "提醒", "朗读"],
        prompt: "给我做个晨间播报: 我昨晚睡得怎么样、今天日程多不多、当前位置天气如何、要不要多走几步。顺便记一下下午3点给妈妈打电话,并把答案念出来。"
    ),
    PromptSample(
        id: "coffee",
        title: "附近找咖啡",
        icon: "cup.and.saucer.fill",
        toolHints: ["定位", "地图", "天气"],
        prompt: "我现在想喝杯咖啡,帮我找附近的咖啡店,顺便说下要不要带伞。"
    ),
    PromptSample(
        id: "workout",
        title: "运动总结",
        icon: "figure.run",
        toolHints: ["运动", "HRV", "步数", "朗读"],
        prompt: "总结一下我最近的运动情况:近期都做了哪些运动、今天的 HRV 和步数怎么样,用一段话念给我听。"
    ),
    PromptSample(
        id: "email",
        title: "写封邮件",
        icon: "envelope.fill",
        toolHints: ["通讯录", "邮件"],
        prompt: "帮我给联系人里叫\"张三\"的人写一封邮件,主题是\"周会改时间\",内容简短地说明本周会议改到周四下午3点。"
    ),
    PromptSample(
        id: "message",
        title: "发条短信",
        icon: "message.fill",
        toolHints: ["通讯录", "短信"],
        prompt: "帮我给妈妈发条短信,内容是\"今晚回家吃饭\"。"
    ),
    PromptSample(
        id: "writeNote",
        title: "写笔记到沙箱",
        icon: "square.and.pencil",
        toolHints: ["日程", "写文件"],
        prompt: "把我今天的日程总结成 markdown,写到沙箱 documents 下的 today.md。"
    ),
    PromptSample(
        id: "readNote",
        title: "读沙箱笔记",
        icon: "doc.text.magnifyingglass",
        toolHints: ["读文件"],
        prompt: "读一下 documents 下的 today.md,告诉我里面写了啥。"
    ),
    PromptSample(
        id: "calendar",
        title: "创建日历事件",
        icon: "calendar.badge.plus",
        toolHints: ["日历"],
        prompt: "明天下午2点到3点帮我加一个日历事件,标题是\"产品评审\"。"
    ),
    PromptSample(
        id: "shortcut",
        title: "跑捷径",
        icon: "bolt.fill",
        toolHints: ["快捷指令"],
        prompt: "运行一个叫\"播放音乐\"的捷径。"
    ),
    PromptSample(
        id: "now",
        title: "现在几点",
        icon: "clock.fill",
        toolHints: ["时间"],
        prompt: "现在是几点几分,星期几?"
    ),
]

struct ContentView: View {
    @AppStorage("demo_provider") private var providerRaw: String = Provider.glm.rawValue
    @State private var apiKey: String = ""
    @State private var baseURLOverride: String = ""
    @State private var model: String = ""

    @State private var selectedSampleId: String = promptSamples.first!.id
    @State private var question: String = promptSamples.first!.prompt

    @State private var response: String = ""
    @State private var error: String = ""
    @State private var isRunning: Bool = false
    @State private var elapsedMs: Int = 0
    @State private var events: [StampedEvent] = []

    @State private var showSettings: Bool = false
    @State private var showDebug: Bool = false

    private var provider: Provider {
        Provider(rawValue: providerRaw) ?? .glm
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Prompt 样例") {
                    PromptSampleCarousel(
                        samples: promptSamples,
                        selectedId: $selectedSampleId,
                        onSelect: { sample in
                            question = sample.prompt
                        }
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section("Question") {
                    TextField("问题", text: $question, axis: .vertical)
                        .lineLimit(2...6)
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
                    if apiKey.isEmpty {
                        Text("先去右上角 ⚙ 设置 API Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
            .navigationTitle("iOS Agent")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showDebug = true
                    } label: {
                        Image(systemName: "wrench.and.screwdriver")
                    }
                    .accessibilityLabel("Debug")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(
                    provider: Binding(
                        get: { provider },
                        set: { providerRaw = $0.rawValue }
                    ),
                    apiKey: $apiKey,
                    model: $model,
                    baseURLOverride: $baseURLOverride
                )
            }
            .sheet(isPresented: $showDebug) {
                DebugView()
            }
            .onAppear {
                hydrate(for: provider)
            }
            .onChange(of: providerRaw) { _, _ in
                hydrate(for: provider)
            }
        }
    }

    private func hydrate(for p: Provider) {
        model = defaultModel(for: p)
        baseURLOverride = defaultBaseURL(for: p)
        apiKey = UserDefaults.standard.string(forKey: keyName(for: p)) ?? ""
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
                client = OpenAICompatibleClient(apiKey: apiKey, baseURL: url, debugLogging: true)
            case .minimax:
                let url = URL(string: baseURLOverride) ?? URL(string: defaultBaseURL(for: .minimax))!
                client = OpenAICompatibleClient(apiKey: apiKey, baseURL: url, debugLogging: true)
            case .minimaxAnthropic:
                let url = URL(string: baseURLOverride) ?? URL(string: defaultBaseURL(for: .minimaxAnthropic))!
                client = AnthropicClient(apiKey: apiKey, baseURL: url, debugLogging: true)
            }

            let agent = Agent(
                client: client,
                model: model,
                systemPrompt: """
                你是一个简短的中文助手。可用工具(19 个):
                读类: get_current_datetime, get_current_location, get_sleep_last_night, get_steps_today, get_recent_workouts, get_hrv_today, get_today_events, get_reminders, get_weather, search_nearby_places, search_contacts, read_sandbox_file
                写类: create_reminder, create_calendar_event, compose_message, compose_email, run_shortcut, write_sandbox_file
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
                    CurrentLocationTool(debugLogging: true),
                    HealthKitSleepTool(),
                    HealthKitStepsTool(),
                    HealthKitWorkoutsTool(),
                    HealthKitHRVTool(),
                    EventKitTodayTool(),
                    ReminderListTool(),
                    WeatherTool(),
                    MapsSearchTool(debugLogging: true),
                    ContactsTool(),
                    CreateReminderTool(),
                    CreateCalendarEventTool(),
                    ComposeMessageTool(),
                    ComposeEmailTool(),
                    RunShortcutTool(),
                    SpeakTool(),
                    ReadSandboxFileTool(),
                    WriteSandboxFileTool(),
                ],
                maxTurns: 12,
                debugLogging: true
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

// MARK: - Debug sheet

struct DebugView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isCheckingLocation = false
    @State private var locationReport = "尚未检查"

    var body: some View {
        NavigationStack {
            Form {
                Section("Location") {
                    Button {
                        Task { await checkLocation() }
                    } label: {
                        HStack {
                            if isCheckingLocation {
                                ProgressView()
                                Text("检查中...")
                            } else {
                                Image(systemName: "location.fill")
                                Text("检查定位接口")
                            }
                        }
                    }
                    .disabled(isCheckingLocation)

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("打开系统设置", systemImage: "gearshape")
                    }

                    Text(locationReport)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            .navigationTitle("Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @MainActor
    private func checkLocation() async {
        isCheckingLocation = true
        defer { isCheckingLocation = false }

        let manager = CLLocationManager()
        var lines: [String] = [
            "time: \(Date())",
            "locationServicesEnabled: \(CLLocationManager.locationServicesEnabled())",
            "authorizationStatus: \(describe(manager.authorizationStatus))",
            "accuracyAuthorization: \(describe(manager.accuracyAuthorization))",
            "Info.plist NSLocationWhenInUseUsageDescription: \(Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") as? String ?? "(missing)")",
        ]

        do {
            let result = try await CurrentLocationTool(debugLogging: true).execute(input: [:])
            lines.append("toolResult: success")
            lines.append(result)
        } catch {
            let nsError = error as NSError
            lines.append("toolResult: error")
            lines.append("\(nsError.domain)(\(nsError.code)): \(nsError.localizedDescription)")
        }

        locationReport = lines.joined(separator: "\n")
    }

    private func describe(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorizedAlways: return "authorizedAlways"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        @unknown default: return "unknown(\(status.rawValue))"
        }
    }

    private func describe(_ authorization: CLAccuracyAuthorization) -> String {
        switch authorization {
        case .fullAccuracy: return "fullAccuracy"
        case .reducedAccuracy: return "reducedAccuracy"
        @unknown default: return "unknown"
        }
    }
}

// MARK: - Settings sheet

struct SettingsView: View {
    @Binding var provider: Provider
    @Binding var apiKey: String
    @Binding var model: String
    @Binding var baseURLOverride: String

    @Environment(\.dismiss) private var dismiss

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
                }

                Section("Credentials") {
                    HStack(spacing: 8) {
                        SecureField("API Key", text: $apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: apiKey) { _, new in
                                UserDefaults.standard.set(new, forKey: keyName(for: provider))
                            }

                        if !apiKey.isEmpty {
                            Button {
                                apiKey = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Clear API Key")
                        }

                        PasteButton(payloadType: String.self) { strings in
                            guard let s = strings.first else { return }
                            apiKey = s.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        .labelStyle(.titleAndIcon)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                        .accessibilityLabel("Paste API Key from clipboard")
                    }
                }

                Section("Model & Endpoint") {
                    TextField("Model", text: $model)
                        .textInputAutocapitalization(.never)
                    TextField("Base URL", text: $baseURLOverride)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.caption, design: .monospaced))
                }

                Section {
                    Text("Provider 切换时,Model / Base URL 会重置到默认值,API Key 从本地存储读取。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Prompt sample carousel

struct PromptSampleCarousel: View {
    let samples: [PromptSample]
    @Binding var selectedId: String
    let onSelect: (PromptSample) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(samples) { sample in
                        PromptSampleCard(
                            sample: sample,
                            isSelected: sample.id == selectedId
                        )
                        .id(sample.id)
                        .onTapGesture {
                            selectedId = sample.id
                            onSelect(sample)
                            withAnimation(.easeInOut(duration: 0.25)) {
                                proxy.scrollTo(sample.id, anchor: .center)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .onAppear {
                proxy.scrollTo(selectedId, anchor: .center)
            }
        }
    }
}

struct PromptSampleCard: View {
    let sample: PromptSample
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: sample.icon)
                    .foregroundColor(isSelected ? .white : .accentColor)
                Text(sample.title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }

            Text(sample.prompt)
                .font(.caption)
                .foregroundColor(isSelected ? .white.opacity(0.95) : .secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                ForEach(sample.toolHints.prefix(4), id: \.self) { hint in
                    Text(hint)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            (isSelected ? Color.white.opacity(0.2) : Color.accentColor.opacity(0.12))
                        )
                        .foregroundColor(isSelected ? .white : .accentColor)
                        .clipShape(Capsule())
                }
                if sample.toolHints.count > 4 {
                    Text("+\(sample.toolHints.count - 4)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
        }
        .padding(12)
        .frame(width: 240, height: 130, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.accentColor : Color.black.opacity(0.06), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Provider helpers (file scope so settings sheet can reuse)

func defaultModel(for p: Provider) -> String {
    switch p {
    case .glm: return "glm-5.1"
    case .minimax, .minimaxAnthropic: return "MiniMax-M2.7"
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

// MARK: - Event row (unchanged)

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
