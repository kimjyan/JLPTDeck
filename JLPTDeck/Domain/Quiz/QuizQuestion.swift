import Foundation

/// A multiple-choice quiz question generated from a vocabulary card.
/// Pure value type — no SwiftData dependency, suitable for snapshotting and testing.
public struct QuizQuestion: Equatable {
    public let cardID: UUID
    public let prompt: String          // headword (kanji)
    public let reading: String         // reading (kana)
    public let choices: [String]       // exactly 4 Korean glosses
    public let correctIndex: Int       // 0..<4

    public init(cardID: UUID, prompt: String, reading: String, choices: [String], correctIndex: Int) {
        precondition(choices.count == 4, "QuizQuestion requires exactly 4 choices")
        precondition((0..<4).contains(correctIndex), "correctIndex must be 0..<4")
        self.cardID = cardID
        self.prompt = prompt
        self.reading = reading
        self.choices = choices
        self.correctIndex = correctIndex
    }

    public var correctChoice: String { choices[correctIndex] }
}
