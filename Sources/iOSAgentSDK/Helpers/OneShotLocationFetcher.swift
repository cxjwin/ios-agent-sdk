#if canImport(CoreLocation) && os(iOS)
import Foundation
import CoreLocation

/// One-shot async wrapper around `CLLocationManager.requestLocation()`.
///
/// Internal helper used by tools that need the user's current location
/// (`CurrentLocationTool`, `MapsSearchTool`).
final class OneShotLocationFetcher: NSObject, @unchecked Sendable, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    func fetch() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyKilometer
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let cont = continuation, let loc = locations.first else { return }
        continuation = nil
        cont.resume(returning: loc)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume(throwing: error)
    }
}
#endif
