#if canImport(HealthKit) && os(iOS)
import Foundation
import HealthKit

/// Coalesced HealthKit authorization helper.
///
/// Each of our HK tools used to call `requestAuthorization(read: [oneType])`
/// independently. When several HK tools run concurrently (the morning-briefing
/// prompt does), iOS only presents one permission sheet at a time, so the
/// other auth requests queue up — the user dismisses one, another appears,
/// and so on. From the outside it looks like the agent is stuck after the
/// first granted tool returns.
///
/// Routing every HK tool through this helper makes all concurrent auth calls
/// request the same union of types, which iOS deduplicates into a single
/// combined sheet covering sleep / steps / workouts / HRV at once.
enum HealthKitAuth {
    /// All HK read types this SDK's bundled tools touch. Order isn't significant;
    /// `requestAuthorization` takes a `Set`.
    static let allReadTypes: Set<HKObjectType> = {
        var set: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            set.insert(sleep)
        }
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) {
            set.insert(steps)
        }
        if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            set.insert(hrv)
        }
        return set
    }()

    /// Request read access to every HK type the SDK uses, on the given store.
    /// Safe to call from many concurrent tools — iOS shows one combined sheet
    /// the first time and returns immediately afterwards.
    static func requestRead(on store: HKHealthStore) async throws {
        try await store.requestAuthorization(toShare: [], read: allReadTypes)
    }
}
#endif
