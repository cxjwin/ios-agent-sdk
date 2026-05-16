import Foundation
#if canImport(CoreLocation)
import CoreLocation
#endif

public struct CurrentLocationTool: ToolProtocol {
    public let name = "get_current_location"
    public let description = "Returns the user's current city and country via CoreLocation + reverse geocoding. No input required."

    public var inputSchema: [String: Any] {
        ["type": "object", "properties": [:]]
    }

    public init() {}

    public func execute(input: [String: Any]) async throws -> String {
        #if canImport(CoreLocation) && os(iOS)
        let manager = CLLocationManager()
        let status = manager.authorizationStatus

        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            return "Location permission has been requested — please grant in the dialog and ask again."
        case .denied, .restricted:
            return "Location permission denied. Enable in Settings → Privacy → Location Services."
        case .authorizedAlways, .authorizedWhenInUse:
            break
        @unknown default:
            return "Unknown location authorization status."
        }

        let location = try await OneShotLocationFetcher().fetch()
        let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
        let placemark = placemarks.first
        let city = placemark?.locality ?? placemark?.administrativeArea ?? "Unknown"
        let country = placemark?.country ?? ""

        return """
        Current location: \(city), \(country)
        (lat \(String(format: "%.4f", location.coordinate.latitude)), lon \(String(format: "%.4f", location.coordinate.longitude)))
        """
        #else
        return "CoreLocation not available. Mock: Shenzhen, China (lat 22.5455, lon 114.0683)"
        #endif
    }
}

// OneShotLocationFetcher moved to Helpers/OneShotLocationFetcher.swift (now shared).
