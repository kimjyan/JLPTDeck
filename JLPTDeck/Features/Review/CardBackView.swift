import SwiftUI

struct CardBackView: View {
    let card: VocabCard

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text(card.reading)
                .font(.system(size: 36, weight: .medium))
                .multilineTextAlignment(.center)
            Text(card.gloss)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.cardBackground)
    }
}
