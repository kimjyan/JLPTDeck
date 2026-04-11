import SwiftUI

struct FlashcardView: View {
    let card: VocabCard
    @Binding var showBack: Bool

    var body: some View {
        ZStack {
            CardFrontView(card: card)
                .opacity(showBack ? 0 : 1)
                .rotation3DEffect(
                    .degrees(showBack ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )
            CardBackView(card: card)
                .opacity(showBack ? 1 : 0)
                .rotation3DEffect(
                    .degrees(showBack ? 0 : -180),
                    axis: (x: 0, y: 1, z: 0)
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.35)) {
                showBack.toggle()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showBack)
    }
}
