import SwiftUI

struct DailyLimitView: View {
    @Environment(UserSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 16) {
            Text("하루 학습량")
                .font(.title2)
                .fontWeight(.semibold)
            Stepper(
                value: $settings.dailyLimit,
                in: 10...50,
                step: 5
            ) {
                Text("하루 \(settings.dailyLimit)개")
                    .font(.body)
            }
            Text("하루에 학습할 카드 수를 정해주세요.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
