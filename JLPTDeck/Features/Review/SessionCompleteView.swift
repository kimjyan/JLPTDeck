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
                .font(.largeTitle)
                .fontWeight(.bold)
            if correctCount + wrongCount > 0 {
                HStack(spacing: 16) {
                    Label("정답 \(correctCount)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Label("오답 \(wrongCount)", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
                .font(.headline)
            }
            Text("수고하셨습니다.")
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                onDone()
            } label: {
                Text("홈으로")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .padding(.bottom)
        }
    }
}
