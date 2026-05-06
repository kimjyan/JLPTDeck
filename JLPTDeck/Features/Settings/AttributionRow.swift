import SwiftUI

/// F6 (attribution): single attribution row used by the Settings "데이터
/// 출처" section. Shows title + subtitle with an external-link affordance
/// when a URL is provided. Tapping the row opens the URL via SwiftUI's
/// `Link` (no UIApplication.openURL boilerplate, no extra entitlements).
struct AttributionRow: View {
    let title: String
    let subtitle: String
    let urlString: String?

    var body: some View {
        if let urlString, let url = URL(string: urlString) {
            Link(destination: url) {
                rowContent(showsLink: true)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.attribution.\(title)")
        } else {
            rowContent(showsLink: false)
                .accessibilityIdentifier("settings.attribution.\(title)")
        }
    }

    @ViewBuilder
    private func rowContent(showsLink: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.text)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.secondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 8)
            if showsLink {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.tertiary)
            }
        }
    }
}
