import Foundation
import SwiftData

@Model
final class VocabCard {
    @Attribute(.unique) var id: UUID
    var headword: String        // 漢字 form
    var reading: String         // かな form
    var gloss: String           // English or Korean meaning (Tanos gloss)
    var jlptLevel: String       // "n4" | "n3" | "n2" | "n1"
    var createdAt: Date

    init(
        id: UUID = UUID(),
        headword: String,
        reading: String,
        gloss: String,
        jlptLevel: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.headword = headword
        self.reading = reading
        self.gloss = gloss
        self.jlptLevel = jlptLevel
        self.createdAt = createdAt
    }
}
