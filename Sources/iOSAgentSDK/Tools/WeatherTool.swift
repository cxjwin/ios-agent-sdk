import Foundation

/// Gets current weather using open-meteo.com (free, no API key, no entitlement).
///
/// Why not WeatherKit: WeatherKit requires Apple Developer Program enrollment and
/// proper entitlement / Service ID configuration. open-meteo works out of the box,
/// runs on Simulator without setup, and gives the agent a useful answer fast.
public struct WeatherTool: ToolProtocol {
    public let name = "get_weather"
    public let description = "Get current weather for a city. Input: 'city' (English/pinyin works best, e.g., 'Shenzhen', 'Beijing', 'Tokyo'). Returns temperature, humidity, wind, and description."

    public var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "city": [
                    "type": "string",
                    "description": "City name in English or pinyin, e.g., 'Shenzhen', 'Beijing'.",
                ],
            ],
            "required": ["city"],
        ]
    }

    public init() {}

    public func execute(input: [String: Any]) async throws -> String {
        let city = (input["city"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !city.isEmpty else {
            return "Missing 'city' parameter."
        }

        // 1) Geocode the city name → latitude/longitude
        let geoQuery = city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? city
        let geoURL = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(geoQuery)&count=1&language=en&format=json")!

        let (geoData, _) = try await URLSession.shared.data(from: geoURL)
        guard let geoJSON = try JSONSerialization.jsonObject(with: geoData) as? [String: Any],
              let results = geoJSON["results"] as? [[String: Any]],
              let first = results.first,
              let lat = first["latitude"] as? Double,
              let lon = first["longitude"] as? Double
        else {
            return "City not found: \(city)"
        }
        let displayName = (first["name"] as? String) ?? city
        let country = (first["country"] as? String) ?? ""

        // 2) Fetch current weather at those coordinates
        let weatherURL = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m&timezone=auto")!

        let (weatherData, _) = try await URLSession.shared.data(from: weatherURL)
        guard let weatherJSON = try JSONSerialization.jsonObject(with: weatherData) as? [String: Any],
              let current = weatherJSON["current"] as? [String: Any]
        else {
            return "Weather data unavailable for \(displayName)"
        }

        let temp = current["temperature_2m"] as? Double ?? 0
        let humidity = current["relative_humidity_2m"] as? Double ?? 0
        let windSpeed = current["wind_speed_10m"] as? Double ?? 0
        let code = current["weather_code"] as? Int ?? 0
        let description = weatherCodeDescription(code)

        return """
        \(displayName), \(country):
        \(description), \(String(format: "%.1f", temp))°C, humidity \(Int(humidity))%, wind \(String(format: "%.1f", windSpeed)) km/h
        """
    }

    /// open-meteo WMO weather codes → human-readable.
    /// https://open-meteo.com/en/docs#weather_variable_documentation
    private func weatherCodeDescription(_ code: Int) -> String {
        switch code {
        case 0: return "Clear sky"
        case 1...3: return "Partly cloudy"
        case 45, 48: return "Foggy"
        case 51...57: return "Drizzle"
        case 61...67: return "Rain"
        case 71...77: return "Snow"
        case 80...82: return "Rain showers"
        case 85, 86: return "Snow showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm with hail"
        default: return "Unknown (code \(code))"
        }
    }
}
