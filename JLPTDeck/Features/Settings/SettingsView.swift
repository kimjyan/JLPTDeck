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
                Section {
                    Picker("레벨", selection: $settings.selectedLevel) {
                        ForEach(JLPTLevel.allCases, id: \.self) { level in
                            Text(level.rawValue.uppercased()).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("JLPT 레벨").foregroundStyle(Theme.secondary)
                }
                .listRowBackground(Theme.surface)

                Section {
                    Stepper(
                        "\(settings.dailyLimit)장",
                        value: $settings.dailyLimit,
                        in: 10...100,
                        step: 5
                    )
                    .foregroundStyle(Theme.text)
                } header: {
                    Text("일일 학습량").foregroundStyle(Theme.secondary)
                }
                .listRowBackground(Theme.surface)

                Section {
                    HStack {
                        Text("버전").foregroundStyle(Theme.text)
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(Theme.secondary)
                    }
                    Text("Data: JMdict (CC BY-SA), Tanos JLPT lists")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondary)
                } header: {
                    Text("앱 정보").foregroundStyle(Theme.secondary)
                }
                .listRowBackground(Theme.surface)

                Section {
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("데이터 초기화").foregroundStyle(Theme.red)
                            Spacer()
                        }
                    }
                }
                .listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg.ignoresSafeArea())
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
