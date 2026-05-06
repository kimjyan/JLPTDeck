import XCTest
@testable import JLPTDeck

/// F17 (G-CardView) detection tests. Pure regex/character checks — no
/// SwiftData / TCA / view harness involved.
final class PronunciationTrapsTests: XCTestCase {

    // MARK: long vowel (장음)

    func test_chouonpu_detectsLongVowel() {
        let traps = PronunciationTraps.detect(reading: "コーヒー")
        XCTAssertTrue(traps.contains(.longVowel))
    }

    func test_oRowFollowedByU_detectsLongVowel() {
        // こうこう (高校) — classic 장음 trap
        let traps = PronunciationTraps.detect(reading: "こうこう")
        XCTAssertTrue(traps.contains(.longVowel))
    }

    func test_eRowFollowedByI_detectsLongVowel() {
        // せんせい (先生) — common Korean-learner mistake
        let traps = PronunciationTraps.detect(reading: "せんせい")
        XCTAssertTrue(traps.contains(.longVowel))
    }

    func test_noLongVowel_noFalsePositive() {
        // たべる — no chouonpu, no o+u or e+i sequence
        let traps = PronunciationTraps.detect(reading: "たべる")
        XCTAssertFalse(traps.contains(.longVowel),
                       "must not flag every long-ish word as 장음")
    }

    // MARK: small tsu (촉음)

    func test_smallHiraganaTsu_detectsSmallTsu() {
        let traps = PronunciationTraps.detect(reading: "いっぱい")
        XCTAssertTrue(traps.contains(.smallTsu))
    }

    func test_smallKatakanaTsu_detectsSmallTsu() {
        let traps = PronunciationTraps.detect(reading: "コップ")
        XCTAssertTrue(traps.contains(.smallTsu))
    }

    // MARK: mora-N (ん)

    func test_hiraganaN_detectsMoraN() {
        // せんせい — also has long vowel; check moraN axis
        let traps = PronunciationTraps.detect(reading: "せんせい")
        XCTAssertTrue(traps.contains(.moraN))
    }

    func test_katakanaN_detectsMoraN() {
        let traps = PronunciationTraps.detect(reading: "パン")
        XCTAssertTrue(traps.contains(.moraN))
    }

    // MARK: combination + edge cases

    func test_multipleTraps_detectsAll() {
        // しんぱい — ん + 촉음(っ)... wait, that's しっぱい. Use しんぱい
        // for ん only; then a combined string for multi-trap.
        let multi = PronunciationTraps.detect(reading: "しっぱいー")
        XCTAssertTrue(multi.contains(.smallTsu))
        XCTAssertTrue(multi.contains(.longVowel))
    }

    func test_emptyString_noTraps() {
        let traps = PronunciationTraps.detect(reading: "")
        XCTAssertTrue(traps.isEmpty)
    }

    func test_kanjiOnly_noTraps() {
        // Only kanji, no kana → no trap detection (we only check kana).
        let traps = PronunciationTraps.detect(reading: "高校")
        XCTAssertFalse(traps.contains(.longVowel),
                       "we don't read kanji to infer kana — input is the kana reading")
    }

    func test_koreanNames_areLocalized() {
        XCTAssertEqual(PronunciationTraps.Kind.longVowel.koreanName, "장음")
        XCTAssertEqual(PronunciationTraps.Kind.smallTsu.koreanName, "촉음")
        XCTAssertEqual(PronunciationTraps.Kind.moraN.koreanName, "ん")
    }
}
