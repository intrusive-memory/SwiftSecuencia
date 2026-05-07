//
//  MockTelemetryReporter.swift
//  SwiftSecuencia
//
//  Mock telemetry reporter for testing telemetry instrumentation.
//

import Foundation
@testable import SwiftSecuencia

/// Mock telemetry reporter that captures events for testing.
///
/// This actor provides thread-safe event capture for verifying that
/// SwiftSecuencia components emit the correct telemetry events with
/// accurate payloads.
///
/// ## Usage
///
/// ```swift
/// let mock = MockTelemetryReporter()
/// let exporter = ForegroundAudioExporter(telemetry: mock)
///
/// try await exporter.exportAudio(...)
///
/// let events = await mock.events
/// #expect(events.count == 2)
/// ```
public actor MockTelemetryReporter: SecuenciaTelemetryReporter {

  /// Captured telemetry events in the order they were received
  public private(set) var events: [SecuenciaTelemetryEvent] = []

  public init() {}

  /// Capture a telemetry event and store it for later verification.
  ///
  /// - Parameter event: The telemetry event to capture
  public func capture(_ event: SecuenciaTelemetryEvent) async {
    events.append(event)
  }

  /// Reset captured events (useful between tests).
  public func reset() {
    events.removeAll()
  }

  /// Get the count of captured events.
  ///
  /// - Returns: Number of events captured
  public func eventCount() -> Int {
    return events.count
  }

  /// Find the first event matching a specific case.
  ///
  /// - Parameter matcher: Closure that returns true for matching event
  /// - Returns: The first matching event, or nil if not found
  public func firstEvent(matching matcher: @Sendable (SecuenciaTelemetryEvent) -> Bool) -> SecuenciaTelemetryEvent? {
    return events.first(where: matcher)
  }

  /// Check if any event matches the given criteria.
  ///
  /// - Parameter matcher: Closure that returns true for matching event
  /// - Returns: True if at least one event matches
  public func hasEvent(matching matcher: @Sendable (SecuenciaTelemetryEvent) -> Bool) -> Bool {
    return events.contains(where: matcher)
  }
}
