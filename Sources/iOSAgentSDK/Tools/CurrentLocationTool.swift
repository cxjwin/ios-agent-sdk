import Foundation
#if canImport(CoreLocation)
import CoreLocation
#endif

public struct CurrentLocationTool: ToolProtocol {
    public let name = "get_current_location"
    public let description = "Returns the user's current city and country via CoreLocation + reverse geocoding. No input required."
    private let debugLogging: Bool

    public var inputSchema: [String: Any] {
        ["type": "object", "properties": [:]]
    }

    public init(debugLogging: Bool = false) {
        self.debugLogging = debugLogging
    }

    public func execute(input: [String: Any]) async throws -> String {
        #if canImport(CoreLocation) && os(iOS)
        let manager = CLLocationManager()
        let status = manager.authorizationStatus
        AgentDebug.log("get_current_location start servicesEnabled=\(CLLocationManager.locationServicesEnabled()) auth=\(status.rawValue) accuracyAuth=\(manager.accuracyAuthorization.rawValue)", enabled: debugLogging)

        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            AgentDebug.log("get_current_location requested WhenInUse authorization", enabled: debugLogging)
            return "Location permission has been requested — please grant in the dialog and ask again."
        case .denied, .restricted:
            AgentDebug.log("get_current_location blocked auth=\(status.rawValue)", enabled: debugLogging)
            return "Location permission denied. Enable in Settings → Privacy → Location Services."
        case .authorizedAlways, .authorizedWhenInUse:
            break
        @unknown default:
            AgentDebug.log("get_current_location unknown auth=\(status.rawValue)", enabled: debugLogging)
            return "Unknown location authorization status."
        }

        let location = try await OneShotLocationFetcher().fetch(debugLogging: debugLogging)
        AgentDebug.log("get_current_location reverseGeocode start lat=\(location.coordinate.latitude) lon=\(location.coordinate.longitude)", enabled: debugLogging)
        let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
        AgentDebug.log("get_current_location reverseGeocode finished placemarks=\(placemarks.count)", enabled: debugLogging)
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
