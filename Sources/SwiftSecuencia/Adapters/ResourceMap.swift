import Foundation

/// Maps SwiftSecuencia asset UUIDs to FCPXML-compliant resource IDs (`r1`, `r2`, `r3`, ...).
///
/// FCPXML requires resources to have IDs that match an `IDREF` pattern. Pipeline Neo
/// hardcodes the format resource as `"r1"`, and expects asset IDs to be assigned by the
/// caller as `"r2"`, `"r3"`, etc. ResourceMap manages this mapping so that adapters
/// (Sortie 3+) can convert SwiftSecuencia UUIDs to r-prefixed IDs consistently.
///
/// ## Thread-Safety Decision
///
/// ResourceMap is implemented as a `struct` with `mutating` methods. This is appropriate
/// because the ResourceMap is built in a single pass during export setup (before any
/// concurrent work begins), and then read immutably during adapter conversions. The
/// typical usage pattern is:
///
/// 1. Create ResourceMap
/// 2. Register all assets (sequential, single-threaded)
/// 3. Pass ResourceMap (by value) to adapters for lookups (read-only)
///
/// If a future sortie requires concurrent registration (e.g., parallel timeline exports
/// each building their own ResourceMap), each export would create its own ResourceMap
/// instance, so concurrent mutation of a single instance is not expected. If that
/// assumption changes, this should be converted to an `actor`.
///
/// ## No Pipeline Neo Dependencies
///
/// This file intentionally does NOT import PipelineNeo. ResourceMap is a pure
/// SwiftSecuencia data structure that maps UUIDs to string IDs.
public struct ResourceMap: Sendable {

  /// The format resource ID, always `"r1"` per Pipeline Neo convention.
  private let formatID: String = "r1"

  /// Maps asset UUIDs to their assigned r-prefixed resource IDs.
  private var assetIDs: [UUID: String] = [:]

  /// The next numeric suffix to assign (starts at 2 because r1 is the format).
  private var nextIndex: Int = 2

  public init() {}

  /// Returns the format resource ID (always `"r1"`).
  public func formatResourceID() -> String {
    formatID
  }

  /// Registers an asset UUID and returns its resource ID.
  ///
  /// If the UUID was already registered, returns the existing ID (idempotent).
  /// New UUIDs get sequential IDs: `"r2"`, `"r3"`, `"r4"`, ...
  ///
  /// - Parameter uuid: The asset's UUID from the SwiftSecuencia model.
  /// - Returns: The FCPXML-compliant resource ID string (e.g. `"r2"`).
  @discardableResult
  public mutating func registerAsset(_ uuid: UUID) -> String {
    if let existing = assetIDs[uuid] {
      return existing
    }
    let id = "r\(nextIndex)"
    nextIndex += 1
    assetIDs[uuid] = id
    return id
  }

  /// Looks up the resource ID for a previously registered asset.
  ///
  /// - Parameter uuid: The asset's UUID to look up.
  /// - Returns: The resource ID string if registered, or `nil` if the UUID was never registered.
  public func assetResourceID(for uuid: UUID) -> String? {
    assetIDs[uuid]
  }

  /// Registers multiple asset UUIDs in sorted order to ensure deterministic ID assignment.
  ///
  /// UUIDs are sorted by their string representation before assigning IDs. This guarantees
  /// that the same set of UUIDs always produces the same ID mapping, regardless of the
  /// order they appear in the source data.
  ///
  /// UUIDs that were already registered retain their existing IDs.
  ///
  /// - Parameter uuids: The asset UUIDs to register.
  /// - Returns: A dictionary mapping each UUID to its assigned resource ID.
  @discardableResult
  public mutating func registerAssets(_ uuids: [UUID]) -> [UUID: String] {
    let sorted = uuids.sorted { $0.uuidString < $1.uuidString }
    var result: [UUID: String] = [:]
    for uuid in sorted {
      result[uuid] = registerAsset(uuid)
    }
    return result
  }

  /// The number of registered assets (not counting the format resource).
  public var assetCount: Int {
    assetIDs.count
  }

  // MARK: - Reverse Lookup

  /// Looks up the UUID for a previously assigned resource ID.
  ///
  /// This reverse lookup is used by `PipelineNeoAssetProvider` to convert incoming
  /// resource ID strings (e.g., `"r2"`, `"r3"`) back to asset UUIDs for SwiftData
  /// fetch operations. The lookup is O(n) over registered assets, which is acceptable
  /// because timelines typically contain a small number of unique assets (< 100).
  ///
  /// - Parameter resourceID: The r-prefixed resource ID to look up (e.g., `"r2"`).
  /// - Returns: The UUID associated with this resource ID, or `nil` if not found.
  public func uuid(for resourceID: String) -> UUID? {
    assetIDs.first(where: { $0.value == resourceID })?.key
  }

  /// Returns a dictionary mapping resource IDs to UUIDs (the inverse of the registration map).
  ///
  /// Useful when batch-converting resource IDs back to UUIDs. The dictionary is built
  /// on demand from the internal forward map.
  ///
  /// - Returns: A dictionary mapping each r-prefixed resource ID to its UUID.
  public var reverseMap: [String: UUID] {
    Dictionary(uniqueKeysWithValues: assetIDs.map { ($0.value, $0.key) })
  }
}
