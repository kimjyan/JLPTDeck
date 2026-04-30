import SwiftUI

struct SessionCompleteView: View {
    let completedCount: Int
    var correctCount: Int = 0
    var wrongCount: Int = 0
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.green)
                Text("오늘 \(completedCount)개 완료!")
                    .font(.system(size: 30, weight: .bold))
                    .tracking(-0.8)
                    .foregroundStyle(Theme.text)
            }
            if correctCount + wrongCount > 0 {
                HStack(spacing: 12) {
                    statChip(
                        label: "정답",
                        count: correctCount,
                        icon: "checkmark.circle.fill",
                        color: Theme.green
                    )
                    statChip(
                        label: "오답",
                        count: wrongCount,
                        icon: "xmark.circle.fill",
                        color: Theme.red
                    )
                }
                .padding(.horizontal, 32)
            }
            Text("수고하셨습니다.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.secondary)
            Spacer()
            Button {
                onDone()
            } label: {
                Text("홈으로")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.buttonRadius)
                            .fill(Theme.accent)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
            .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg.ignoresSafeArea())
    }

    private func statChip(label: String, count: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(label).foregroundStyle(Theme.secondary)
            Text("\(count)")
                .fontWeight(.semibold)
                .foregroundStyle(Theme.text)
                .monospacedDigit()
        }
        .font(.system(size: 15, weight: .medium))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .fill(Theme.surface)
        )
    }
}
