import SwiftUI

struct CardFrontView: View {
    let card: VocabCard

    var body: some View {
        VStack {
            Spacer()
            Text(card.headword)
                .font(.system(size: 80, weight: .bold))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .padding()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.cardBackground)
    }
}
