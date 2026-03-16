import Testing

@testable import SwiftSecuencia

@Test func defaultFCPXMLVersion() async throws {
  #expect(SwiftSecuencia.defaultFCPXMLVersion == "1.13")
}

@Test func supportedVersionsIncludesLatest() async throws {
  #expect(SwiftSecuencia.supportedVersions.contains("1.11"))
}
