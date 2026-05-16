import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

public struct HealthKitHRVTool: ToolProtocol {
    public let name = "get_hrv_today"
    public let description = "Returns today's heart rate variability (HRV SDNN, in milliseconds) from HealthKit. HRV is a key stress/recovery indicator — generally, higher = better-recovered. No input required."

    public var inputSchema: [String: Any] {
        ["type": "object", "properties": [:]]
    }

    public init() {}

    public func execute(input: [String: Any]) async throws -> String {
        #if canImport(HealthKit) && os(iOS)
        let store = HKHealthStore()
        guard HKHealthStore.isHealthDataAvailable() else {
            return "HealthKit not available."
        }
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return "HRV type unavailable."
        }
        try await store.requestAuthorization(toShare: [], read: [hrvType])

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfToday,
            end: Date(),
            options: []
        )

        let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { cont in
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                cont.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            store.execute(query)
        }

        if samples.isEmpty {
            return "No HRV data recorded today. (On Simulator, add data in Settings → Health → Heart → Heart Rate Variability.)"
        }

        let unit = HKUnit.secondUnit(with: .milli)
        let values = samples.map { $0.quantity.doubleValue(for: unit) }
        let avg = values.reduce(0, +) / Double(values.count)
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 0

        return """
        HRV today: \(samples.count) sample(s)
        Average: \(String(format: "%.1f", avg)) ms
        Range: \(String(format: "%.1f", minVal))–\(String(format: "%.1f", maxVal)) ms
        """
        #else
        return "HealthKit not available. Mock HRV today: avg 42.3 ms (range 35–55)."
        #endif
    }
}
