#if canImport(CoreLocation) && os(iOS)
import Foundation
import CoreLocation

/// One-shot async wrapper around `CLLocationManager.requestLocation()` with a
/// hard timeout so an empty/uncalibrated simulator location doesn't hang the
/// agent loop forever.
///
/// Internal helper used by tools that need the user's current location
/// (`CurrentLocationTool`, `MapsSearchTool`).
@MainActor
final class OneShotLocationFetcher: NSObject, CLLocationManagerDelegate {
    enum FetchError: LocalizedError {
        case timeout(seconds: Double)
        case alreadyFetching
        var errorDescription: String? {
            switch self {
            case .timeout(let s):
                return "Location fix timed out after \(String(format: "%.1f", s))s. On device: confirm Location Services and this app's permission are enabled. On Simulator: Features → Location → pick something other than None."
            case .alreadyFetching:
                return "A location request is already in progress."
            }
        }
    }

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?
    private var timeoutTask: Task<Void, Never>?
    private var debugLogging = false

    deinit {
        timeoutTask?.cancel()
    }

    func fetch(timeout: TimeInterval = 30.0, debugLogging: Bool = false) async throws -> CLLocation {
        self.debugLogging = debugLogging
        log("fetch start timeout=\(String(format: "%.1f", timeout))s mainThread=\(Thread.isMainThread) servicesEnabled=\(CLLocationManager.locationServicesEnabled()) auth=\(Self.describe(manager.authorizationStatus)) accuracyAuth=\(Self.describe(manager.accuracyAuthorization))")

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { cont in
                guard continuation == nil else {
                    cont.resume(throwing: FetchError.alreadyFetching)
                    return
                }

                continuation = cont
                manager.delegate = self
                manager.desiredAccuracy = kCLLocationAccuracyKilometer
                manager.distanceFilter = kCLDistanceFilterNone
                log("requestLocation desiredAccuracy=\(manager.desiredAccuracy)")
                manager.requestLocation()

                timeoutTask?.cancel()
                timeoutTask = Task { [weak self] in
                    let nanoseconds = UInt64(timeout * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: nanoseconds)
                    await self?.finish(.failure(FetchError.timeout(seconds: timeout)), reason: "timeout")
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.finish(.failure(CancellationError()), reason: "cancelled")
            }
        }
    }

    private func finish(_ result: Result<CLLocation, Error>, reason: String) {
        timeoutTask?.cancel()
        timeoutTask = nil
        let cont = continuation
        continuation = nil
        manager.delegate = nil
        guard let cont else {
            log("finish ignored reason=\(reason) result=\(Self.describe(result))")
            return
        }
        log("finish reason=\(reason) result=\(Self.describe(result))")
        switch result {
        case .success(let loc): cont.resume(returning: loc)
        case .failure(let err): cont.resume(throwing: err)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        log("didUpdateLocations count=\(locations.count) \(locations.map(Self.describe).joined(separator: " | "))")
        guard let loc = locations.last else { return }
        finish(.success(loc), reason: "didUpdateLocations")
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        log("didFailWithError \(Self.describe(error))")
        finish(.failure(error), reason: "didFailWithError")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        log("authorization changed auth=\(Self.describe(manager.authorizationStatus)) accuracyAuth=\(Self.describe(manager.accuracyAuthorization))")
    }

    private func log(_ message: @autoclosure () -> String) {
        AgentDebug.log("CoreLocation \(message())", enabled: debugLogging)
    }

    private static func describe(_ result: Result<CLLocation, Error>) -> String {
        switch result {
        case .success(let location):
            return describe(location)
        case .failure(let error):
            return describe(error)
        }
    }

    private static func describe(_ location: CLLocation) -> String {
        let age = -location.timestamp.timeIntervalSinceNow
        return String(
            format: "lat=%.6f lon=%.6f hAcc=%.1fm vAcc=%.1fm age=%.1fs",
            location.coordinate.latitude,
            location.coordinate.longitude,
            location.horizontalAccuracy,
            location.verticalAccuracy,
            age
        )
    }

    private static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        return "\(nsError.domain)(\(nsError.code)): \(nsError.localizedDescription)"
    }

    private static func describe(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorizedAlways: return "authorizedAlways"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        @unknown default: return "unknown(\(status.rawValue))"
        }
    }

    private static func describe(_ authorization: CLAccuracyAuthorization) -> String {
        switch authorization {
        case .fullAccuracy: return "fullAccuracy"
        case .reducedAccuracy: return "reducedAccuracy"
        @unknown default: return "unknown"
        }
    }
}
#endif
