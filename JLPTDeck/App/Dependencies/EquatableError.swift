import Foundation

/// Wraps a non-Equatable Error so it can ride inside an Equatable Action payload.
struct EquatableError: Error, Equatable, Sendable {
    let message: String
    init(_ error: Error) { self.message = String(describing: error) }
    static func == (lhs: EquatableError, rhs: EquatableError) -> Bool { lhs.message == rhs.message }
}
