import Foundation

/// JLPT difficulty level for a vocabulary item.
/// Ordered by ascending difficulty in `CaseIterable` (n4 = easiest, n1 = hardest).
enum JLPTLevel: String, CaseIterable, Codable {
    case n4
    case n3
    case n2
    case n1

    /// Numeric rank used for "lower level wins" tie-breaking during import.
    /// Smaller rank == easier == preferred when a word appears in multiple Tanos lists.
    var rank: Int {
        switch self {
        case .n4: return 0
        case .n3: return 1
        case .n2: return 2
        case .n1: return 3
        }
    }
}
