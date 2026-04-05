// WeatherService.swift
// BioNaural
//
// Protocol + concrete implementation for reading weather data via WeatherKit (iOS 16+).
// Barometric pressure is the hero metric — pressure drops correlate with mood changes,
// migraines, and reduced HRV. The service provides lightweight WeatherContext models
// for the Health view and pre-session intelligence.
// All values from Theme/config tokens. No SwiftUI imports.

import Foundation
import WeatherKit
import CoreLocation
import OSLog

// MARK: - WeatherConfig

/// Configuration constants for the weather service.
public enum WeatherConfig {

    /// Barometric pressure change (hPa) considered significant for health impact.
    static let pressureChangeDeltaThreshold: Double = 5.0

    /// Duration (minutes) before cached weather data is considered stale.
    static let cacheExpirationMinutes: Int = 30

    /// Fallback latitude when location permission is unavailable (San Francisco).
    static let defaultLatitude: Double = 37.7749

    /// Fallback longitude when location permission is unavailable (San Francisco).
    static let defaultLongitude: Double = -122.4194

    /// Maximum number of days allowed for weather history lookback.
    static let maxHistoryDays: Int = 10

    /// Fallback humidity for daily forecasts that lack per-hour humidity data.
    static let dailyForecastFallbackHumidity: Double = 0.5

    /// Fallback pressure for daily forecasts that lack pressure data.
    static let dailyForecastFallbackPressure: Double = 0

    /// Number of recent hourly forecasts used to compute pressure trend.
    static let pressureTrendHourWindow: Int = 6
}

// MARK: - WeatherContext

/// Lightweight, Sendable snapshot of current weather conditions relevant to biometrics.
public struct WeatherContext: Sendable {

    /// Timestamp of the weather observation.
    public let date: Date

    /// Temperature in degrees Celsius.
    public let temperatureCelsius: Double

    /// Relative humidity as a fraction (0.0 to 1.0).
    public let humidity: Double

    /// Barometric pressure in hectopascals (hPa).
    public let pressureHPa: Double

    /// Direction of pressure change over recent hours.
    public let pressureTrend: PressureTrend

    /// Simplified weather condition category.
    public let condition: WeatherCondition

    /// UV index (integer scale, typically 0-11+).
    public let uvIndex: Int

    public init(
        date: Date,
        temperatureCelsius: Double,
        humidity: Double,
        pressureHPa: Double,
        pressureTrend: PressureTrend,
        condition: WeatherCondition,
        uvIndex: Int
    ) {
        self.date = date
        self.temperatureCelsius = temperatureCelsius
        self.humidity = humidity
        self.pressureHPa = pressureHPa
        self.pressureTrend = pressureTrend
        self.condition = condition
        self.uvIndex = uvIndex
    }
}

// MARK: - PressureTrend

/// Direction of barometric pressure change.
public enum PressureTrend: String, Sendable, CaseIterable {
    case rising
    case steady
    case falling

    /// SF Symbol name for trend direction.
    public var icon: String {
        switch self {
        case .rising:  return "arrow.up.right"
        case .steady:  return "arrow.right"
        case .falling: return "arrow.down.right"
        }
    }

    /// Human-readable label.
    public var label: String {
        switch self {
        case .rising:  return "Rising"
        case .steady:  return "Steady"
        case .falling: return "Falling"
        }
    }
}

// MARK: - WeatherCondition

/// Simplified weather condition categories relevant to session context.
public enum WeatherCondition: String, Sendable, CaseIterable {
    case clear
    case cloudy
    case rainy
    case stormy
    case snowy
    case foggy
    case windy

    /// SF Symbol name for the condition.
    public var icon: String {
        switch self {
        case .clear:  return "sun.max.fill"
        case .cloudy: return "cloud.fill"
        case .rainy:  return "cloud.rain.fill"
        case .stormy: return "cloud.bolt.rain.fill"
        case .snowy:  return "cloud.snow.fill"
        case .foggy:  return "cloud.fog.fill"
        case .windy:  return "wind"
        }
    }

    /// Human-readable label.
    public var label: String {
        switch self {
        case .clear:  return "Clear"
        case .cloudy: return "Cloudy"
        case .rainy:  return "Rainy"
        case .stormy: return "Stormy"
        case .snowy:  return "Snowy"
        case .foggy:  return "Foggy"
        case .windy:  return "Windy"
        }
    }
}

// MARK: - WeatherServiceProtocol

/// Contract for weather data integration.
///
/// Implementations read current and historical weather data to surface
/// environmental context in the Health view and inform pre-session intelligence.
/// All methods degrade gracefully — returning nil when WeatherKit is
/// unavailable, location permission is denied, or data cannot be fetched.
public protocol WeatherServiceProtocol: AnyObject, Sendable {

    /// Fetch current weather conditions for the user's location.
    ///
    /// Returns cached data when within the `cacheExpirationMinutes` window.
    /// Falls back to default coordinates when location is unavailable.
    ///
    /// - Returns: Current weather context, or nil if WeatherKit is unavailable.
    func currentWeather() async -> WeatherContext?

    /// Fetch daily weather summaries for the lookback period.
    ///
    /// Used for correlation analysis between weather patterns and session outcomes.
    ///
    /// - Parameter days: Number of days to look back (max 10).
    /// - Returns: Array of daily weather contexts, oldest first.
    func weatherHistory(days: Int) async -> [WeatherContext]

    /// Compute the barometric pressure change from yesterday to today.
    ///
    /// This is the hero metric — falling pressure correlates with reduced HRV,
    /// mood changes, and migraine onset.
    ///
    /// - Returns: Pressure delta in hPa (positive = rising), or nil if insufficient data.
    func pressureChangeFromYesterday() async -> Double?
}

// MARK: - WeatherService

/// Concrete WeatherKit implementation of ``WeatherServiceProtocol``.
///
/// Uses `WeatherService.shared` from Apple's WeatherKit framework.
/// Requests a one-shot location via CLLocationManager, caches results
/// to respect rate limits, and maps Apple's Weather types to the
/// lightweight ``WeatherContext`` model.
///
/// - Important: Requires the WeatherKit capability in the app's entitlements
///   and an active Apple Developer Program membership.
public final class LiveWeatherService: NSObject, WeatherServiceProtocol, @unchecked Sendable {

    // MARK: - Properties

    private let weatherService = WeatherKit.WeatherService.shared
    private let locationManager = CLLocationManager()
    private static let logger = Logger(subsystem: "com.bionaural", category: "weather")

    /// Cached weather context to avoid excessive WeatherKit API calls.
    private var cachedContext: WeatherContext?
    private var cacheTimestamp: Date?

    /// Continuation for one-shot location requests.
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    // MARK: - Init

    public override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    // MARK: - WeatherServiceProtocol

    public func currentWeather() async -> WeatherContext? {
        // Return cached data if still fresh
        if let cached = cachedContext,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < Double(WeatherConfig.cacheExpirationMinutes) * 60 {
            Self.logger.debug("Returning cached weather context")
            return cached
        }

        let location = await resolveLocation()

        do {
            let weather = try await weatherService.weather(for: location)
            let current = weather.currentWeather

            // Compute pressure trend from hourly forecast
            let trend = computePressureTrend(from: weather.hourlyForecast)

            let context = WeatherContext(
                date: current.date,
                temperatureCelsius: current.temperature.converted(to: .celsius).value,
                humidity: current.humidity,
                pressureHPa: current.pressure.converted(to: .hectopascals).value,
                pressureTrend: trend,
                condition: mapCondition(current.condition),
                uvIndex: current.uvIndex.value
            )

            cachedContext = context
            cacheTimestamp = Date()

            Self.logger.info(
                "Weather fetched: \(context.condition.label), \(String(format: "%.0f", context.pressureHPa)) hPa, trend: \(trend.label)"
            )

            return context
        } catch {
            Self.logger.error("WeatherKit fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    public func weatherHistory(days: Int) async -> [WeatherContext] {
        let clampedDays = min(max(days, 1), WeatherConfig.maxHistoryDays)
        let location = await resolveLocation()

        do {
            let calendar = Calendar.current
            let now = Date()
            guard let startDate = calendar.date(byAdding: .day, value: -clampedDays, to: now) else {
                return []
            }

            let weather = try await weatherService.weather(
                for: location,
                including: .daily(startDate: startDate, endDate: now)
            )

            return weather.forecast.map { day in
                WeatherContext(
                    date: day.date,
                    temperatureCelsius: day.highTemperature.converted(to: .celsius).value,
                    humidity: WeatherConfig.dailyForecastFallbackHumidity, // Day forecasts lack per-hour humidity; use placeholder
                    pressureHPa: WeatherConfig.dailyForecastFallbackPressure, // Day forecasts lack pressure; use hourly for pressure
                    pressureTrend: .steady,
                    condition: mapCondition(day.condition),
                    uvIndex: day.uvIndex.value
                )
            }
        } catch {
            Self.logger.error("WeatherKit history fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    public func pressureChangeFromYesterday() async -> Double? {
        let location = await resolveLocation()

        do {
            let calendar = Calendar.current
            let now = Date()
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else {
                return nil
            }

            let weather = try await weatherService.weather(
                for: location,
                including: .hourly(startDate: yesterday, endDate: now)
            )

            let forecasts = weather.forecast
            guard forecasts.count >= 2,
                  let first = forecasts.first,
                  let last = forecasts.last else { return nil }

            // Compare the earliest reading (~24h ago) to the most recent
            let oldestPressure = first.pressure.converted(to: .hectopascals).value
            let newestPressure = last.pressure.converted(to: .hectopascals).value

            let delta = newestPressure - oldestPressure
            Self.logger.debug("Pressure delta (24h): \(String(format: "%.1f", delta)) hPa")

            return delta
        } catch {
            Self.logger.error("Pressure history fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Location Resolution

    /// Resolves the user's current location, falling back to default coordinates.
    private func resolveLocation() async -> CLLocation {
        let status = locationManager.authorizationStatus

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            if let location = await requestOneShot() {
                return location
            }
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            // After requesting, try a one-shot (delegate will provide location)
            if let location = await requestOneShot() {
                return location
            }
        case .denied, .restricted:
            Self.logger.info("Location permission denied — using default coordinates")
        @unknown default:
            Self.logger.warning("Unknown location authorization status")
        }

        return CLLocation(
            latitude: WeatherConfig.defaultLatitude,
            longitude: WeatherConfig.defaultLongitude
        )
    }

    /// Performs a one-shot location request with a continuation.
    private func requestOneShot() async -> CLLocation? {
        await withCheckedContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    // MARK: - Condition Mapping

    /// Maps Apple's WeatherKit condition enum to our simplified ``WeatherCondition``.
    private func mapCondition(_ appleCondition: WeatherKit.WeatherCondition) -> WeatherCondition {
        switch appleCondition {
        case .clear, .mostlyClear, .hot:
            return .clear
        case .cloudy, .mostlyCloudy, .partlyCloudy:
            return .cloudy
        case .rain, .heavyRain, .drizzle, .freezingRain:
            return .rainy
        case .thunderstorms, .tropicalStorm, .hurricane, .isolatedThunderstorms,
             .scatteredThunderstorms, .strongStorms:
            return .stormy
        case .snow, .heavySnow, .flurries, .sleet, .freezingDrizzle,
             .wintryMix, .blizzard:
            return .snowy
        case .foggy, .haze, .smoky:
            return .foggy
        case .windy, .breezy:
            return .windy
        default:
            return .cloudy
        }
    }

    // MARK: - Pressure Trend Computation

    /// Computes pressure trend from the last few hours of hourly forecast data.
    private func computePressureTrend(
        from hourlyForecast: Forecast<HourWeather>
    ) -> PressureTrend {
        let recentHours = Array(hourlyForecast.prefix(WeatherConfig.pressureTrendHourWindow))
        guard recentHours.count >= 2,
              let first = recentHours.first,
              let last = recentHours.last else { return .steady }

        let firstPressure = first.pressure.converted(to: .hectopascals).value
        let lastPressure = last.pressure.converted(to: .hectopascals).value
        let delta = lastPressure - firstPressure

        if delta > WeatherConfig.pressureChangeDeltaThreshold / 2 {
            return .rising
        } else if delta < -(WeatherConfig.pressureChangeDeltaThreshold / 2) {
            return .falling
        } else {
            return .steady
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LiveWeatherService: CLLocationManagerDelegate {

    public func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        locationContinuation?.resume(returning: locations.last)
        locationContinuation = nil
    }

    public func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        Self.logger.error("Location request failed: \(error.localizedDescription)")
        locationContinuation?.resume(returning: nil)
        locationContinuation = nil
    }
}
