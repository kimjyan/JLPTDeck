import Foundation

/// On-disk shape of a single bundled JMdict entry.
/// The bundled `jmdict_n4_n1.json` resource is a top-level `[JMdictEntry]` array.
///
/// Pure-Swift type: no SwiftData / SwiftUI imports so it can be used from
/// build-time tooling and unit tests without a model container.
struct JMdictEntry: Codable, Equatable {
    let headword: String
    let reading: String
    let gloss: String
    let jlptLevel: JLPTLevel
}
