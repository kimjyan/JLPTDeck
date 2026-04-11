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
    let gloss_ko: String
    let jlptLevel: JLPTLevel

    enum CodingKeys: String, CodingKey {
        case headword, reading, gloss, gloss_ko, jlptLevel
    }

    init(
        headword: String,
        reading: String,
        gloss: String,
        gloss_ko: String,
        jlptLevel: JLPTLevel
    ) {
        self.headword = headword
        self.reading = reading
        self.gloss = gloss
        self.gloss_ko = gloss_ko
        self.jlptLevel = jlptLevel
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.headword = try container.decode(String.self, forKey: .headword)
        self.reading = try container.decode(String.self, forKey: .reading)
        self.gloss = try container.decode(String.self, forKey: .gloss)
        // Decode-fault-tolerant: bundled JSON may not yet have this key.
        self.gloss_ko = try container.decodeIfPresent(String.self, forKey: .gloss_ko) ?? ""
        self.jlptLevel = try container.decode(JLPTLevel.self, forKey: .jlptLevel)
    }
}
