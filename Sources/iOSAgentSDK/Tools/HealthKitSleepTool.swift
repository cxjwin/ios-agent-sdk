import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

public struct HealthKitSleepTool: ToolProtocol {
    public let name = "get_sleep_last_night"
    public let description = "Returns last night's sleep data via HealthKit: total sleep, deep sleep, REM. No input required."

    public var inputSchema: [String: Any] {
        ["type": "object", "properties": [:]]
    }

    public init() {}

    public func execute(input: [String: Any]) async throws -> String {
        #if canImport(HealthKit) && os(iOS)
        let store = HKHealthStore()
        guard HKHealthStore.isHealthDataAvailable() else {
            return "HealthKit not available on this device."
        }
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return "Sleep type unavailable."
        }
        try await HealthKitAuth.requestRead(on: store)

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(byAdding: .hour, value: -6, to: startOfToday) else {
            return "Failed to compute time window."
        }

        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: now, options: [])

        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { cont in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                cont.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }

        if samples.isEmpty {
            return "No sleep data recorded for last night. (On Simulator, add sample data in Settings → Health.)"
        }

        var totalSeconds: TimeInterval = 0
        var deepSeconds: TimeInterval = 0
        var remSeconds: TimeInterval = 0

        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            switch sample.value {
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                 HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                totalSeconds += duration
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                totalSeconds += duration
                deepSeconds += duration
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                totalSeconds += duration
                remSeconds += duration
            default:
                break
            }
        }

        return """
        Total sleep: \(format(totalSeconds))
        Deep sleep: \(format(deepSeconds))
        REM: \(format(remSeconds))
        """
        #else
        return "HealthKit not available on this platform. Mock data: total 7h12m, deep 1h05m, REM 1h40m."
        #endif
    }

    private func format(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        return "\(h)h\(m)m"
    }
}
