import Foundation
import SwiftData

@Model
final class VocabCard {
    @Attribute(.unique) var id: UUID
    var headword: String        // 漢字 form
    var reading: String         // かな form
    var gloss: String           // English or Korean meaning (Tanos gloss)
    var gloss_ko: String        // Korean meaning (filled in by translation process)
    var jlptLevel: String       // "n4" | "n3" | "n2" | "n1"
    /// F12 (G-CardView): part-of-speech token from JMdict (e.g., "動詞",
    /// "形容詞", "名詞"). Optional — bundled JSON currently lacks this
    /// field for every entry, so the view's POS row stays hidden until
    /// a future data refresh populates it. Adding the column now keeps
    /// the SwiftData migration trivial (new optional attribute) and
    /// avoids a second migration when the data lands.
    var pos: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        headword: String,
        reading: String,
        gloss: String,
        gloss_ko: String = "",
        jlptLevel: String,
        pos: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.headword = headword
        self.reading = reading
        self.gloss = gloss
        self.gloss_ko = gloss_ko
        self.jlptLevel = jlptLevel
        self.pos = pos
        self.createdAt = createdAt
    }
}
