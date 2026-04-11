import SwiftUI

struct LevelPickerView: View {
    @Environment(UserSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 16) {
            Text("JLPT 레벨 선택")
                .font(.title2)
                .fontWeight(.semibold)
            Picker("JLPT Level", selection: $settings.selectedLevel) {
                ForEach(JLPTLevel.allCases, id: \.self) { level in
                    Text(level.rawValue.uppercased()).tag(level)
                }
            }
            .pickerStyle(.segmented)
            Text("학습할 JLPT 레벨을 골라주세요.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
