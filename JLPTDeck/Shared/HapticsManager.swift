import UIKit

enum HapticsManager {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
