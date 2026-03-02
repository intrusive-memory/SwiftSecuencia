import Foundation
import SwiftCompartido
import SwiftData
import SwiftSecuencia

/// Bootstraps SwiftData with an in-memory container for CLI operations.
///
/// The CLI does not persist timelines to disk. All SwiftData operations use an
/// in-memory container that exists only for the duration of the build process.
///
/// ## Usage
///
/// ```swift
/// let container = try SwiftDataBootstrap.createInMemoryContainer()
/// let context = SwiftDataBootstrap.createContext(from: container)
/// ```
public enum SwiftDataBootstrap {

  /// Creates an in-memory SwiftData container with all required models.
  ///
  /// The container includes:
  /// - `Timeline` - Timeline structure
  /// - `TimelineClip` - Individual clips
  /// - `TypedDataStorage` - Media asset storage (from SwiftCompartido)
  ///
  /// - Returns: A configured `ModelContainer` with in-memory storage.
  /// - Throws: If container creation fails.
  public static func createInMemoryContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(
      isStoredInMemoryOnly: true
    )

    return try ModelContainer(
      for: Timeline.self, TimelineClip.self, TypedDataStorage.self,
      configurations: configuration
    )
  }

  /// Creates a model context from a container.
  ///
  /// - Parameter container: The model container to create a context from.
  /// - Returns: A new `ModelContext` for database operations.
  @MainActor
  public static func createContext(from container: ModelContainer) -> ModelContext {
    container.mainContext
  }
}
