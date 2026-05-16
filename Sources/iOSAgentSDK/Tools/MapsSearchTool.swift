import Foundation
#if canImport(MapKit)
import MapKit
#endif
#if canImport(CoreLocation)
import CoreLocation
#endif

/// Searches for places near the user's current location via MKLocalSearch.
///
/// Requires Location permission (it grabs current location first to define
/// the search region).
public struct MapsSearchTool: ToolProtocol {
    public let name = "search_nearby_places"
    public let description = "Search for places near the user's current location via MapKit. Input: 'query' (e.g., 'coffee', 'gym', '健身房'), optional 'limit' (max results, default 5)."

    public var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "query": [
                    "type": "string",
                    "description": "Natural language search, e.g., 'coffee shop' or '麻辣火锅'.",
                ],
                "limit": [
                    "type": "integer",
                    "description": "Maximum number of results to return. Default 5.",
                ],
            ],
            "required": ["query"],
        ]
    }

    public init() {}

    public func execute(input: [String: Any]) async throws -> String {
        let query = (input["query"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !query.isEmpty else { return "Missing 'query' parameter." }
        let limit = (input["limit"] as? Int) ?? 5

        #if canImport(MapKit) && canImport(CoreLocation) && os(iOS)
        let manager = CLLocationManager()
        let status = manager.authorizationStatus
        guard status == .authorizedAlways || status == .authorizedWhenInUse else {
            return "Location permission required. Status: \(status.rawValue)."
        }

        let location = try await OneShotLocationFetcher().fetch()

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 5000,
            longitudinalMeters: 5000
        )

        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        let items = Array(response.mapItems.prefix(limit))

        if items.isEmpty {
            return "No results for '\(query)' nearby."
        }

        let lines = items.map { item -> String in
            let distance = item.placemark.location?.distance(from: location) ?? 0
            let distanceStr = distance < 1000
                ? "\(Int(distance))m"
                : String(format: "%.1fkm", distance / 1000)
            let address = [item.placemark.thoroughfare, item.placemark.locality]
                .compactMap { $0 }
                .joined(separator: ", ")
            return "• \(item.name ?? "(unnamed)") — \(address.isEmpty ? "(no address)" : address) — \(distanceStr)"
        }

        return "Found \(items.count) results for '\(query)' near you:\n" + lines.joined(separator: "\n")
        #else
        return "MapKit not available. Mock: 3 results for '\(query)' nearby."
        #endif
    }
}
