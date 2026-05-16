import Foundation

public struct OpenAICompatibleClient: LLMClient {
    public let apiKey: String
    public let baseURL: URL
    public let urlSession: URLSession

    public init(
        apiKey: String,
        baseURL: URL,
        urlSession: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.urlSession = urlSession
    }

    public static func glm(apiKey: String) -> OpenAICompatibleClient {
        OpenAICompatibleClient(
            apiKey: apiKey,
            baseURL: URL(string: "https://open.bigmodel.cn/api/paas/v4")!
        )
    }

    public static func minimax(apiKey: String) -> OpenAICompatibleClient {
        OpenAICompatibleClient(
            apiKey: apiKey,
            baseURL: URL(string: "https://api.minimax.io/v1")!
        )
    }

    public func sendMessage(
        model: String,
        messages: [[String: Any]],
        maxTokens: Int,
        system: String?,
        tools: [[String: Any]]?
    ) async throws -> [String: Any] {
        var openAIMessages: [[String: Any]] = []
        if let system, !system.isEmpty {
            openAIMessages.append(["role": "system", "content": system])
        }
        for msg in messages {
            openAIMessages.append(contentsOf: convertMessageToOpenAI(msg))
        }

        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": openAIMessages,
        ]

        if let tools, !tools.isEmpty {
            body["tools"] = tools.map { tool -> [String: Any] in
                [
                    "type": "function",
                    "function": [
                        "name": tool["name"] ?? "",
                        "description": tool["description"] ?? "",
                        "parameters": tool["input_schema"] ?? [:],
                    ],
                ]
            }
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AgentError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? "<no body>"
            throw AgentError.httpError(status: http.statusCode, body: text)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AgentError.invalidResponse
        }
        return convertResponseToAnthropic(json)
    }

    private func convertMessageToOpenAI(_ msg: [String: Any]) -> [[String: Any]] {
        guard let role = msg["role"] as? String else { return [] }
        let content = msg["content"]

        if let stringContent = content as? String {
            return [["role": role, "content": stringContent]]
        }

        guard let blocks = content as? [[String: Any]] else {
            return [["role": role, "content": ""]]
        }

        if role == "user" {
            var results: [[String: Any]] = []
            var textParts: [String] = []
            for block in blocks {
                let type = block["type"] as? String
                if type == "tool_result" {
                    let id = block["tool_use_id"] as? String ?? ""
                    let resultContent = block["content"] as? String ?? ""
                    results.append([
                        "role": "tool",
                        "tool_call_id": id,
                        "content": resultContent,
                    ])
                } else if type == "text", let text = block["text"] as? String {
                    textParts.append(text)
                }
            }
            if !textParts.isEmpty {
                results.insert(
                    ["role": "user", "content": textParts.joined(separator: "\n")],
                    at: 0
                )
            }
            return results
        }

        if role == "assistant" {
            var textParts: [String] = []
            var toolCalls: [[String: Any]] = []
            for block in blocks {
                let type = block["type"] as? String
                if type == "text", let text = block["text"] as? String {
                    textParts.append(text)
                } else if type == "tool_use" {
                    let id = block["id"] as? String ?? ""
                    let name = block["name"] as? String ?? ""
                    let input = block["input"] ?? [:]
                    let argsJSON: String
                    if let data = try? JSONSerialization.data(withJSONObject: input),
                       let s = String(data: data, encoding: .utf8) {
                        argsJSON = s
                    } else {
                        argsJSON = "{}"
                    }
                    toolCalls.append([
                        "id": id,
                        "type": "function",
                        "function": [
                            "name": name,
                            "arguments": argsJSON,
                        ],
                    ])
                }
            }
            var result: [String: Any] = [
                "role": "assistant",
                "content": textParts.isEmpty ? "" : textParts.joined(separator: "\n"),
            ]
            if !toolCalls.isEmpty {
                result["tool_calls"] = toolCalls
            }
            return [result]
        }

        return [["role": role, "content": ""]]
    }

    private func convertResponseToAnthropic(_ resp: [String: Any]) -> [String: Any] {
        guard let choices = resp["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any]
        else {
            return ["content": [], "stop_reason": "end_turn"]
        }

        var contentBlocks: [[String: Any]] = []

        if let text = message["content"] as? String, !text.isEmpty {
            contentBlocks.append(["type": "text", "text": text])
        }

        var hasToolCalls = false
        if let toolCalls = message["tool_calls"] as? [[String: Any]] {
            for call in toolCalls {
                guard let id = call["id"] as? String,
                      let function = call["function"] as? [String: Any],
                      let name = function["name"] as? String
                else { continue }
                let argsString = function["arguments"] as? String ?? "{}"
                let argsData = argsString.data(using: .utf8) ?? Data()
                let input = (try? JSONSerialization.jsonObject(with: argsData)) as? [String: Any] ?? [:]
                contentBlocks.append([
                    "type": "tool_use",
                    "id": id,
                    "name": name,
                    "input": input,
                ])
                hasToolCalls = true
            }
        }

        return [
            "content": contentBlocks,
            "stop_reason": hasToolCalls ? "tool_use" : "end_turn",
        ]
    }
}
