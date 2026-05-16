import Foundation
#if canImport(EventKit)
import EventKit
#endif

/// Creates a new reminder in the user's default Reminders list.
///
/// **This is a write tool — `isReadOnly = false`.** Unlike the read-only tools,
/// this one mutates user state. In a permission-aware build, this is where the
/// agent loop would prompt for confirmation before executing.
public struct CreateReminderTool: ToolProtocol {
    public let name = "create_reminder"
    public let description = "Creates a new reminder in the user's default Reminders list. Input: 'title' (required) and optional 'dueDate' (ISO 8601, e.g., '2026-05-13T15:00:00+08:00'). The dueDate must be in the future — if the user gives a relative time like '今天下午3点' or 'tomorrow', call get_current_datetime first to compute the absolute date, otherwise this tool will reject the call."

    public let isReadOnly = false

    public var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "title": [
                    "type": "string",
                    "description": "Reminder title (what to remember).",
                ],
                "dueDate": [
                    "type": "string",
                    "description": "Optional due date-time in ISO 8601 format, e.g., '2026-05-13T15:00:00+08:00'.",
                ],
            ],
            "required": ["title"],
        ]
    }

    public init() {}

    public func execute(input: [String: Any]) async throws -> String {
        let title = (input["title"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !title.isEmpty else {
            return "Missing 'title' parameter."
        }
        let dueDateStr = input["dueDate"] as? String

        #if canImport(EventKit) && os(iOS)
        let store = EKEventStore()

        let granted = try await store.requestFullAccessToReminders()
        guard granted else {
            return "Reminders access not granted."
        }

        guard let defaultList = store.defaultCalendarForNewReminders() else {
            return "No default reminders list available."
        }

        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = defaultList

        var dueDescription = ""
        if let dueDateStr {
            guard let date = parseISODate(dueDateStr) else {
                return "Could not parse dueDate \"\(dueDateStr)\". Use ISO 8601, e.g., 2026-05-17T15:00:00+08:00."
            }
            let now = Date()
            // Allow up to 12h of slack so "this morning's reminder" still works.
            if date < now.addingTimeInterval(-12 * 3600) {
                let fmt = ISO8601DateFormatter()
                fmt.formatOptions = [.withInternetDateTime]
                return "Refusing to create reminder with past dueDate \(fmt.string(from: date)). Current time is \(fmt.string(from: now)). Recompute the absolute ISO 8601 date (call get_current_datetime if needed) and retry."
            }
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: date
            )
            let fmt = DateFormatter()
            fmt.dateStyle = .short
            fmt.timeStyle = .short
            fmt.locale = Locale(identifier: "zh_CN")
            dueDescription = " (due \(fmt.string(from: date)))"
        }

        try store.save(reminder, commit: true)

        return "Created reminder: \(title)\(dueDescription)"
        #else
        return "EventKit not available. Mock: created reminder '\(title)'\(dueDateStr.map { " (due \($0))" } ?? "")"
        #endif
    }

    private func parseISODate(_ s: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFraction.date(from: s) { return d }

        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: s)
    }
}
