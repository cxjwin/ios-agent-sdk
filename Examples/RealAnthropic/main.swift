import Foundation
import iOSAgentSDK

@main
struct RealLLM {
    static func main() async throws {
        let env = ProcessInfo.processInfo.environment
        let provider = (env["PROVIDER"] ?? "glm").lowercased()

        let client: any LLMClient
        let model: String
        let displayName: String

        switch provider {
        case "glm":
            guard let key = env["GLM_API_KEY"], !key.isEmpty else {
                print("Set GLM_API_KEY (and PROVIDER=glm) in env.")
                exit(1)
            }
            let baseURL = env["GLM_BASE_URL"].flatMap(URL.init(string:))
                ?? URL(string: "https://open.bigmodel.cn/api/paas/v4")!
            client = OpenAICompatibleClient(apiKey: key, baseURL: baseURL)
            model = env["MODEL"] ?? "glm-4.6"
            displayName = "GLM (OpenAI 协议) @ \(baseURL.absoluteString)"

        case "minimax", "minimax-openai":
            guard let key = env["MINIMAX_API_KEY"], !key.isEmpty else {
                print("Set MINIMAX_API_KEY (and PROVIDER=minimax) in env.")
                exit(1)
            }
            let baseURL = env["MINIMAX_BASE_URL"].flatMap(URL.init(string:))
                ?? URL(string: "https://api.minimax.io/v1")!
            client = OpenAICompatibleClient(apiKey: key, baseURL: baseURL)
            model = env["MODEL"] ?? "MiniMax-M2"
            displayName = "MiniMax (OpenAI 协议) @ \(baseURL.absoluteString)"

        case "minimax-anthropic":
            guard let key = env["MINIMAX_API_KEY"], !key.isEmpty else {
                print("Set MINIMAX_API_KEY (and PROVIDER=minimax-anthropic) in env.")
                exit(1)
            }
            let baseURL = env["MINIMAX_ANTHROPIC_BASE_URL"].flatMap(URL.init(string:))
                ?? URL(string: "https://api.minimax.io/anthropic/v1")!
            client = AnthropicClient(apiKey: key, baseURL: baseURL)
            model = env["MODEL"] ?? "MiniMax-M2"
            displayName = "MiniMax (Anthropic 协议,复用 AnthropicClient) @ \(baseURL.absoluteString)"

        case "anthropic":
            guard let key = env["ANTHROPIC_API_KEY"], !key.isEmpty else {
                print("Set ANTHROPIC_API_KEY (and PROVIDER=anthropic) in env.")
                exit(1)
            }
            client = AnthropicClient(apiKey: key)
            model = env["MODEL"] ?? "claude-opus-4-7"
            displayName = "Anthropic Claude"

        default:
            print("Unknown PROVIDER: \(provider). Use one of: glm, minimax, minimax-anthropic, anthropic.")
            exit(1)
        }

        let agent = Agent(
            client: client,
            model: model,
            systemPrompt: """
            你是一个简短的中文助手。可用工具: get_sleep_last_night / get_steps_today / get_weather (需 city 参数)。
            根据用户问题选合适的工具,用一段话回答。
            """,
            tools: [
                HealthKitSleepTool(),
                HealthKitStepsTool(),
                WeatherTool(),
            ],
            maxTurns: 5
        )

        let question = ProcessInfo.processInfo.environment["QUESTION"]
            ?? "深圳今天天气怎么样?"
        print("== \(displayName) ==")
        print("Model: \(model)")
        print("Q: \(question)")
        print("...")
        let result = try await agent.run(question)
        print("A: \(result)")
    }
}
