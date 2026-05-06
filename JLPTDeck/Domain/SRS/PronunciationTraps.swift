import Foundation

/// F17 (G-CardView): pure detection of pronunciation traps in a kana
/// reading that Korean learners commonly stumble on. Returns the set of
/// detected trap kinds. UI maps each kind to an icon + Korean tooltip.
///
/// Detection rules (regex on the `reading` string):
/// - `.longVowel` (장음): a chōonpu `ー` OR an `(あ・い・う・え・お)`-row
///   kana followed by `う` (forming おう/こう/そう/…) or `い` (forming
///   けい/せい/ねい/…). Loose heuristic — the goal is to surface candidates
///   for the user to *think* about, not to be a phonologically perfect
///   classifier. False positives are acceptable.
/// - `.smallTsu` (촉음): contains `っ` or `ッ` (sokuon).
/// - `.moraN` (ん): contains `ん` or `ン`.
public enum PronunciationTraps {
    public enum Kind: Hashable, Sendable {
        case longVowel
        case smallTsu
        case moraN

        public var koreanName: String {
            switch self {
            case .longVowel: return "장음"
            case .smallTsu:  return "촉음"
            case .moraN:     return "ん"
            }
        }

        public var koreanTooltip: String {
            switch self {
            case .longVowel: return "장음 — 모음을 길게 발음하세요 (예: おう, えい, ー)"
            case .smallTsu:  return "촉음 — 다음 자음을 1박 멈췄다 발음하세요 (예: いっぱい)"
            case .moraN:     return "ん — 한 박자 비음으로 발음하세요"
            }
        }
    }

    /// Returns the set of pronunciation traps present in the reading.
    /// Empty set means no traps detected — UI should hide the badge row.
    public static func detect(reading: String) -> Set<Kind> {
        var found: Set<Kind> = []

        if reading.contains("ー") || hasVowelLengthening(reading) {
            found.insert(.longVowel)
        }
        if reading.contains("っ") || reading.contains("ッ") {
            found.insert(.smallTsu)
        }
        if reading.contains("ん") || reading.contains("ン") {
            found.insert(.moraN)
        }
        return found
    }

    /// Detects vowel-lengthening combos (おう, えい, etc.) without the
    /// chōonpu. We walk the string and look for an o-row kana followed
    /// by う, or an e-row kana followed by い. This is intentionally
    /// conservative — over-detection is a worse UX than under-detection
    /// (cluttered card), so we limit to the two highest-frequency
    /// patterns Korean learners ask about.
    private static func hasVowelLengthening(_ s: String) -> Bool {
        let oRow: Set<Character> = [
            "お", "こ", "そ", "と", "の", "ほ", "も", "よ", "ろ", "を",
            "ご", "ぞ", "ど", "ぼ", "ぽ",
            "オ", "コ", "ソ", "ト", "ノ", "ホ", "モ", "ヨ", "ロ", "ヲ",
            "ゴ", "ゾ", "ド", "ボ", "ポ"
        ]
        let eRow: Set<Character> = [
            "え", "け", "せ", "て", "ね", "へ", "め", "れ",
            "げ", "ぜ", "で", "べ", "ぺ",
            "エ", "ケ", "セ", "テ", "ネ", "ヘ", "メ", "レ",
            "ゲ", "ゼ", "デ", "ベ", "ペ"
        ]

        let chars = Array(s)
        guard chars.count >= 2 else { return false }
        for i in 0..<(chars.count - 1) {
            let cur = chars[i]
            let next = chars[i + 1]
            if oRow.contains(cur) && (next == "う" || next == "ウ") { return true }
            if eRow.contains(cur) && (next == "い" || next == "イ") { return true }
        }
        return false
    }
}
