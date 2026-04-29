import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(UserSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext

    @State private var showResetConfirmation = false
    @State private var showResetComplete = false

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                Section("JLPT 레벨") {
                    Picker("레벨", selection: $settings.selectedLevel) {
                        ForEach(JLPTLevel.allCases, id: \.self) { level in
                            Text(level.rawValue.uppercased()).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("일일 학습량") {
                    Stepper(
                        "\(settings.dailyLimit)장",
                        value: $settings.dailyLimit,
                        in: 10...100,
                        step: 5
                    )
                }

                Section("앱 정보") {
                    HStack {
                        Text("버전")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(Theme.secondary)
                    }
                    Text("Data: JMdict (CC BY-SA), Tanos JLPT lists")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondary)
                }

                Section {
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("데이터 초기화")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("설정")
            .onDisappear {
                settings.save()
            }
            .onChange(of: settings.selectedLevel) { _, _ in settings.save() }
            .onChange(of: settings.dailyLimit) { _, _ in settings.save() }
            .alert("데이터 초기화", isPresented: $showResetConfirmation) {
                Button("취소", role: .cancel) {}
                Button("초기화", role: .destructive) {
                    resetAllSRSData()
                }
            } message: {
                Text("모든 학습 기록이 삭제됩니다. 이 작업은 되돌릴 수 없습니다.")
            }
            .alert("초기화 완료", isPresented: $showResetComplete) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("모든 학습 기록이 초기화되었습니다.")
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func resetAllSRSData() {
        do {
            try modelContext.delete(model: SRSState.self)
            try modelContext.save()
            showResetComplete = true
        } catch {
            // Silently handle
        }
    }
}
