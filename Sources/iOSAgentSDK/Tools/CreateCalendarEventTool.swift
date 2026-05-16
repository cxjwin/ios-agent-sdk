import Foundation
#if canImport(EventKit)
import EventKit
#endif

/// Creates a new event in the user's default calendar.
///
/// Symmetric write counterpart to `EventKitTodayTool` (read).
public struct CreateCalendarEventTool: ToolProtocol {
    public let name = "create_calendar_event"
    public let description = "Creates a new event in the user's default calendar. Required: 'title' and 'startDate' (ISO 8601). Optional: 'endDate' (defaults to start + 1 hour), 'location', 'notes'."

    public let isReadOnly = false

    public var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "title": ["type": "string", "description": "Event title."],
                "startDate": [
                    "type": "string",
                    "description": "Start date-time in ISO 8601, e.g., '2026-05-13T15:00:00+08:00'.",
                ],
                "endDate": [
                    "type": "string",
                    "description": "Optional end date-time in ISO 8601. Defaults to startDate + 1 hour.",
                ],
                "location": ["type": "string", "description": "Optional location string."],
                "notes": ["type": "string", "description": "Optional notes / description."],
            ],
            "required": ["title", "startDate"],
        ]
    }

    public init() {}

    public func execute(input: [String: Any]) async throws -> String {
        let title = (input["title"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        let startStr = (input["startDate"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !title.isEmpty else { return "Missing 'title' parameter." }
        guard !startStr.isEmpty else { return "Missing 'startDate' parameter." }

        guard let start = parseISODate(startStr) else {
            return "Invalid startDate format: '\(startStr)'. Expected ISO 8601."
        }

        let end: Date
        if let endStr = input["endDate"] as? String, let parsedEnd = parseISODate(endStr) {
            end = parsedEnd
        } else {
            end = start.addingTimeInterval(3600)
        }

        #if canImport(EventKit) && os(iOS)
        let store = EKEventStore()

        let granted: Bool
        if #available(iOS 17, *) {
            granted = try await store.requestFullAccessToEvents()
        } else {
            granted = try await withCheckedThrowingContinuation { cont in
                store.requestAccess(to: .event) { ok, err in
                    if let err {
                        cont.resume(throwing: err)
                    } else {
                        cont.resume(returning: ok)
                    }
                }
            }
        }
        guard granted else { return "Calendar access not granted." }

        guard let defaultCalendar = store.defaultCalendarForNewEvents else {
            return "No default calendar available for new events."
        }

        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = end
        event.location = input["location"] as? String
        event.notes = input["notes"] as? String
        event.calendar = defaultCalendar

        try store.save(event, span: .thisEvent)

        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .short
        fmt.locale = Locale(identifier: "zh_CN")
        return "Created event: '\(title)' on \(fmt.string(from: start)) – \(fmt.string(from: end))"
        #else
        return "EventKit not available. Mock: Created event '\(title)' starting \(startStr)"
        #endif
    }

    private func parseISODate(_ s: String) -> Date? {
        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f1.date(from: s) { return d }
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        return f2.date(from: s)
    }
}
