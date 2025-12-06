import Testing
import Foundation
import SwiftData
import SwiftCompartido
@testable import SwiftSecuencia

// MARK: - AppIntent Structure Tests
//
// NOTE: Full integration testing of AppIntents requires:
// - Real SwiftData documents with valid PersistentIdentifiers
// - TypedDataStorage records with actual audio file data
// - App Intents runtime environment
// - Shortcuts integration framework
//
// The underlying functionality IS comprehensively tested in:
// - FCPXMLBundleExportTests.swift (bundle creation, media export)
// - TimelineTests.swift (timeline management)
// - AssetIntegrationTests.swift (TypedDataStorage integration)
//
// These tests verify the AppIntent structure and metadata only.

@Test func appIntentHasCorrectMetadata() async throws {
    // Verify intent title
    #expect(GenerateFCPXMLBundleIntent.title.key.hasPrefix("Generate FCPXML Bundle"))

    // Verify intent doesn't open app
    #expect(GenerateFCPXMLBundleIntent.openAppWhenRun == false)
}

@Test func appIntentCanBeInitialized() async throws {
    // Verify the intent can be initialized
    // We can create an empty intent instance
    _ = GenerateFCPXMLBundleIntent()

    // If we get here without crashing, the test passes
}

// NOTE ON TESTING STRATEGY:
//
// AppIntents are designed to be tested in Shortcuts or via the App Intents framework.
// Unit testing them requires mocking the entire AppIntents runtime, PersistentIdentifier
// creation, and SwiftData context - which is impractical and brittle.
//
// Instead, we rely on:
// 1. Structural tests (above) - verify intent metadata
// 2. Component tests - all components used by the intent are tested independently
// 3. Manual testing - use Shortcuts app to verify end-to-end workflow
//
// The intent's perform() method delegates to:
// - Timeline creation (tested in TimelineTests)
// - FCPXMLBundleExporter (tested in FCPXMLBundleExportTests)
// - TypedDataStorage queries (tested in AssetIntegrationTests)
//
// All business logic is in tested components; the intent is a thin facade.
