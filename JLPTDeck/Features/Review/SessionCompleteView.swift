import SwiftUI

struct SessionCompleteView: View {
    let completedCount: Int
    var correctCount: Int = 0
    var wrongCount: Int = 0
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("오늘 \(completedCount)개 완료!")
                .font(.system(size: 34, weight: .bold))
                .tracking(-1)
                .foregroundStyle(Theme.text)
            if correctCount + wrongCount > 0 {
                HStack(spacing: 24) {
                    Label("정답 \(correctCount)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Theme.green)
                    Label("오답 \(wrongCount)", systemImage: "xmark.circle.fill")
                        .foregroundStyle(Theme.red)
                }
                .font(.system(size: 17, weight: .semibold))
            }
            Text("수고하셨습니다.")
                .font(.system(size: 17))
                .foregroundStyle(Theme.secondary)
            Spacer()
            Button {
                onDone()
            } label: {
                Text("홈으로")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .padding(.bottom)
        }
    }
}
