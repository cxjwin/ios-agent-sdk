# 候选标题

A. 《我用 1500 行 Swift 重写了 30000 行的 Open Agent SDK,只为让它跑在 iPhone 上》
B. 《什么是 agent: 从被媳妇问倒,到在 iPhone 上重写一个》
C. 《iOS 上为什么没人写 Agent SDK,我决定自己动手 — 砍掉 95% 之后剩下的本质》
D. 《30 行 Python、80 行 Swift、30000 行 Swift SDK: 一个 agent 的三种身材》
E. 《Agent 不复杂,是 Claude Code 太重 — 我给 iPhone 写了个瘦版》

(我偏向 B 或 D,人味更重。B 适合放在 X 引流,D 适合放在长文标题。)

---

# 正文

## 开场: 一个让我语塞的下午

今天我媳妇问我:"什么是 agent? 你不是说你搭过 agent 吗?"

我一时语塞。

我天天用 Claude Code,知道它是个 agent。我写过 Skill、配过 hook、编排过 subagent,要说"搭过"也勉强算。但当一个**完全不写代码的人**站在你面前,问你这玩意儿到底是个啥 — 我发现自己根本说不出一句让她能复述给闺蜜的话。

后来我跟 Claude 聊了一下午,绕了一圈,**我把概念压成了一句**:

> Agent 就是个 while 循环,大模型在循环里自己决定下一步调啥工具,我大概 30 行 Python 就能搓一个。

然后再补一个不需要代码的比喻:

> 你让助理"订周五的拉面"。聊天机器人会说"这几家不错,你打电话问问"。Agent 会真的打开 App、查空位、订好、把确认发给你。**区别就一个: 嘴上说 vs 真动手做**。

她"哦"了一下。算是过关。

但**我自己**不甘心。我意识到我天天用 agent,却没真正写过一个 — Claude Code 帮我把一切都封装好了。30 行 Python 我也能糊出来,但那玩意儿玩具级。真正"工程化"的 agent 长什么样? Anthropic 自己的 Claude Agent SDK 摆在那儿,但 Swift 没有官方版,而我是个 iOS 开发者。

于是我去 GitHub 翻了一下午。结果挺有意思: **Mac 上的开源 agent 项目一抓一大把,iOS 上几乎没有**。能找到的几个 Swift Agent SDK,清一色 `platforms: [.macOS(.v14)]` — 没人愿意往 iPhone 上挪。

我决定挪一个。

## 为什么选 Open Agent SDK Swift 来下刀

Swift 圈里现在主要这几个 agent SDK:

| 项目 | star | 定位 | 平台 |
|---|---|---|---|
| `SwiftedMind/SwiftAgent` | 203 | Apple FoundationModels 风格 | iOS/macOS |
| `1amageek/SwiftAgent` | 86 | type-safe declarative + MCP | iOS/macOS |
| `fumito-ito/AgentSDK-Swift` | 36 | OpenAI Agents SDK 移植 | iOS/macOS |
| `terryso/open-agent-sdk-swift` | 13 | **claude-agent-sdk 的 Swift 平替** | macOS-only |

最少 star 的那个反而是我要的。原因:

1. **它最像 Claude Agent SDK**。我每天用 CC,这个 SDK 的概念模型跟我的 mental model 几乎重合 — 学习成本最低。
2. **它有完整的特性面**。Subagent / Hook / Skill / MCP / Permission / Plan mode / TodoWrite / Session / Worktree / Cron... 一个不少。这意味着我能看到 Anthropic 那套思想**在 Swift 里完整长出来**长什么样。
3. **它是 macOS-only,正好给我一个明确的工程目标** — 移到 iOS。这个 port 本身就是博客内容。

至于其他三个,我后面会单独看看,**但 v0 我只跟这一个较劲**。

## SDK 的真实结构

clone 下来,数了数,**30000+ 行 Swift**,29 个 example target。光主文件 `Agent.swift` 一个就 118KB。

我以为这是"太多了",仔细读完发现 — **核心其实只有三层**,剩下全是 Claude Code 的特性复刻。

```
┌─────────────────────────────────────────────────┐
│  Agent.swift (118KB)                            │
│  ├ 主循环 (这是核心,约 300 行)                  │
│  ├ session memory / git context / 项目发现       │ ← CC 终端语境的产物
│  ├ subagent / team / mailbox / registry         │ ← 多 agent 编排
│  ├ skills / hooks / TodoWrite / Plan / Worktree │ ← CC 内置特性
│  └ Permission / Model switching / Interrupt     │ ← UX 控制
└─────────────────────────────────────────────────┘
        │ protocol 抽象
        ▼
┌─────────────────────────────────────────────────┐
│  LLMClient (protocol, 30 行)                    │
│  ├ AnthropicClient   (8KB)                      │
│  └ OpenAIClient      (22KB - 多在做格式转换)    │
└─────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────┐
│  ToolExecutor (enum / stateless, 20KB)          │
│  └ 提取 tool_use → 分 read-only/mutation        │
│    → 并发或串行执行 → 组 tool_result            │
└─────────────────────────────────────────────────┘
```

**本质就这三件套**: 主循环 + LLM 客户端 + 工具调度器。其他一切都是包在外面的增量功能。

## 砍掉什么、留下什么

我列了张表,问自己: **iPhone 上的 agent 真的需要这个吗?**

| 模块 | 留 / 砍 | 理由 |
|---|---|---|
| 核心 agent loop | 留 | 这就是 agent 本身 |
| `ToolProtocol` + `ToolExecutor` | 留(简化) | 工具协议必须有 |
| `LLMClient` protocol + 多 provider | 留 | 我手里有 Claude + GLM + MiniMax 三套 key,要切换 |
| **FoundationModelsClient (新加)** | 留 | iOS 26+ 系统本地模型,免费、隐私、断网可用 — 这是 iOS 独有的杀手锏 |
| Subagent / Team / Mailbox / Registry | 砍 | 一台手机不需要多 agent 协作,内存也吃不消 |
| Hooks | 暂砍 | v1 再说,留个 protocol 占位 |
| Skills 模板系统 | 暂砍 | v1 再说 |
| Git context / Project document discovery | 砍 | 手机上没有源码工程的概念 |
| Session memory / auto-compact | 砍 | v0 直接 truncate,简单到底 |
| Permission modes (5 种) | 砍(收成 1 种) | 用户即开发者,无需复杂权限,危险操作弹一下确认就够 |
| TodoWrite / Plan mode / Worktree / Cron / LSP | 全砍 | 全是终端语境产物 |
| MCP client | 暂砍 | 想接的话 v1 加,前期 native tool 够用 |
| **iOS 原生工具货架 (新加)** | 留 | HealthKit / EventKit / WeatherKit / PhotoKit / CoreLocation / Contacts / AppIntents — 这才是 iOS 端 agent 的护城河 |

砍完之后,我估的代码量:

| 模块 | 行数预估 |
|---|---|
| `Agent.swift` | ~300 (vs 原版 ~3000) |
| `LLMClient.swift` (protocol) | ~30 |
| `AnthropicClient.swift` | ~150 |
| `OpenAIClient.swift` (含格式转换) | ~200 |
| `FoundationModelsClient.swift` (iOS 26 系统 API) | ~80 |
| `ToolExecutor.swift` (砍掉权限/restriction stack) | ~80 |
| `ToolProtocol.swift` + Types | ~100 |
| `Tools/HealthKitTool.swift` | ~120 |
| `Tools/EventKitTool.swift` | ~80 |
| `Tools/WeatherKitTool.swift` | ~50 |
| `Tools/CoreLocationTool.swift` | ~50 |
| `Tools/AppIntentBridge.swift` | ~100 |
| 示例 App (SwiftUI) | ~200 |
| **总计** | **约 1500 行** |

**1500 行 vs 30000+ 行,20 倍瘦身**。当然不是说原版冗余,而是 — **CC 在终端用的那一整套特性,在 iPhone 上 90% 用不上**。

## 核心 loop 长什么样

我在原版里把 Agent class 的本质抽出来,大概是这样的 80 行:

```swift
public actor Agent {
    let client: any LLMClient
    let model: String
    let systemPrompt: String?
    let maxTurns: Int
    let tools: [any ToolProtocol]
    private var messages: [[String: Any]] = []

    public func run(_ userInput: String) async throws -> String {
        messages.append(["role": "user", "content": userInput])
        let apiTools = tools.map { $0.toAPIFormat() }

        for _ in 0..<maxTurns {
            try Task.checkCancellation()

            let response = try await client.sendMessage(
                model: model,
                messages: messages,
                maxTokens: 4096,
                system: systemPrompt,
                tools: apiTools,
                toolChoice: nil,
                thinking: nil,
                temperature: nil
            )
            let content = response["content"] as? [[String: Any]] ?? []
            let stopReason = response["stop_reason"] as? String ?? ""

            messages.append(["role": "assistant", "content": content])

            if stopReason == "end_turn" {
                return content.compactMap { $0["text"] as? String }.joined(separator: "\n")
            }

            let blocks = ToolExecutor.extractToolUseBlocks(from: content)
            let results = await ToolExecutor.execute(blocks: blocks, tools: tools)
            messages.append(["role": "user", "content": results.map { $0.toAPIFormat() }])
        }
        throw AgentError.maxTurnsExceeded
    }
}
```

**你跟你媳妇解释 agent 时讲的那个"while 循环",就长这样**。Python 那 30 行、Swift 这 80 行、Open Agent SDK 那 3000 行,**都是同一个东西**,只是封装层数不同。

## iOS 端独有的工具货架(这才是值钱的地方)

CC 在终端里再强,也读不到我昨晚 HRV 数据。**而 iPhone 能**。

iOS 端 agent 的真正价值不在于"能跑 Claude",而在于它**离用户数据最近**:

| 框架 | 能给 agent 的能力 |
|---|---|
| HealthKit | 睡眠、HRV、步数、心率、训练、月经 — 全套健康数据 |
| EventKit | 读写日历、提醒事项 |
| WeatherKit | Apple 自家天气 |
| CoreLocation | "我现在在哪" + 地理围栏触发 |
| Contacts | 通讯录查询 |
| PhotoKit + Vision | 相册搜索、图片内容理解 |
| **App Intents** | 调用任意 Shortcut、控制别的 App |
| SwiftData / CoreData | 读 App 自己的数据 |
| Speech + AVFoundation | 语音输入 + 语音播报 |
| MapKit | 路线、附近搜索 |
| BackgroundTasks | agent 定时自己醒来跑一遍 |
| **FoundationModels** (iOS 26+) | 系统自带本地 LLM,免费、离线、隐私 |

最后那个 `FoundationModels` 是杀器,我会单独留一章讲。

## 模型怎么选(我的策略)

我手里有四个推理源,各打各的算盘:

| 源 | 强项 | 计费 | iOS 调用 |
|---|---|---|---|
| Anthropic Claude (API) | 综合最强,tool use 设计最干净 | 按 token,Max 订阅**不补贴 API** | URLSession 直打 |
| GLM (智谱) | 中文好,价格低 | 按 token,极便宜 | OpenAI 兼容,改 base_url |
| MiniMax | 同时支持 Anthropic 协议和 OpenAI 协议(推荐前者) | 按 token | 跟 Claude 几乎同构 |
| **FoundationModels** (iOS 26+) | 免费、离线、隐私 | 0 元 | 系统 API |

我的策略:

- **路由层简单 query 走 FoundationModels** — 用户问"今天几号"这种,根本不用上网
- **复杂推理走 Claude** — 工具调用复杂的场景,Claude 最稳
- **GLM / MiniMax 作为成本备选** — 当 Claude 跑得太贵或 rate limit 时切过去
- **跑了之后做对比** — 同一个 agent task,四家分别要多少钱、多快、多稳。这块数据中文圈基本空白,做出来就是独家。

**这一段本身可以单独成一篇博客**: 《Claude vs GLM vs MiniMax vs FoundationModels: 同一个 agent task,我跑了 100 次》。

## 一个反直觉的发现: Max 订阅不能直接用

我以为我每月 $100 的 Max 订阅能覆盖这些 API 调用。**不能**。

| | 走 Max 订阅? |
|---|---|
| Claude Code CLI 本身 | 是 |
| Claude Agent SDK (Python/TS) | **不是,必须 API key** |
| URLSession 直打 API | 必须 API key |

社区在追这个 feature(`anthropics/claude-agent-sdk-python` issue #559),但截至我写这篇博客时还没实现。

**唯一让 Max 配额覆盖程序化场景的姿势**,是让你的程序 `subprocess` 起 `claude` CLI 当 agent runtime:

```python
import subprocess, json
result = subprocess.run(
    ["claude", "-p", "读 README,生成 PR 描述", "--output-format", "json"],
    capture_output=True, text=True
)
output = json.loads(result.stdout)
```

CLI 用你的登录态,计入 Max 5h 滚动窗口,**API 一分钱不花**。

但 iPhone 上跑不了 `claude` CLI 二进制。所以 iOS agent 想 0 API 花费,只有两条路:

1. **Mac mini 后端**: 在家放台 Mac mini 24/7 开 CC,iPhone 通过 HTTPS / Tailscale 调用。Mac mini 烧 Max 配额,API 0 元。
2. **iOS 26 FoundationModels 兜底**: 简单 query 走本地,复杂的再上 API(或者上面那台 Mac mini)。

我决定 v0 先**不省这个钱**,直接 console.anthropic.com 充 $20,把 demo 跑通。开发期 $20 撑很久,等到日用量上去再迁。

## 一定会踩的坑(写出来给后来人看)

1. **API key 不能塞进 App bundle**。反编译就漏。两条路: 后端代 proxy / 用户自己粘 key 进设置。我选后者 — 既诚实又教育用户。
2. **HealthKit / Calendar / Photos 都要 Info.plist usage description**。权限请求写进 tool dispatch 函数,**别在 App 启动时一次性全申请** — 审核会觉得权限过宽。
3. **后台跑 agent 受限**。`BGAppRefreshTask` 一天就那么几次机会,每次最多 30 秒。"用户主动唤起 + 定时通知拉回来"是最稳的模式,别幻想真正的后台 agent。
4. **流式响应** (`stream: true`,用 `URLSession.bytes` 解 SSE) 体验差很多个数量级。v0 可以不做,跑通后必须加。
5. **错误处理不要省**。API 会返 `overloaded` / `rate_limit`,网络会断,工具会 throw。把这些都 funnel 进 `tool_result` 让模型自己看到 — 它会自动重试或换路子。这个特性第一次见会觉得"它真的会动脑"。
6. **三家 LLM 的 tool calling 字段不通用**。GLM = OpenAI 复刻,arguments 是 JSON 字符串要 parse;MiniMax 同时支持两套;Claude 用 input_schema 而不是 parameters。**我在 LLMClient protocol 那层抹平,上面看不到**。

## App Intents 是个被低估的杀招

我打算把每个 tool **同时实现成一个 App Intent**。

后果是: **Siri 和 Shortcuts 立刻就能调我的工具**。然后我的 agent loop 还可以**反过来调别的 App 暴露的 App Intent** — 我的 agent 一下接进了 iOS 全生态。

这一步不做,我的 agent 只是个 App 里的功能。做了,它就是 iOS 的一只手。

## v0 之后,我想干什么

v0 目标: **iPhone 上跑通一个能读 HealthKit + 日历 + 天气的 "晨间助理 agent",语音播报**。这个 demo 足以发一篇博客和一条推。

v0 之后,大概这样:

- v1: 接 FoundationModels 做混合路由,简单 query 0 成本
- v2: App Intents 桥接全打通,所有 tool 既是 agent tool 也是 Shortcut Action
- v3: 接我的 X 创作者数据 CSV,做个"今日选题助手"
- v4: Mac mini 后端模式,把 Max 配额吃满

每一步都能拆一篇博客。

## 这件事的元意义

我意识到,**写这个 SDK 本身就是 agent 概念的最佳教学材料**。

中文圈现在讲 agent 的文章,要么是产品经理视角("agent 会重塑所有工作"),要么是论文综述("ReAct、CoT、Reflexion..."),**真正"打开看代码 30 行就是个 agent"的中文长文,几乎没有**。

我决定这个项目同时是三件事:

1. **一个能用的 iOS Agent SDK**(实物)
2. **一系列博客**(每个阶段拆一篇)
3. **一个"什么是 agent"的可读教材**(代码本身就是说明)

我老婆下次再问什么是 agent,我可以打开 GitHub 把代码给她看 — 不用解释,她也能看出"哦,就是个 while 循环加一堆工具"。

---

## 写作 TODO(自留)

- [ ] 删掉一些表格,改成段落叙述 — 现在表格密度太高,"人味"被压低
- [ ] 开场那一段"媳妇问 agent"再打磨一下,现在有点干
- [ ] 模型成本对比那一节做完真实测试再补数据,否则空
- [ ] App Intents 那段要不要单独成文? 现在它在这里有点突兀
- [ ] 加几张图: 30 行 Python / 80 行 Swift / 30000 行 SDK 的"代码量对比海报",视觉冲击力强
- [ ] 配图: HealthKit 工具实际跑起来的截图(等代码写完)
- [ ] 标题最终选哪个: 我倾向 D《30 行 Python、80 行 Swift、30000 行 Swift SDK: 一个 agent 的三种身材》 — 数字三段式,中文里很抓眼
- [ ] 结尾"元意义"那段,要么砍掉(显得装),要么再凝练一下变成钩子句
