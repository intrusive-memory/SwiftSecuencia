import Foundation

/// Provides access to the schema.json resource bundled with SecuenciaCLICore
public enum SchemaResource {
    /// Returns the URL to the schema.json resource
    public static var schemaURL: URL? {
        Bundle.module.url(forResource: "schema", withExtension: "json")
    }

    /// Returns the schema.json content as Data
    public static func schemaData() throws -> Data {
        guard let url = schemaURL else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try Data(contentsOf: url)
    }
}
