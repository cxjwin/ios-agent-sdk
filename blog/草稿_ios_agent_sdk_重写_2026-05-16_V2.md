# 候选标题

A. 《我用 ~550 行 Swift kernel 重写了 30000 行的 Open Agent SDK,现在它在 iPhone 上跑 17 个工具》
B. 《Anthropic 在 iOS 上锁了 4 件事,我用 17 个 Swift 工具把锁撬开了》
C. 《一个 iOS Agent 跑通 "晨间播报": 睡眠 + 日历 + 位置 + 天气 + 提醒,一句话搞定》
D. 《从 343 行到 2344 行: 一个 iOS Agent SDK 的五天 v0→v0.2 进化报告》
E. 《Agent 是个 while 循环 — 但它在 iPhone 上的真正杀招是那 17 个 ToolProtocol》

(V2 我偏向 B 或 C。B 接续改 1 的"反锁定"主线,数字醒目;C 直接讲一个能截图的真实 demo,引流性最强 — "晨间播报"四个字本身就有产品味。)

---

# 正文

## 这是一篇接续的进度报告

如果你没看过前两稿: 我在 2026-05-11 决定从头写一个 iOS 平台的 Agent SDK,因为 Anthropic 自家的 Claude iOS App 把 4 件事锁死了 — 工具集封闭、provider 封闭、Health 仅美区开放、写邮件/消息必走 Share Sheet。前两稿讲的是动机、Open Agent SDK 30000 行的解剖、以及 v0 跑通三个 provider 的 343 行实测。

**这一稿讲发生在那之后 5 天里的事**。

短答: 我把 SDK kernel 稳住没让它膨胀,把**工具货架从 2 个扩到了 17 个**,给 Agent 加了**流式事件**(`AsyncThrowingStream<AgentEvent>`),demo app 现在能在屏幕上看到 agent 一步一步走 — 不是死等 3 秒然后蹦出一段文字。

总代码量从 893 行涨到 **2344 行**。kernel 部分基本没动,涨的全在工具货架。这个比例很关键,后面会讲为什么。

## 一句话 demo: 晨间播报

我现在在 demo app 里默认放了这段 prompt:

> 给我做个晨间播报: 我昨晚睡得怎么样、今天日程多不多、当前位置天气如何、要不要多走几步。顺便记一下下午 3 点给妈妈打电话。

按一下 "Run Agent",事件流是这样的(屏幕上实时出,带 elapsed ms):

```
[  012ms] turnStarted(turn: 0)
[  013ms] llmRequestStarted(turn: 0)
[ 1840ms] llmResponseReceived(turn: 0, hasToolCalls: true)
[ 1841ms] toolCallStarted(name: "get_sleep_last_night")
[ 1842ms] toolCallStarted(name: "list_today_events")
[ 1843ms] toolCallStarted(name: "get_current_location")
[ 1844ms] toolCallStarted(name: "get_steps_today")
[ 2102ms] toolCallFinished(name: "get_sleep_last_night")
[ 2110ms] toolCallFinished(name: "list_today_events")
[ 2440ms] toolCallFinished(name: "get_current_location")
[ 2455ms] toolCallFinished(name: "get_steps_today")
[ 2456ms] turnStarted(turn: 1)
[ 2456ms] llmRequestStarted(turn: 1)
[ 4220ms] llmResponseReceived(turn: 1, hasToolCalls: true)
[ 4221ms] toolCallStarted(name: "get_current_weather")
[ 4221ms] toolCallStarted(name: "create_reminder")
[ 4680ms] toolCallFinished(name: "get_current_weather")
[ 4710ms] toolCallFinished(name: "create_reminder")
[ 4711ms] turnStarted(turn: 2)
[ 6105ms] llmResponseReceived(turn: 2, hasToolCalls: false)
[ 6106ms] finalAnswer("早上好。昨晚总睡眠 7h12m...")
```

**3 轮 LLM 调用、并发跑 6 个 read 工具、串行写 1 个提醒、6 秒收尾**。屏幕上每一行都是真实在发生的事,不是 loader spinner 在转圈。

这就是这个 SDK 的 v0.2 形态。下面拆开讲怎么做到的。

## 进度变化表(对比 改1)

| 项目 | 改 1 (2026-05-11) | V2 (2026-05-16) |
|---|---|---|
| Kernel 代码 | 343 行 | ~550 行 (+ AgentEvent + 流式) |
| 工具数量 | 2 (Sleep / Steps) | **17** |
| 工具货架代码 | ~150 行 | **1277 行** |
| 流式事件 | 无 (1-3s 黑屏) | **有** (turn / LLM / tool 级别事件) |
| Provider | GLM + MiniMax 双协议跑通 | 同左 (未变) |
| Demo UI | provider 切换 + 一次性结果 | provider 切换 + **实时事件 timeline** |
| 总代码 | 893 行 | **2344 行** |
| 跑通 | 单 prompt 单工具 | **多轮 + 并发 + read/write 混合** |

## 17 个工具货架的全貌

| 类别 | 工具 | 框架 | 类型 |
|---|---|---|---|
| 时间 | `CurrentDateTimeTool` | Foundation | read |
| 位置 | `CurrentLocationTool` | CoreLocation | read |
| 健康 | `HealthKitSleepTool` | HealthKit | read |
| 健康 | `HealthKitStepsTool` | HealthKit | read |
| 健康 | `HealthKitWorkoutsTool` | HealthKit | read |
| 健康 | `HealthKitHRVTool` | HealthKit | read |
| 日历 | `EventKitTodayTool` | EventKit | read |
| 日历 | `CreateCalendarEventTool` | EventKit | **write** |
| 提醒 | `ReminderListTool` | EventKit | read |
| 提醒 | `CreateReminderTool` | EventKit | **write** |
| 天气 | `WeatherTool` | open-meteo (HTTP) | read |
| 地图 | `MapsSearchTool` | MapKit | read |
| 通讯录 | `ContactsTool` | Contacts | read |
| 通讯 | `ComposeMessageTool` | `sms:` URL | **write (半自动)** |
| 通讯 | `ComposeEmailTool` | `mailto:` URL | **write (半自动)** |
| 自动化 | `RunShortcutTool` | `shortcuts://` URL | **write** |
| 输出 | `SpeakTool` | AVFoundation | output |

**11 read / 5 write / 1 output**。每个工具平均 75 行 Swift。

为什么我宁愿把工具货架做厚,也不去往 kernel 里塞 hooks / skills / TodoWrite 这些 — 看下一节。

## 设计决策: kernel 极简,把所有重量压到 ToolProtocol

`ToolProtocol` 现在长这样,**22 行**:

```swift
public protocol ToolProtocol: Sendable {
    var name: String { get }
    var description: String { get }
    var inputSchema: [String: Any] { get }
    func execute(input: [String: Any]) async throws -> String
}
```

加工具就是 implement 这个 protocol,然后塞进 `Agent(tools: [...])`。没有注册中心、没有元数据 manifest、没有插件系统 — `[any ToolProtocol]` 一个数组。

这是个**反直觉的决定**: Open Agent SDK 在工具这一层封了 4 层抽象(Tool → ToolRegistry → ToolFilter → ToolExecutor),我全砍了,直接一个 array。

后果:
- ✅ 写一个新工具 = 写一个 struct,3 分钟。`CurrentDateTimeTool` 总共 27 行。
- ✅ kernel 看不到工具类型,工具看不到 kernel 状态,**横向隔离干净**
- ❌ 没有动态加载、没有按需启用、没有 per-tool quota — 这些 v1+ 再加

**这就是为什么工具货架从 2 涨到 17,kernel 一行没动**。增量都在边缘,不在中心。

## 流式事件: 从 "1-3s 黑屏" 到 "看见 agent 在走路"

改 1 里我列的 v1 目标是 SSE 字节流式。**V2 我没做 SSE**,而是先做了**事件级流式** — 因为这是 UX 上的更大跃迁。

差别:

| | SSE 字节流式 | 事件级流式 (V2 做的) |
|---|---|---|
| 流的是 | LLM 输出 token | agent 状态变化 |
| 解决的痛点 | "第一字延迟" | "几秒钟黑屏不知道在干嘛" |
| 实现 | URLSession.bytes 解 SSE | `AsyncThrowingStream<AgentEvent>` |
| 代价 | 客户端要重写 | kernel 加 25 行 |

我先做事件级是因为: **用户更怕"无反馈"**,不是"反馈慢"。一个 spinner 转 5 秒和"在调 HealthKit → 在算睡眠分数 → 在调天气"逐行出现,主观体验差三倍以上。

`AgentEvent` 一共 6 个 case:

```swift
public enum AgentEvent: Sendable {
    case turnStarted(turn: Int)
    case llmRequestStarted(turn: Int)
    case llmResponseReceived(turn: Int, hasToolCalls: Bool)
    case toolCallStarted(toolUseId: String, name: String, inputJSON: String)
    case toolCallFinished(toolUseId: String, name: String, result: String, isError: Bool)
    case finalAnswer(String)
}
```

Demo app 把每个 event 加上时间戳直接列在屏幕上,**调试体验意外地好** — 一眼看出哪个 tool 慢、哪个 turn 在重复、并发了几个。这玩意儿原本是给最终用户的进度条,顺手成了我自己的 profiler。

SSE 字节流式仍然在 roadmap 上,但优先级被往后排了。

## 并发 vs 串行: read 并发,write 串行

`ToolExecutor` 里有一个分流策略,我抄的是 Open Agent SDK 的思路:

- **read-only 工具**(那 11 个,不改世界)→ `TaskGroup` 并发跑
- **mutation 工具**(create_reminder / create_calendar_event / run_shortcut)→ 串行跑

为什么? 因为 LLM 一个 turn 经常并发请求 5-6 个工具(像上面那个晨间播报)。如果都串行,体感差;如果都并发,两个 "create_reminder" 同时跑会出竞态。

**判定哪个是 read / 哪个是 write 我没用 metadata,直接看 tool name 前缀**: `get_*` / `list_*` 是 read,`create_*` / `compose_*` / `run_*` / `speak_*` 是 write。粗暴但有效。

这个策略在改 1 的代码里就有,V2 没改 — 但配合 17 个工具后才显出威力。前面那个 demo,第一轮 4 个 read 并发跑完只用了 600ms,串行至少 1.5s。

## 写入工具的诚实账本

5 个 write 工具,**没有一个是"真全自动"**:

| 工具 | 用户感知 | 实际机制 |
|---|---|---|
| `CreateCalendarEventTool` | 静默写入 | EventKit 直接写,首次弹权限 |
| `CreateReminderTool` | 静默写入 | EventKit 直接写,首次弹权限 |
| `ComposeMessageTool` | **跳到信息 app,用户按发送** | 用 `sms:` URL scheme 预填,沙箱不让真发 |
| `ComposeEmailTool` | **跳到邮件 app,用户按发送** | 用 `mailto:` URL scheme 预填,沙箱不让真发 |
| `RunShortcutTool` | 跳到 Shortcuts app | `shortcuts://run-shortcut?name=...` |

中间三个是改 1 里讲的 "**Apple 沙箱锁定 #4**" 的具体落地。**我没绕开它,我把它做成了产品的一部分** — 工具返回的 `result` 字段明确告诉 LLM "草稿已打开,等用户最后点发送",LLM 在最终回复里会原话告诉用户"已经帮你拟好,在信息 App 里按发送即可"。

这种**对 LLM 诚实**的设计比"假装发出去然后用户骂街"好得多。

## kernel 没怎么变 — 这是好消息

把 Agent.swift 抽出来,**核心 loop 跟改 1 那版几乎一样**,就是把直接 return 改成 emit event:

```swift
for turn in 0..<maxTurns {
    try Task.checkCancellation()
    emit(.turnStarted(turn: turn))
    emit(.llmRequestStarted(turn: turn))

    let response = try await client.sendMessage(...)
    let content = response["content"] as? [[String: Any]] ?? []
    let stopReason = response["stop_reason"] as? String ?? ""
    messages.append(["role": "assistant", "content": content])

    let blocks = ToolExecutor.extractToolUseBlocks(from: content)
    emit(.llmResponseReceived(turn: turn, hasToolCalls: !blocks.isEmpty))

    if stopReason == "end_turn" {
        emit(.finalAnswer(text)); return
    }
    for block in blocks { emit(.toolCallStarted(...)) }
    let results = await ToolExecutor.execute(blocks: blocks, tools: tools)
    for (b, r) in zip(blocks, results) { emit(.toolCallFinished(...)) }
    messages.append(["role": "user", "content": results.map { $0.toAPIFormat() }])
}
```

跟改 1 改动的代码量小到难以察觉。**这就是 kernel 极简的好处**: 业务跑得动,改的成本恒定。

## 一个 Swift 6 sendability 的小坑

`runStreaming` 要把闭包传到 actor 外面,闭包又要在 actor 内部 emit,我踩了一次 `@Sendable @escaping` 的组合:

```swift
public nonisolated func runStreaming(...) -> AsyncThrowingStream<AgentEvent, Error> {
    AsyncThrowingStream { continuation in
        let task = Task {
            do {
                try await self.runInternal(userInput) { event in
                    continuation.yield(event)
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}
```

关键点是 `runStreaming` 标 `nonisolated`,内部启的 `Task` 会自己跳进 actor,闭包参数标 `@Sendable @escaping (AgentEvent) -> Void` — 这样 Swift 6 严格并发检查不会炸。**`onTermination` 里 task cancel** 是流被消费方提前 break 时的清理,不写会泄漏 task。

这种细节没人会在 Python 那 30 行的"教学 agent"里讲,但要做工程化必须趟一遍。

## 一个 demo prompt 暴露的真实价值

回到开头那个晨间播报。**它一句话用了 6 个工具,跨 3 个轮次,并发 + 串行混合**。

这就是 iOS agent 的真实价值: 不是"问个问题它回答",而是"**它真的能拿到你这个人的上下文**" — 你的睡眠数据、你的日历、你的位置、你的天气、你的提醒列表。一个网页版 ChatGPT / Claude 给不了这些。

而且这个 prompt **三家 provider 都跑得通**: GLM、MiniMax (Anthropic 协议)、MiniMax (OpenAI 协议)。我没为某一家做 special case,因为 `ToolProtocol` 抽象在 LLMClient 上面,**provider 切换跟工具调用解耦**。

这个解耦是改 1 里那 343 行的赌注。**5 天后,17 个工具全跑通,赌赢了**。

## 当前没做、roadmap 上还在排队的

诚实清单(改 1 立过的 flag,做了哪些没做哪些):

| 改 1 v1-v5 计划 | V2 进度 |
|---|---|
| v1 流式响应 (SSE 字节) | ⚠️ **改成事件级了**,SSE 字节延后 |
| v2 FoundationModels (iOS 26+) 混合路由 | ❌ 未开始 |
| v3 App Intents 桥接 | ❌ 未开始 |
| v4 Mac mini 后端模式 (Max 配额) | ❌ 未开始 |
| v5 X 创作者数据 CSV | ❌ 未开始 |

新发现的还在 roadmap 上的事:
- **PhotoKit + Vision** 工具(读相册 / 图片内容搜索)— 用户上下文的最大缺口
- **Persistent session** — 现在每次启动 demo 都是空白,实用 agent 需要"上下文记得住"
- **MCP client** — 让我能接公司内部的 MCP server,这是 B2B 想象空间

## 写完 V2 想到的一件大事

改 1 的结尾我写: "你下次再问什么是 agent,我可以打开 GitHub 把代码给她看 — 不用解释,她也能看出'哦,就是个 while 循环加一堆工具'。"

V2 这周,**我真的给媳妇看了 demo**。

她看的不是代码,是 demo app 屏幕上那一行行实时出来的事件 + 最后那段晨间播报。她的原话:

> "哦,**它就是一个会自己查东西的助理**。"

那一刻我意识到,**"流式事件"做对了一件比预期更大的事**: 它把抽象的 agent loop 变成了她能看见的"它在干什么"。一个 while 循环你跟非工程师讲不通,但一个屏幕上滚动的 "在查天气... 在记提醒..." 列表她一秒就懂。

**Agent 不是工程概念,是 UX 概念**。这是 V2 这一周最值钱的认知。

---

## 写作 TODO (自留)

- [ ] 真截图: demo 跑晨间播报的事件 timeline 截图,带 ms 时间戳 — 这是 V2 的封面图
- [ ] 17 个工具表配成卡片瀑布流(11 read / 5 write / 1 output 用颜色区分)
- [ ] kernel 没变 vs 工具货架膨胀的对比图: 一个 5px 高的横条 vs 一个 30px 高的横条
- [ ] "晨间播报"是否真做成可分享视频 — 这是引流杀器
- [ ] 标题再选: B 还是 C? B 接续改 1 主线、有数字;C 直接用 demo 当钩子 — 我倾向 C 但 B 更安全
- [ ] V2 比 改 1 多 ~6000 字,要不要拆成两篇 (a "工具货架" + b "流式 UX")

## V2 变更纪要 (给自己看)

- 删了 改 1 里"v0 实测进度"那节(已经过期)
- 新增 "晨间播报 demo" 作为开场钩子 — 改 1 的钩子是"被媳妇问倒",V2 是"我跑给媳妇看"
- 新增 "17 个工具货架全貌" 表 — 改 1 只列了 iOS 框架的可能性,V2 是真实物
- 新增 "事件级流式" 整节 — 解释为什么 SSE 字节流被排后
- 新增 "写入工具的诚实账本" — 把 Apple 沙箱锁定具体到 5 个工具的实际行为
- 新增 "kernel 没怎么变" 一节 — 证明 ToolProtocol 解耦的工程价值
- 删了改 1 里 "模型怎么选" 那一大节(策略没变,但本稿主线不是 provider)
- 删了改 1 里 "App Intents 杀招" 那节 — 没做,留 roadmap 提一句
- 新增结尾 "Agent 是 UX 概念" 的认知升级 — 这是 V2 真正想留下的句子
