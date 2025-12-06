import Testing
@testable import SwiftSecuencia

@Test func libraryVersion() async throws {
    #expect(SwiftSecuencia.version == "1.0.2")
}

@Test func defaultFCPXMLVersion() async throws {
    #expect(SwiftSecuencia.defaultFCPXMLVersion == "1.11")
}

@Test func supportedVersionsIncludesLatest() async throws {
    #expect(SwiftSecuencia.supportedVersions.contains("1.11"))
}
