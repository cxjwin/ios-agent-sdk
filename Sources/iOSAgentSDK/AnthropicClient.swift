import Foundation

public struct AnthropicClient: LLMClient {
    public let apiKey: String
    public let baseURL: URL
    public let urlSession: URLSession
    public let debugLogging: Bool

    public init(
        apiKey: String,
        baseURL: URL = URL(string: "https://api.anthropic.com/v1")!,
        urlSession: URLSession = .shared,
        debugLogging: Bool = false
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.urlSession = urlSession
        self.debugLogging = debugLogging
    }

    public func sendMessage(
        model: String,
        messages: [[String: Any]],
        maxTokens: Int,
        system: String?,
        tools: [[String: Any]]?
    ) async throws -> [String: Any] {
        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": messages,
        ]
        if let system { body["system"] = system }
        if let tools, !tools.isEmpty { body["tools"] = tools }

        var request = URLRequest(url: baseURL.appendingPathComponent("messages"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        AgentDebug.log(
            "→ POST \(request.url?.absoluteString ?? "?") auth=x-api-key key=\(AgentDebug.mask(apiKey)) model=\(model) messages=\(messages.count) tools=\(tools?.count ?? 0) bodyBytes=\(request.httpBody?.count ?? 0)",
            enabled: debugLogging
        )

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            AgentDebug.log("← non-HTTP response", enabled: debugLogging)
            throw AgentError.invalidResponse
        }

        let bodyText = String(data: data, encoding: .utf8) ?? "<non-utf8 \(data.count) bytes>"
        AgentDebug.log(
            "← HTTP \(http.statusCode) bytes=\(data.count) body=\(AgentDebug.truncate(bodyText))",
            enabled: debugLogging
        )

        guard (200..<300).contains(http.statusCode) else {
            throw AgentError.httpError(status: http.statusCode, body: bodyText)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AgentError.invalidResponse
        }
        return json
    }
}
