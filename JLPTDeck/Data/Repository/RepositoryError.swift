import Foundation

enum RepositoryError: Error {
    case notFound
    case persistenceFailure(Error)
}
