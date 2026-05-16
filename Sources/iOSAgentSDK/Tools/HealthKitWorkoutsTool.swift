import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

public struct HealthKitWorkoutsTool: ToolProtocol {
    public let name = "get_recent_workouts"
    public let description = "Returns workouts (running, gym, yoga, etc.) from the past N days via HealthKit. Input: optional 'days' (default 7)."

    public var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "days": [
                    "type": "integer",
                    "description": "Number of days to look back. Default 7.",
                ],
            ],
        ]
    }

    public init() {}

    public func execute(input: [String: Any]) async throws -> String {
        let days = (input["days"] as? Int) ?? 7

        #if canImport(HealthKit) && os(iOS)
        let store = HKHealthStore()
        guard HKHealthStore.isHealthDataAvailable() else {
            return "HealthKit not available on this device."
        }
        let workoutType = HKObjectType.workoutType()
        try await HealthKitAuth.requestRead(on: store)

        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: now) else {
            return "Failed to compute time range."
        }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])

        let samples: [HKWorkout] = try await withCheckedThrowingContinuation { cont in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                cont.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }

        if samples.isEmpty {
            return "No workouts in the past \(days) days. (On Simulator, add workouts in Settings → Health → Workouts.)"
        }

        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .short
        fmt.locale = Locale(identifier: "zh_CN")

        let lines = samples.prefix(10).map { w -> String in
            let typeName = workoutName(w.workoutActivityType)
            let duration = Int(w.duration / 60)
            let date = fmt.string(from: w.startDate)
            return "• \(date): \(typeName), \(duration)min"
        }

        var output = "Workouts in past \(days) days (\(samples.count) total):\n" + lines.joined(separator: "\n")
        if samples.count > 10 {
            output += "\n(+\(samples.count - 10) more)"
        }
        return output
        #else
        return "HealthKit not available on this platform. Mock: 3 runs (30min each), 1 yoga (45min)."
        #endif
    }

    #if canImport(HealthKit) && os(iOS)
    private func workoutName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "跑步"
        case .walking: return "步行"
        case .cycling: return "骑行"
        case .swimming: return "游泳"
        case .yoga: return "瑜伽"
        case .functionalStrengthTraining: return "力量训练"
        case .traditionalStrengthTraining: return "传统力量训练"
        case .hiking: return "徒步"
        case .highIntensityIntervalTraining: return "HIIT"
        case .coreTraining: return "核心训练"
        case .pilates: return "普拉提"
        case .dance: return "舞蹈"
        case .other: return "其他运动"
        default: return "运动"
        }
    }
    #endif
}
