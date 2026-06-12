import Foundation

struct Verdict: Decodable {
    let verdict: String
    let reason: String
    let detail: String
    let trivial: Bool
}

enum LLMConfig {
    private static let baseURLKey = "llm-base-url"
    private static let modelKey = "llm-model"

    static var baseURL: String {
        get { UserDefaults.standard.string(forKey: baseURLKey) ?? "https://api.openai.com/v1" }
        set { UserDefaults.standard.set(newValue, forKey: baseURLKey) }
    }

    static var model: String {
        get { UserDefaults.standard.string(forKey: modelKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: modelKey) }
    }
}

enum LLMError: LocalizedError {
    case notConfigured
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "还没有配置好模型服务，请先到设置里填入 Base URL、API Key 和模型名。"
        case .badResponse(let message): return message
        }
    }
}

struct LLMService {
    private static let systemPrompt = """
    你是「快定」，一个帮用户终结内耗的快速决策助手。用户会输入一件让他纠结的事，你的任务是直接给出可执行的结论，而不是利弊分析——分析只会给用户更多内耗的素材。

    你必须只输出一个 JSON 对象，不要输出任何其他文字、解释或 Markdown 代码块。格式：
    {"verdict": "...", "reason": "...", "detail": "...", "trivial": false}

    字段规则：
    1. verdict：不超过 8 个字的可执行动作（如「去」「不买」「选 A」「今晚就发」）。禁止「视情况而定」「都可以」这类骑墙表态。
    2. reason：一句话（30 字以内）给出最关键的一条理由，不要罗列。
    3. detail：2-4 句展开你的判断逻辑，供用户想看时再看。
    4. trivial：布尔值。如果这件事鸡毛蒜皮、怎么选结果都差不多，设为 true，verdict 直接替用户抛硬币（如「抛硬币：去」），reason 说明这事不值得纠结。
    5. 信息不足时不要追问，基于最合理的假设直接表态，假设写在 detail 里。
    """

    func decide(_ question: String, anotherAngleFrom previous: Verdict? = nil) async throws -> Verdict {
        guard let apiKey = KeychainHelper.loadAPIKey(), !apiKey.isEmpty,
              !LLMConfig.model.isEmpty,
              let endpoint = Self.chatCompletionsURL() else {
            throw LLMError.notConfigured
        }

        var userText = question
        if let previous {
            userText += "\n\n（你刚才的结论是「\(previous.verdict)」，理由是「\(previous.reason)」。用户想听一个不同的角度：重新审视后再次表态，可以坚持原结论，但理由必须换一个角度。）"
        }

        let body: [String: Any] = [
            "model": LLMConfig.model,
            "messages": [
                ["role": "system", "content": Self.systemPrompt],
                ["role": "user", "content": userText],
            ],
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LLMError.badResponse("网络异常，请重试。")
        }
        guard http.statusCode == 200 else {
            let apiMessage = (try? JSONDecoder().decode(APIErrorEnvelope.self, from: data))?.error.message
            throw LLMError.badResponse(apiMessage ?? "请求失败（HTTP \(http.statusCode)）")
        }

        let envelope = try JSONDecoder().decode(ChatCompletionEnvelope.self, from: data)
        guard let content = envelope.choices.first?.message.content,
              let jsonData = Self.extractJSON(from: content) else {
            throw LLMError.badResponse("模型响应格式异常，请重试。")
        }
        return try JSONDecoder().decode(Verdict.self, from: jsonData)
    }

    private static func chatCompletionsURL() -> URL? {
        var base = LLMConfig.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else { return nil }
        while base.hasSuffix("/") { base.removeLast() }
        return URL(string: base + "/chat/completions")
    }

    /// 模型可能把 JSON 包在 ```json 代码块里或带前后说明文字，取首尾大括号之间的内容。
    private static func extractJSON(from content: String) -> Data? {
        guard let start = content.firstIndex(of: "{"),
              let end = content.lastIndex(of: "}"),
              start <= end else { return nil }
        return String(content[start...end]).data(using: .utf8)
    }
}

private struct ChatCompletionEnvelope: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }

        let message: Message
    }

    let choices: [Choice]
}

private struct APIErrorEnvelope: Decodable {
    struct APIError: Decodable {
        let message: String
    }

    let error: APIError
}
