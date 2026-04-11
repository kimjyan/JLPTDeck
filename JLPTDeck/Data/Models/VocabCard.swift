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
    var createdAt: Date

    init(
        id: UUID = UUID(),
        headword: String,
        reading: String,
        gloss: String,
        gloss_ko: String = "",
        jlptLevel: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.headword = headword
        self.reading = reading
        self.gloss = gloss
        self.gloss_ko = gloss_ko
        self.jlptLevel = jlptLevel
        self.createdAt = createdAt
    }
}
