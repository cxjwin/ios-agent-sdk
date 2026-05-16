import Foundation
#if canImport(EventKit)
import EventKit
#endif

public struct EventKitTodayTool: ToolProtocol {
    public let name = "get_today_events"
    public let description = "Returns today's calendar events via EventKit. No input required."

    public var inputSchema: [String: Any] {
        ["type": "object", "properties": [:]]
    }

    public init() {}

    public func execute(input: [String: Any]) async throws -> String {
        #if canImport(EventKit) && os(iOS)
        let store = EKEventStore()

        // iOS 17+ uses requestFullAccessToEvents (read+write).
        // For read-only we could use requestWriteOnlyAccessToEvents, but reading also needs full.
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
        guard granted else {
            return "Calendar access not granted."
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        guard let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
            return "Failed to compute date range."
        }

        let predicate = store.predicateForEvents(
            withStart: startOfToday,
            end: endOfToday,
            calendars: nil
        )
        let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }

        if events.isEmpty {
            return "No calendar events scheduled for today. (On Simulator, add events in Calendar app.)"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        let lines = events.map { ev -> String in
            let start = formatter.string(from: ev.startDate)
            let end = formatter.string(from: ev.endDate)
            let title = ev.title ?? "(无标题)"
            let location = (ev.location?.isEmpty == false) ? " @ \(ev.location!)" : ""
            return "\(start)–\(end): \(title)\(location)"
        }

        return "Today's events (\(events.count) total):\n" + lines.joined(separator: "\n")
        #else
        return "EventKit not available on this platform. Mock data: 10:00–11:00 团队周会; 15:30–16:30 1:1 with manager."
        #endif
    }
}
