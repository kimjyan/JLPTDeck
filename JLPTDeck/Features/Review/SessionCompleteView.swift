import SwiftUI

struct SessionCompleteView: View {
    let completedCount: Int
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("오늘 \(completedCount)개 완료!")
                .font(.largeTitle)
                .fontWeight(.bold)
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
