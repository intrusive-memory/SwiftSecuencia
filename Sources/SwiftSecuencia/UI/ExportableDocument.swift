//
//  ExportableDocument.swift
//  SwiftSecuencia
//
//  Protocol for documents that can be exported via ExportMenuView.
//

import Foundation
import SwiftData
import SwiftCompartido

/// Protocol for documents that can be exported to FCP and M4A.
///
/// Conform your document type to this protocol to use `ExportMenuView`.
///
/// ## Example
///
/// ```swift
/// class MyDocument: ExportableDocument {
///     var exportName: String { "My Project" }
///
///     func audioElements() -> [TypedDataStorage] {
///         return sortedElements.filter { $0.mimeType.hasPrefix("audio/") }
///     }
/// }
/// ```
@MainActor
public protocol ExportableDocument {
    /// Name to use for exported files (without extension).
    var exportName: String { get }

    /// Returns audio elements for export, sorted in the desired playback order.
    func audioElements() -> [TypedDataStorage]
}
