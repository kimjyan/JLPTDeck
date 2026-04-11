import XCTest
@testable import JLPTDeck

final class QuizGeneratorTests: XCTestCase {

    private struct SeededRNG: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            // Splitmix64 — deterministic, simple, no Foundation dep
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    private func makeInput(_ ko: String = "먹다") -> QuizGenerator.Input {
        QuizGenerator.Input(
            cardID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            headword: "食べる",
            reading: "たべる",
            glossKo: ko
        )
    }

    func test_choicesAreExactlyFour() {
        var rng = SeededRNG(state: 1)
        let q = QuizGenerator.make(
            input: makeInput(),
            distractors: ["마시다", "걷다", "자다", "보다", "읽다"],
            rng: &rng
        )
        XCTAssertEqual(q.choices.count, 4)
    }

    func test_correctIndexPointsAtCorrectAnswer() {
        var rng = SeededRNG(state: 42)
        let q = QuizGenerator.make(
            input: makeInput("먹다"),
            distractors: ["마시다", "걷다", "자다"],
            rng: &rng
        )
        XCTAssertEqual(q.choices[q.correctIndex], "먹다")
    }

    func test_distractorsExcludeCorrect() {
        var rng = SeededRNG(state: 7)
        let q = QuizGenerator.make(
            input: makeInput("먹다"),
            // Includes "먹다" in distractors — generator must filter it out
            distractors: ["마시다", "먹다", "걷다", "자다"],
            rng: &rng
        )
        let nonCorrect = q.choices.enumerated().filter { $0.offset != q.correctIndex }.map { $0.element }
        XCTAssertFalse(nonCorrect.contains("먹다"))
    }

    func test_padsWhenDistractorsTooFew() {
        var rng = SeededRNG(state: 3)
        let q = QuizGenerator.make(
            input: makeInput(),
            distractors: ["마시다"],   // only 1
            rng: &rng
        )
        XCTAssertEqual(q.choices.count, 4)
        XCTAssertEqual(q.choices.filter { $0 == "—" }.count, 2)
    }

    func test_deterministicWithSeededRNG() {
        var rng1 = SeededRNG(state: 100)
        var rng2 = SeededRNG(state: 100)
        let input = makeInput()
        let pool = ["a", "b", "c", "d", "e"]
        let q1 = QuizGenerator.make(input: input, distractors: pool, rng: &rng1)
        let q2 = QuizGenerator.make(input: input, distractors: pool, rng: &rng2)
        XCTAssertEqual(q1, q2)
    }

    func test_questionConvenienceProperty() {
        var rng = SeededRNG(state: 9)
        let q = QuizGenerator.make(
            input: makeInput("자다"),
            distractors: ["먹다", "걷다", "보다"],
            rng: &rng
        )
        XCTAssertEqual(q.correctChoice, "자다")
    }
}
