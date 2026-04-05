// MockWeatherService.swift
// BioNaural
//
// Mock implementation of WeatherServiceProtocol for tests and previews.
// Returns realistic sample data for all weather queries.
// Pattern matches MockCalendarService.

import Foundation

// MARK: - MockWeatherService

public final class MockWeatherService: WeatherServiceProtocol, @unchecked Sendable {

    // MARK: - Defaults

    private enum Defaults {
        static let temperature: Double = 18.5
        static let humidity: Double = 0.62
        static let pressure: Double = 1013.2
        static let uvIndex: Int = 3
        static let pressureDelta: Double = -3.8
        static let historyBaseTemp: Double = 16.0
        static let historyTempStep: Double = 0.5
        static let historyBaseHumidity: Double = 0.55
        static let historyHumidityStep: Double = 0.03
        static let historySamplePressures: [Double] = [1015.0, 1012.5, 1008.3, 1010.1, 1013.8, 1016.2, 1014.5]
    }

    // MARK: - Configurable Sample Data

    /// Override to return custom weather context in tests.
    public var sampleContext: WeatherContext?

    /// Override to return a custom pressure delta in tests.
    public var samplePressureDelta: Double?

    /// Override to return custom history in tests.
    public var sampleHistory: [WeatherContext]?

    /// When true, all methods return nil (simulates WeatherKit unavailable).
    public var simulateUnavailable: Bool = false

    // MARK: - Init

    public init() {}

    // MARK: - WeatherServiceProtocol

    public func currentWeather() async -> WeatherContext? {
        guard !simulateUnavailable else { return nil }

        if let override = sampleContext { return override }

        return WeatherContext(
            date: Date(),
            temperatureCelsius: Defaults.temperature,
            humidity: Defaults.humidity,
            pressureHPa: Defaults.pressure,
            pressureTrend: .falling,
            condition: .cloudy,
            uvIndex: Defaults.uvIndex
        )
    }

    public func weatherHistory(days: Int) async -> [WeatherContext] {
        guard !simulateUnavailable else { return [] }

        if let override = sampleHistory { return override }

        let calendar = Calendar.current
        let now = Date()

        return (0..<min(days, Defaults.historySamplePressures.count)).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: now) else {
                return nil
            }
            let conditions: [WeatherCondition] = [.clear, .cloudy, .rainy, .clear, .cloudy, .foggy, .clear]
            let index = offset % conditions.count

            return WeatherContext(
                date: date,
                temperatureCelsius: Defaults.historyBaseTemp + Double(offset) * Defaults.historyTempStep,
                humidity: Defaults.historyBaseHumidity + Double(offset) * Defaults.historyHumidityStep,
                pressureHPa: Defaults.historySamplePressures[index],
                pressureTrend: offset < 3 ? .falling : .rising,
                condition: conditions[index],
                uvIndex: max(1, 5 - offset)
            )
        }
    }

    public func pressureChangeFromYesterday() async -> Double? {
        guard !simulateUnavailable else { return nil }

        return samplePressureDelta ?? Defaults.pressureDelta
    }
}
