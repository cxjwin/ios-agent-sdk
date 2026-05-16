# 候选标题

A. 《我用 343 行 Swift 重写了 30000 行的 Open Agent SDK,只为让它跑在 iPhone 上》
B. 《什么是 agent: 从被媳妇问倒,到在 iPhone 上重写一个》
C. 《Claude iOS 不让我做的事,我用 343 行 Swift 自己做了》
D. 《30 行 Python、343 行 Swift、30000 行 SDK: 一个 agent 的三种身材》
E. 《Anthropic 在 iOS 上做了个不错的 Agent,但它把你锁死在三个维度 — 所以我自己写了一个》
F. 《Agent 不复杂,是 Claude Code 太重 — 我给 iPhone 写了个瘦版》

(改 1 后我偏向 C 或 D。C 数字 + 反锁定一起,适合 X 引流;D 三段式数字读起来最抓眼,适合长文标题。E 太长但角度最准。)

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

"那我挪一个" — 我心里想。然后我突然反应过来一件事。

## 等等 — 我先查一下 Anthropic 自己在 iOS 上做了啥

Claude 自己就有 iOS app。如果 Anthropic 已经在那个 app 里把 agent 这事儿干了,我现在动手就是重造轮子。

我打开 [它官方支持页面](https://support.claude.com/en/articles/11869619-using-claude-with-ios-apps) (2026-03-16 发布),逐字读完。**Claude iOS App 已经能做的事**:

| App | 能力 | 实现方式 | 限制 |
|---|---|---|---|
| Calendar | 读 + 写 | 直接调 EventKit | 全 plan 可用 |
| Reminders | 读 + 创建 item | 直接调用 | 全 plan 可用 |
| Mail | 写(草稿) | **走系统 Share Sheet** | 全 plan 可用 |
| Messages | 写 | **走系统 Share Sheet** | 全 plan 可用 |
| Maps | 读 | 直接调用 | 全 plan 可用 |
| Location | 读 | 直接调用 | Team/Enterprise 不行 |
| Health | **只读** | 直接调 HealthKit | **🇺🇸 US-only + Pro/Max only + Beta** |
| Gmail / Outlook / WhatsApp / Slack / Signal | 写 | Share Sheet | 全 plan |

外加 **Siri Shortcuts** 触发、远程 **MCP** 客户端、Pro/Max 的 **Cowork** 持久 agent thread。

我看完有 30 秒在想要不要放弃这个项目。Anthropic 在 iOS 上做得比我想象的多得多。

后来我做了一件事 — 列了张表,**Anthropic 不让我做的事**。这张表救了项目。

## 我列的"Anthropic 锁定"清单

| 锁定维度 | 内容 | 我的 SDK 能解决吗 |
|---|---|---|
| **#1 工具集封闭** | 你能用的工具是 Anthropic 给你的清单。**没有"自己写个 Swift native tool 接进去"这条路** | ✅ 我的 SDK 让你定义任意 `ToolProtocol`,3 行就能加一个工具 |
| **#2 Provider 封闭** | 只能用 Claude,**GLM / MiniMax / 本地 FoundationModels 一律切不了** | ✅ 我实测跑通了 3 家(下面有真输出) |
| **#3 地区封闭(局部)** | Health 集成美国限定,**中国大陆用户根本进不去** | ✅ 我用国产 LLM 的国内端点,HealthKit 工具自己写,不受美国限定 |
| **#4 Share Sheet 限制** | 写邮件、发消息要点系统 Share Sheet 那最后一下 — **不是真自动** | ❌ **Apple 沙箱也卡死我**,这点诚实承认 |

前三个我能搞定。第四个 Apple 也卡死我,**但这是诚实博客的钩子,不是缺陷** — Apple 沙箱里的"半自动 agent"本身就是个值得讲的话题,所有 iOS agent(包括 Anthropic 自己的)都受这个限制。

所以这个项目继续写有意义。**它不是"iOS 上没有 agent"的填空,它是 "Anthropic 已经做了一个 agent,但锁定太严,你想要别的选项 → 自己写"**。

特别说明: 你是**中国开发者**、或想接**公司内部数据**、或想做**混合 provider 实验** — Claude iOS 直接帮不到你。

## 为什么选 Open Agent SDK Swift 来下刀

Swift 圈里现在主要这几个 agent SDK:

| 项目 | star | 定位 | 平台 |
|---|---|---|---|
| `SwiftedMind/SwiftAgent` | 203 | Apple FoundationModels 风格 | iOS/macOS |
| `1amageek/SwiftAgent` | 86 | type-safe declarative + MCP | iOS/macOS |
| `fumito-ito/AgentSDK-Swift` | 36 | OpenAI Agents SDK 移植 | iOS/macOS |
| `terryso/open-agent-sdk-swift` | 13 | **claude-agent-sdk 的 Swift 平替** | macOS-only |

最少 star 的那个反而是我要的:

1. **它最像 Claude Agent SDK**。我每天用 CC,这个 SDK 的概念模型跟我的 mental model 几乎重合 — 学习成本最低。
2. **它有完整的特性面**。Subagent / Hook / Skill / MCP / Permission / Plan mode / TodoWrite / Session / Worktree / Cron... 一个不少。我能看到 Anthropic 那套思想**在 Swift 里完整长出来**长什么样。
3. **它是 macOS-only**,正好给我一个明确的工程目标 — 移到 iOS。**这个 port 本身就是博客内容**。

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
| **FoundationModelsClient (新加)** | 留(v1) | iOS 26+ 系统本地模型,免费、隐私、断网可用 |
| Subagent / Team / Mailbox / Registry | 砍 | 一台手机不需要多 agent 协作 |
| Hooks / Skills 模板系统 | 暂砍 | 留 protocol 占位,v1 再加 |
| Git context / Project document discovery | 砍 | 手机上没有源码工程的概念 |
| Session memory / auto-compact | 砍 | v0 直接 truncate |
| Permission modes (5 种) | 砍(收成 1 种) | 用户即开发者,危险操作弹一下确认 |
| TodoWrite / Plan / Worktree / Cron / LSP | 全砍 | CC 终端语境产物 |
| MCP client | 暂砍 | 想接 v1 加,前期 native tool 够用 |
| **iOS 原生工具货架(新加)** | 留 | HealthKit / EventKit / WeatherKit / PhotoKit / CoreLocation / AppIntents — 这是 iOS agent 的护城河 |

## 估的 1500 行,实测 343 行

砍完之后我估了 1500 行。**实际跑通 v0 用了 343 行 SDK 本体**。

| 模块 | 估算 | 实测 |
|---|---|---|
| `Agent.swift` | ~300 | **78** |
| `LLMClient.swift` (protocol) | ~30 | 11 |
| `AnthropicClient.swift` | ~150 | 53 |
| `OpenAICompatibleClient.swift` | ~200 | 174 |
| `ToolExecutor.swift` | ~80 | 67 |
| `ToolProtocol.swift` | ~100 | 22 |
| `AgentError.swift` | (没估) | 24 |
| `HealthKitSleepTool.swift` | ~120 | 92 |
| `HealthKitStepsTool.swift` | (没估) | 57 |
| **SDK 本体小计** | ~860 | **578** |
| Examples (mock + real CLI) | (没估) | 150 |
| SwiftUI demo app | ~200 | 165 |
| **总计** | **~1500** | **~893** |

**实测比估算少 40%**。两个原因:
1. Swift `actor` 把 thread safety 抹掉了,不用手写锁
2. `[String: Any]` 偷懒,没做强类型 `Codable` — 这是技术债,v1 还要还

**Open Agent SDK 30000+ 行 → 我 343 行 (核心 SDK,去掉 examples)。87 倍瘦身**。当然功能也少了 — 但本质都在,**三个 provider 全跑通,工具调用全 work**。

## 核心 loop 长什么样

我把 Agent class 的本质抽出来,**这就是全部**:

```swift
public actor Agent {
    public let model: String
    public let systemPrompt: String?
    public let maxTurns: Int
    public let maxTokens: Int
    let client: any LLMClient
    let tools: [any ToolProtocol]
    private var messages: [[String: Any]] = []

    public func run(_ userInput: String) async throws -> String {
        messages.append(["role": "user", "content": userInput])
        let apiTools = tools.isEmpty ? nil : tools.map { $0.toAPIFormat() }

        for _ in 0..<maxTurns {
            try Task.checkCancellation()

            let response = try await client.sendMessage(
                model: model,
                messages: messages,
                maxTokens: maxTokens,
                system: systemPrompt,
                tools: apiTools
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

**你跟你媳妇解释 agent 时讲的那个"while 循环",就长这样**。Python 那 30 行、Swift 这 ~50 行、Open Agent SDK 那 3000 行,**都是同一个东西**,只是封装层数不同。

## 三家 LLM 实测对比

跑通 v0 之后,我用同一个 prompt + 同一份 HealthKit mock 数据 (7h12m / 1h05m deep / 1h40m REM),三种 provider 各跑一次:

| 配置 | 模型 | 响应(截图见配图) |
|---|---|---|
| **GLM (OpenAI 协议)** | glm-4.6 (订阅 coding plan) | "昨晚你总共睡了7小时12分钟,其中深睡1小时5分钟、REM睡眠1小时40分钟,睡眠时间还算充足。" |
| **MiniMax (OpenAI 协议)** | MiniMax-M2 (订阅 coding plan) | `<think>...思考过程...</think>` 接 "昨晚你睡得还不错!总睡眠时长为7小时12分..." |
| **MiniMax (Anthropic 协议)** | MiniMax-M2 | "你昨晚睡得不错,总共睡了7小时12分钟,其中深度睡眠1小时5分钟,REM睡眠1小时40分钟,睡眠结构比较健康。" |

三个发现值得写:

**1. AnthropicClient 一行没改就跑了 MiniMax**

我写了一个干净的 `AnthropicClient`(53 行 URLSession + JSON),然后**只把 baseURL 从 `api.anthropic.com` 改成 `api.minimaxi.com/anthropic/v1`,就把 MiniMax 跑起来了**。`LLMClient` protocol 抽象成立。这是个 5 分钟可验证的实证,比任何"理论上 provider-portable"的话都有力。

**2. Anthropic 协议设计优于 OpenAI 协议的一个可截图证据**

看上表中间那行 — MiniMax 在 OpenAI 协议下把 `<think>` 思考过程塞进 `message.content` 字段,污染最终输出。在 Anthropic 协议下,thinking 被单独分离到 content block,输出干净。**这不是"理论上更好",是可截图的具体对比**,博客里直接放。

**3. 国产 LLM 厂家比 Anthropic 对开发者更慷慨**

GLM 和 MiniMax 都允许订阅 key 直接调 API,subscription quota 直接覆盖 SDK 调用。**Anthropic Max 不支持这个** — Agent SDK 必须用单独充值的 API key。一个反共识的小事实,值得单写一段。

## iOS 端独有的工具货架

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

| 源 | 强项 | 计费 |
|---|---|---|
| Anthropic Claude (API) | 综合最强,tool use 设计最干净 | 按 token,Max 订阅**不补贴 API** |
| GLM (智谱) | 中文好,coding plan 订阅划算 | 按 token / 订阅 |
| MiniMax | 同时支持 Anthropic 协议和 OpenAI 协议 | 按 token / 订阅 |
| **FoundationModels** (iOS 26+) | 免费、离线、隐私 | 0 元 |

我的策略:
- **路由层简单 query 走 FoundationModels** — 用户问"今天几号"这种,根本不用上网
- **复杂推理走 Claude** — 工具调用复杂的场景,Claude 最稳(但我目前没 Anthropic key,这块等加)
- **GLM / MiniMax 作为日常备选** — 我已经实测两家都能干活,而且订阅 key 比 token 便宜得多

**这一段本身可以单独成一篇博客**: 《Claude vs GLM vs MiniMax vs FoundationModels: 同一个 agent task,我跑了 100 次》。

## 一个反直觉的发现: Max 订阅不能直接用

我以为我每月 $100 的 Max 订阅能覆盖这些 API 调用。**不能**。

| | 走 Max 订阅? |
|---|---|
| Claude Code CLI 本身 | 是 |
| Claude Agent SDK (Python/TS) | **不是,必须 API key** |
| URLSession 直打 API | 必须 API key |

社区在追这个 feature(`anthropics/claude-agent-sdk-python` issue #559),但截至我写这篇博客时还没实现。

**唯一让 Max 配额覆盖程序化场景的姿势**,是让程序 `subprocess` 起 `claude` CLI 当 agent runtime:

```python
import subprocess, json
result = subprocess.run(
    ["claude", "-p", "读 README,生成 PR 描述", "--output-format", "json"],
    capture_output=True, text=True
)
output = json.loads(result.stdout)
```

CLI 用你的登录态,**API 一分钱不花**。但 iPhone 上跑不了 `claude` CLI 二进制。所以 iOS agent 想 0 API 花费,只有两条路:

1. **Mac mini 后端**: 在家放台 Mac mini 24/7 开 CC,iPhone 通过 HTTPS / Tailscale 调用。Mac mini 烧 Max 配额,API 0 元。
2. **iOS 26 FoundationModels 兜底**: 简单 query 走本地,复杂的再上 API。

GLM 和 MiniMax 这边**反而不存在这个问题** — 它们的订阅 key 直接是 API key,直接调。

## 一定会踩的坑(写出来给后来人看)

1. **API key 不能塞进 App bundle**。反编译就漏。两条路: 后端代 proxy / 让用户自己粘 key 进设置。我选后者 — 既诚实又教育用户。
2. **HealthKit / Calendar / Photos 都要 Info.plist usage description**。最坑的是 Xcode 15+ 之后 Info.plist 不再是独立文件,埋在 Target → Info → Custom iOS Target Properties 里 — 我自己 demo 一启动就因为这个崩了一次。
3. **HealthKit 权限按数据类型分别授权**。Sleep 和 Steps 是两次不同的弹窗 — 这跟 web agent 的"一把梭"权限完全不同。
4. **后台跑 agent 受限**。`BGAppRefreshTask` 一天就那么几次机会,每次最多 30 秒。"用户主动唤起 + 定时通知拉回来"是最稳的模式。
5. **流式响应** (`stream: true`,用 `URLSession.bytes` 解 SSE) 体验差好几个数量级。v0 没做,v1 必须加。
6. **错误处理不要省**。API 会返 `overloaded` / `rate_limit`,网络会断,工具会 throw。把这些都 funnel 进 `tool_result` 让模型自己看到 — 它会自动重试或换路子。这个特性第一次见会觉得"它真的会动脑"。
7. **三家 LLM 的 tool calling 字段不通用**。GLM = OpenAI 复刻,arguments 是 JSON 字符串要 parse;MiniMax 双协议都支持;Claude 用 `input_schema` 而不是 `parameters`。**我在 `LLMClient` protocol 那层抹平,上面看不到**。
8. **Apple 沙箱跳不出**。即使是我们这个 SDK,真的"写邮件 / 发消息"也必须走 iOS 系统 Share Sheet — **用户点最后一下"发送"**。这跟 Claude 官方 iOS app **本质受同一个限制**。真正"全自动" agent 在 iOS 沙箱里不存在。这是博客里值得诚实说的一点。

## App Intents 是个被低估的杀招

我打算把每个 tool **同时实现成一个 App Intent**。

后果是: **Siri 和 Shortcuts 立刻就能调我的工具**。然后我的 agent loop 还可以**反过来调别的 App 暴露的 App Intent** — 我的 agent 一下接进了 iOS 全生态。

这一步不做,我的 agent 只是个 App 里的功能。做了,**它就是 iOS 的一只手**。

## v0 实测进度(2026-05-11 写到这里时)

- ✅ **核心 loop**: 3 个 mock smoke test 全过(end_turn 短路 / tool_use 回环 / maxTurns 兜底)
- ✅ **三个 provider 实测**: GLM、MiniMax OpenAI、MiniMax Anthropic 全部端到端打通,实调真 API
- ✅ **两个 HealthKit 工具**: sleep + steps,iOS Simulator 上跑通(权限按需弹、没数据时友好降级)
- ✅ **SwiftUI demo app**: Provider 切换、API key 存 UserDefaults、响应时间显示、错误展示
- ✅ **代码量实测**: SDK 本体 343 行,加上 demo 总共约 893 行

v0 之后,大概这样:
- **v1**: 流式响应(SSE) — 第一字延迟从 3s 降到 300ms
- **v2**: 接 FoundationModels (iOS 26+) 做混合路由,简单 query 走本地 0 成本
- **v3**: App Intents 桥接,所有 tool 既是 agent tool 也是 Shortcut Action
- **v4**: Mac mini 后端模式,subprocess 起 `claude` CLI,把 Max 配额吃满
- **v5**: 接我的 X 创作者数据 CSV,做个"今日选题助手"

每一步都能拆一篇博客。

## 这件事的元意义

我意识到,**写这个 SDK 本身就是 agent 概念的最佳教学材料**。

中文圈现在讲 agent 的文章,要么是产品经理视角("agent 会重塑所有工作"),要么是论文综述("ReAct、CoT、Reflexion..."),**真正"打开看代码 50 行就是个 agent"的中文长文,几乎没有**。

我决定这个项目同时是三件事:

1. **一个能用的 iOS Agent SDK**(实物,343 行)
2. **一系列博客**(每个阶段拆一篇)
3. **一个"什么是 agent"的可读教材**(代码本身就是说明)

我老婆下次再问什么是 agent,我可以打开 GitHub 把代码给她看 — 不用解释,她也能看出"哦,就是个 while 循环加一堆工具"。

---

## 写作 TODO(自留)

- [ ] 标题最终选哪个 — 我倾向 C 或 D,有数字 + 有锁定角度。E 太长但准
- [ ] "四个锁定" 那张表能不能改成段落 — 现在全文表格已经偏多
- [ ] **真截图**: iOS demo 三种 provider 各跑一次的 UI 截图,横排放对比 — 这是博客 #1 视觉
- [ ] **代码量对比海报**: 30000 行 → 343 行,87 倍瘦身,做成单图视觉冲击
- [ ] App Intents 那段还没真做,要么标"v3 计划",要么独立成另一篇
- [ ] Share Sheet 那一点 (#8 坑) 可以拎出来单独成节,它是反锁定#4 的延续,有分量
- [ ] 结尾"元意义"那段保留 — 真代码出来后这段有底气了,因为有实物撑着
- [ ] **校准测试**: 写完后给媳妇读一遍,看她能不能复述出来 agent 是什么。这就是这篇的"人味校准"

## 改 1 变更纪要(给自己看)

- 新增 "Claude iOS 已经做了哪些" 表 + "四个锁定" 表 → 把项目从"无人区填空"重新定位成"反 Anthropic 锁定"
- 1500 行估算 → 343 行实测(SDK 本体),加上代码量实测表
- 新增 "三家 LLM 实测对比" 整节(含 `<think>` 泄漏的可截图证据)
- 坑列表加第 8 条 "Apple 沙箱 / Share Sheet"
- v0 进度 → 改成 ✅ 实测清单
- 候选标题加了反锁定角度的 C 和 E
- 删了"模型策略"里"我有 Anthropic key"的假设 — 实际我目前没有,只有 Max 订阅
