import Foundation

/// Protocol for capturing and reporting telemetry events from SwiftSecuencia.
///
/// Implement this protocol to integrate SwiftSecuencia telemetry with your application's
/// telemetry system (e.g., OSLog, Sentry, custom analytics, memory profilers).
///
/// ## Usage
///
/// Create a reporter implementation and pass it to SwiftSecuencia components:
///
/// ```swift
/// struct MyTelemetryReporter: SecuenciaTelemetryReporter {
///     func capture(_ event: SecuenciaTelemetryEvent) async {
///         switch event {
///         case .exportStart(let clipCount, let objects):
///             logger.info("Export starting: \(clipCount) clips, \(objects) objects")
///         case .exportComplete(let sizeMB, let objects, let pendingChanges):
///             logger.info("Export complete: \(sizeMB)MB, \(objects) objects, pending: \(pendingChanges)")
///         // ... handle other events
///         }
///     }
/// }
///
/// let telemetry = MyTelemetryReporter()
/// let exporter = ForegroundAudioExporter(telemetry: telemetry)
/// ```
///
/// ## Thread Safety
///
/// This protocol is marked `Sendable` to ensure thread-safe usage across actor boundaries.
/// Implementations must handle concurrent calls to `capture(_:)` safely.
///
/// ## Optional Integration
///
/// Telemetry is always optional in SwiftSecuencia. If you don't provide a reporter,
/// components will simply skip telemetry capture:
///
/// ```swift
/// // Telemetry disabled
/// let exporter = ForegroundAudioExporter(telemetry: nil)
/// ```
///
public protocol SecuenciaTelemetryReporter: Sendable {

    /// Capture and process a telemetry event asynchronously.
    ///
    /// This method is called at key lifecycle points in SwiftSecuencia to report
    /// memory state, resource usage, and potential retention issues.
    ///
    /// - Parameter event: The telemetry event to capture
    ///
    /// ## Implementation Notes
    ///
    /// - Implementations should be non-blocking and handle errors gracefully
    /// - Consider batching events for performance in high-frequency scenarios
    /// - Avoid blocking the caller's execution path with expensive I/O
    /// - Use structured logging or metrics systems for production telemetry
    ///
    /// ## Example Implementation
    ///
    /// ```swift
    /// func capture(_ event: SecuenciaTelemetryEvent) async {
    ///     switch event {
    ///     case .exportStart(let clipCount, let objects):
    ///         await analytics.track("secuencia.export.start", properties: [
    ///             "clip_count": clipCount,
    ///             "model_objects": objects
    ///         ])
    ///
    ///     case .modelContextLeak(let registered, let inserted):
    ///         await analytics.trackError("secuencia.leak.model_context", properties: [
    ///             "registered_objects": registered,
    ///             "inserted_objects": inserted
    ///         ])
    ///
    ///     // ... other cases
    ///     }
    /// }
    /// ```
    ///
    func capture(_ event: SecuenciaTelemetryEvent) async
}
