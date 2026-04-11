import Foundation

/// Builds a `QuizQuestion` from a target card and a pool of distractor glosses.
/// Pure function. Caller supplies the RNG so tests can seed deterministically.
public enum QuizGenerator {

    public struct Input: Equatable {
        public let cardID: UUID
        public let headword: String
        public let reading: String
        public let glossKo: String

        public init(cardID: UUID, headword: String, reading: String, glossKo: String) {
            self.cardID = cardID
            self.headword = headword
            self.reading = reading
            self.glossKo = glossKo
        }
    }

    /// `distractors` should be 3 or more distinct Korean glosses, none equal to `input.glossKo`.
    /// If fewer than 3 are supplied, the function still returns a valid 4-choice question by
    /// padding with placeholder strings (caller should ensure the pool is sufficient — this
    /// is a defensive fallback, not a happy path).
    public static func make<R: RandomNumberGenerator>(
        input: Input,
        distractors: [String],
        rng: inout R
    ) -> QuizQuestion {
        var pool = distractors.filter { $0 != input.glossKo }
        // Ensure exactly 3 distractors. Pad if short.
        while pool.count < 3 {
            pool.append("—")
        }
        let picked = Array(pool.shuffled(using: &rng).prefix(3))
        var choices = picked + [input.glossKo]
        choices.shuffle(using: &rng)
        let correctIndex = choices.firstIndex(of: input.glossKo)!
        return QuizQuestion(
            cardID: input.cardID,
            prompt: input.headword,
            reading: input.reading,
            choices: choices,
            correctIndex: correctIndex
        )
    }
}
