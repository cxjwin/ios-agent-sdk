import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif

#if canImport(AVFoundation) && (os(iOS) || os(macOS))
/// Holds the AVSpeechSynthesizer so it survives across calls.
/// Without this, the synthesizer is deallocated when the tool function returns
/// and speech stops mid-sentence.
private final class SpeakerHolder: @unchecked Sendable {
    static let shared = SpeakerHolder()
    let synthesizer = AVSpeechSynthesizer()
}
#endif

/// Speaks text aloud via AVSpeechSynthesizer.
///
/// This is the SDK's first **output tool** — it produces a side effect (audio)
/// rather than returning data. The agent typically calls this AFTER composing
/// its final text answer, to deliver it as voice.
///
/// `isReadOnly = false` because it has user-perceptible side effects.
public struct SpeakTool: ToolProtocol {
    public let name = "speak"
    public let description = "Speaks the given text aloud via the device speaker. Use this after composing your final answer to deliver it as voice. Input: 'text' (required), 'language' (optional BCP-47 code like 'zh-CN' default, 'en-US')."

    public let isReadOnly = false

    public var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "text": [
                    "type": "string",
                    "description": "Text to speak aloud.",
                ],
                "language": [
                    "type": "string",
                    "description": "BCP-47 language code, e.g., 'zh-CN', 'en-US'. Default 'zh-CN'.",
                ],
            ],
            "required": ["text"],
        ]
    }

    public init() {}

    public func execute(input: [String: Any]) async throws -> String {
        let text = (input["text"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !text.isEmpty else {
            return "Missing 'text' parameter."
        }
        let language = (input["language"] as? String) ?? "zh-CN"

        #if canImport(AVFoundation) && (os(iOS) || os(macOS))
        // Build & enqueue the utterance on the main actor so neither it nor
        // the synthesizer crosses an actor boundary while non-Sendable.
        await MainActor.run {
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: language)
                ?? AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            SpeakerHolder.shared.synthesizer.speak(utterance)
        }
        return "Speaking \(text.count) characters in \(language)."
        #else
        return "AVFoundation not available on this platform. Mock spoke: '\(text)'"
        #endif
    }
}
