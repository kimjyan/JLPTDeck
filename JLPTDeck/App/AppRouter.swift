import Foundation
import Observation

enum Route {
    case onboarding
    case home
    case review
}

@Observable
final class AppRouter {
    var route: Route = .onboarding
}
