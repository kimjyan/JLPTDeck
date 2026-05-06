import SwiftUI
import UniformTypeIdentifiers

/// F13: minimal `FileDocument` wrapper used by SettingsView's `.fileExporter`
/// and `.fileImporter`. Carries raw JSON bytes — encoding/decoding happens at
/// call sites with `ExportPayloadCodec`.
struct JSONFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
