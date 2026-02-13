import Testing
import Foundation
import SwiftData
@testable import SecuenciaCLICore
import SwiftSecuencia
import SwiftCompartido

@Suite("SwiftDataBootstrap Tests")
struct SwiftDataBootstrapTests {

    @Test("Create in-memory container")
    func testCreateInMemoryContainer() throws {
        let container = try SwiftDataBootstrap.createInMemoryContainer()
        // Verify container was created successfully
        #expect(container.configurations.count > 0)
    }

    @Test("Container is stored in memory only")
    func testContainerIsInMemoryOnly() throws {
        let container = try SwiftDataBootstrap.createInMemoryContainer()

        // Verify the container uses in-memory storage
        let configurations = container.configurations
        #expect(configurations.count > 0)

        for config in configurations {
            #expect(config.isStoredInMemoryOnly == true)
        }
    }

    @Test("Container schema contains required models")
    func testContainerSchemaContainsModels() throws {
        let container = try SwiftDataBootstrap.createInMemoryContainer()

        // Verify schema contains Timeline, TimelineClip, and TypedDataStorage
        let schema = container.schema
        let modelNames = schema.entities.map { $0.name }

        #expect(modelNames.contains("Timeline"))
        #expect(modelNames.contains("TimelineClip"))
        #expect(modelNames.contains("TypedDataStorage"))
    }

    @Test("Create context from container")
    @MainActor
    func testCreateContext() throws {
        let container = try SwiftDataBootstrap.createInMemoryContainer()
        let context = SwiftDataBootstrap.createContext(from: container)

        // Verify context was created successfully
        #expect(context.container === container)
    }

    @Test("Context can insert Timeline")
    @MainActor
    func testContextCanInsertTimeline() throws {
        let container = try SwiftDataBootstrap.createInMemoryContainer()
        let context = SwiftDataBootstrap.createContext(from: container)

        let timeline = Timeline(name: "Test Timeline")
        context.insert(timeline)

        try context.save()

        // Verify timeline exists
        let descriptor = FetchDescriptor<Timeline>()
        let timelines = try context.fetch(descriptor)
        #expect(timelines.count == 1)
        #expect(timelines[0].name == "Test Timeline")
    }

    @Test("Context can insert TimelineClip")
    @MainActor
    func testContextCanInsertClip() throws {
        let container = try SwiftDataBootstrap.createInMemoryContainer()
        let context = SwiftDataBootstrap.createContext(from: container)

        let timeline = Timeline(name: "Test Timeline")
        context.insert(timeline)

        let clip = TimelineClip(
            assetStorageId: UUID(),
            offset: .zero,
            duration: Timecode(seconds: 10)
        )
        timeline.clips.append(clip)

        try context.save()

        // Verify clip exists
        let descriptor = FetchDescriptor<TimelineClip>()
        let clips = try context.fetch(descriptor)
        #expect(clips.count == 1)
        #expect(clips[0].duration.seconds == 10.0)
    }

    @Test("Context can insert TypedDataStorage")
    @MainActor
    func testContextCanInsertTypedDataStorage() throws {
        let container = try SwiftDataBootstrap.createInMemoryContainer()
        let context = SwiftDataBootstrap.createContext(from: container)

        let storage = TypedDataStorage(
            id: UUID(),
            providerId: "test-provider",
            requestorID: "test-requestor",
            data: GeneratedTextData(
                text: "Hello, World!",
                model: "test-model"
            ),
            prompt: "Test prompt"
        )
        context.insert(storage)

        try context.save()

        // Verify storage exists
        let descriptor = FetchDescriptor<TypedDataStorage>()
        let records = try context.fetch(descriptor)
        #expect(records.count == 1)
        #expect(records[0].requestorID == "test-requestor")
    }
}
