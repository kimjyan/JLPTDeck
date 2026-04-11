import Foundation

/// Quality of a review response for the SM-2 algorithm.
/// We intentionally expose only a subset of the classic 0..5 SM-2 grades to
/// keep the UI simple. Values remain compatible with SM-2 math.
public enum SRSQuality: Int {
    case again = 0
    case hard = 3
    case good = 4
    case easy = 5
}
