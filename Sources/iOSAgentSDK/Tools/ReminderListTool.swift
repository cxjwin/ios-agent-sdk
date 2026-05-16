import Foundation
#if canImport(EventKit)
import EventKit
#endif

public struct ReminderListTool: ToolProtocol {
    public let name = "get_reminders"
    public let description = "Returns all incomplete reminders from the user's Reminders app via EventKit. No input required."

    public var inputSchema: [String: Any] {
        ["type": "object", "properties": [:]]
    }

    public init() {}

    public func execute(input: [String: Any]) async throws -> String {
        #if canImport(EventKit) && os(iOS)
        let store = EKEventStore()

        let granted: Bool
        if #available(iOS 17, *) {
            granted = try await store.requestFullAccessToReminders()
        } else {
            granted = try await withCheckedThrowingContinuation { cont in
                store.requestAccess(to: .reminder) { ok, err in
                    if let err {
                        cont.resume(throwing: err)
                    } else {
                        cont.resume(returning: ok)
                    }
                }
            }
        }
        guard granted else {
            return "Reminders access not granted."
        }

        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )

        let reminders: [EKReminder] = await withCheckedContinuation { cont in
            store.fetchReminders(matching: predicate) { reminders in
                cont.resume(returning: reminders ?? [])
            }
        }

        if reminders.isEmpty {
            return "No incomplete reminders."
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")

        let lines = reminders.prefix(20).map { r -> String in
            var line = "• \(r.title ?? "(无标题)")"
            if let comps = r.dueDateComponents,
               let due = Calendar.current.date(from: comps) {
                line += " — due \(formatter.string(from: due))"
            }
            return line
        }

        var output = "Incomplete reminders (\(reminders.count)):\n" + lines.joined(separator: "\n")
        if reminders.count > 20 {
            output += "\n(+\(reminders.count - 20) more)"
        }
        return output
        #else
        return "EventKit not available. Mock:\n• 给妈妈打电话 — due today 15:00\n• 买牛奶"
        #endif
    }
}
