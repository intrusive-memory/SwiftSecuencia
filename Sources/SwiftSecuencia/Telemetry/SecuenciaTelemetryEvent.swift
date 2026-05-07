import Foundation

/// Telemetry events emitted by SwiftSecuencia to diagnose memory retention and resource cleanup.
///
/// These events track key lifecycle points in audio export, timeline conversion, and resource management
/// to identify memory leaks and retention issues in SwiftData ModelContexts, audio buffers,
/// timeline clips, and AVFoundation export sessions.
///
/// ## Usage
///
/// Implement ``SecuenciaTelemetryReporter`` to capture these events and forward them to your
/// telemetry system (e.g., OSLog, Sentry, custom analytics).
///
/// ```swift
/// let telemetry = MyTelemetryReporter()
/// let exporter = ForegroundAudioExporter(telemetry: telemetry)
/// ```
///
/// ## Event Categories
///
/// - **Export Events**: Track audio export lifecycle and ModelContext state
/// - **Timeline Conversion Events**: Monitor audio buffer accumulation and clip creation
/// - **AVFoundation Events**: Verify export session resource cleanup
/// - **Memory Leak Detection**: Identify ModelContext object retention
///
public enum SecuenciaTelemetryEvent: Sendable {

    /// Fired at the start of audio export, before any export operations begin.
    ///
    /// Use this event to establish a baseline for ModelContext object counts and timeline state.
    ///
    /// - Parameters:
    ///   - timelineClipCount: Number of clips in the timeline being exported
    ///   - modelContextObjects: Count of registered objects in the ModelContext (should typically be 0 at export start)
    ///
    /// ## Expected Behavior
    ///
    /// In a healthy system, `modelContextObjects` should be 0 or minimal at export start.
    /// If this count is non-zero across multiple episodes, it indicates ModelContext objects
    /// are not being released between exports (memory leak).
    ///
    case exportStart(timelineClipCount: Int, modelContextObjects: Int)

    /// Fired after audio export completes, capturing final state and resource usage.
    ///
    /// Use this event to verify ModelContext cleanup and measure output size.
    ///
    /// - Parameters:
    ///   - outputSizeMB: Size of the exported audio file in megabytes
    ///   - modelContextObjects: Count of registered objects in the ModelContext after export
    ///   - pendingChanges: Whether the ModelContext has unsaved changes (`modelContext.hasChanges`)
    ///
    /// ## Expected Behavior
    ///
    /// After export, `modelContextObjects` should return to baseline (typically 0).
    /// If `pendingChanges` is `true`, it may indicate incomplete cleanup or unexpected state mutations.
    /// Compare `modelContextObjects` between `exportStart` and `exportComplete` to detect retention.
    ///
    case exportComplete(outputSizeMB: Double, modelContextObjects: Int, pendingChanges: Bool)

    /// Fired at the start of timeline conversion, before processing audio elements.
    ///
    /// Use this event to track audio buffer accumulation and conversion workload.
    ///
    /// - Parameters:
    ///   - elementCount: Number of audio elements to be converted into timeline clips
    ///   - totalAudioMB: Total size of audio data in megabytes (sum of all element binary values)
    ///
    /// ## Expected Behavior
    ///
    /// `totalAudioMB` indicates memory pressure from audio buffers during conversion.
    /// If this value remains elevated after conversion completes, it suggests audio buffers
    /// are not being released (memory leak).
    ///
    case timelineConversionStart(elementCount: Int, totalAudioMB: Double)

    /// Fired after timeline conversion completes, capturing final timeline state.
    ///
    /// Use this event to verify timeline clips were created and measure total duration.
    ///
    /// - Parameters:
    ///   - clipCount: Number of clips created in the timeline
    ///   - durationSeconds: Total duration of the timeline in seconds
    ///
    /// ## Expected Behavior
    ///
    /// `clipCount` should match `elementCount` from `timelineConversionStart` (1:1 mapping expected).
    /// If `clipCount` accumulates across episodes (e.g., 16 → 32 → 48), it indicates timeline
    /// objects are persisting across episodes (memory leak).
    ///
    case timelineConversionComplete(clipCount: Int, durationSeconds: Double)

    /// Fired before creating an AVFoundation export session.
    ///
    /// Use this event to track AVFoundation resource allocation.
    ///
    /// - Parameters:
    ///   - compositionDuration: Duration of the AVComposition being exported, in seconds
    ///
    /// ## Expected Behavior
    ///
    /// This event establishes a baseline for AVFoundation export session creation.
    /// Compare with `avExportComplete` to verify session cleanup.
    ///
    case avExportStart(compositionDuration: Double)

    /// Fired after AVFoundation export session completes.
    ///
    /// Use this event to verify the export session was properly released.
    ///
    /// - Parameters:
    ///   - sessionRetained: Whether the export session reference is still non-nil after export
    ///
    /// ## Expected Behavior
    ///
    /// `sessionRetained` should be `false` if the export session was properly released.
    /// If `true`, it indicates the session is being retained after export completes (memory leak).
    ///
    case avExportComplete(sessionRetained: Bool)

    /// Fired when ModelContext shows signs of object retention across lifecycle boundaries.
    ///
    /// This is a diagnostic event that can be manually triggered to report suspected leaks.
    ///
    /// - Parameters:
    ///   - registeredObjects: Total count of registered objects in the ModelContext
    ///   - insertedObjects: Count of newly inserted objects pending save
    ///
    /// ## Expected Behavior
    ///
    /// This event should rarely fire. Non-zero `registeredObjects` after cleanup indicates
    /// a ModelContext leak. Non-zero `insertedObjects` after a save operation may indicate
    /// incomplete or failed persistence.
    ///
    case modelContextLeak(registeredObjects: Int, insertedObjects: Int)
}
