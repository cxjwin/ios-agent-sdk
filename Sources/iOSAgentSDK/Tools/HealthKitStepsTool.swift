import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

public struct HealthKitStepsTool: ToolProtocol {
    public let name = "get_steps_today"
    public let description = "Returns today's step count via HealthKit. No input required."

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
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return "Step count type unavailable."
        }
        try await HealthKitAuth.requestRead(on: store)

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let now = Date()

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfToday,
            end: now,
            options: .strictStartDate
        )

        let totalSteps: Double = try await withCheckedThrowingContinuation { cont in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                let sum = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                cont.resume(returning: sum)
            }
            store.execute(query)
        }

        if totalSteps == 0 {
            return "No step data recorded for today yet. (On Simulator, add sample data in Settings → Health.)"
        }

        return "Steps today: \(Int(totalSteps))"
        #else
        return "HealthKit not available on this platform. Mock data: 5,432 steps today."
        #endif
    }
}
