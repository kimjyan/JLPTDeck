import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(UserSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext

    @State private var showResetConfirmation = false
    @State private var showResetComplete = false
    // F13: data export / import state
    @State private var exportDocument: JSONFileDocument? = nil
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var ioMessage: String? = nil
    @State private var showIOAlert = false

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
                    HStack {
                        Text("데이터셋").foregroundStyle(Theme.text)
                        Spacer()
                        Text(datasetVersion)
                            .foregroundStyle(Theme.secondary)
                            .monospacedDigit()
                    }
                    .accessibilityIdentifier("settings.datasetVersion")
                } header: {
                    Text("앱 정보").foregroundStyle(Theme.secondary)
                } footer: {
                    // F5 (카피 정정): "한국어 뜻 인식 단어장"으로 한정.
                    // F11 (결핍 명시): 측정 범위 1줄 명시.
                    Text("한국어 뜻 인식 단어장 (4지선다). 이 앱은 한국어 뜻 인식만 측정합니다 — 문맥규정·용법·읽기·발음 약점은 측정 대상이 아닙니다.")
                        .font(.caption)
                        .foregroundStyle(Theme.secondary)
                        .accessibilityIdentifier("settings.scopeNotice")
                }
                .listRowBackground(Theme.surface)

                // F6 (attribution 강화): EDRDG/JMdict + Tanos + JLPT 비공식 명시.
                Section {
                    AttributionRow(
                        title: "JMdict",
                        subtitle: "Electronic Dictionary Research and Development Group (EDRDG) — CC BY-SA 4.0",
                        urlString: "https://www.edrdg.org/jmdict/edict_doc.html"
                    )
                    AttributionRow(
                        title: "JLPT 어휘 목록",
                        subtitle: "Tanos.co.uk (Jonathan Waller) — JLPT level lists, 비공식 추정",
                        urlString: "https://www.tanos.co.uk/jlpt/"
                    )
                    Text("JLPT 레벨 분류는 비공식 추정이며 일본국제교류기금(Japan Foundation) 공식 출제 기준이 아닙니다.")
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiary)
                        .accessibilityIdentifier("settings.jlptUnofficial")
                } header: {
                    Text("데이터 출처 / 라이선스").foregroundStyle(Theme.secondary)
                }
                .listRowBackground(Theme.surface)

                if FeatureFlags.dataExport {
                    Section {
                        Button {
                            performExport()
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("백업 내보내기").foregroundStyle(Theme.text)
                            }
                        }
                        .accessibilityIdentifier("settings.export")

                        Button {
                            showImporter = true
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("백업 가져오기").foregroundStyle(Theme.text)
                            }
                        }
                        .accessibilityIdentifier("settings.import")
                    } header: {
                        Text("데이터").foregroundStyle(Theme.secondary)
                    } footer: {
                        Text("학습 기록(SRSState)과 카드 숨김 정보를 JSON 파일로 저장/복원합니다. 다른 카드 풀(번들)은 영향받지 않습니다.")
                            .font(.caption)
                            .foregroundStyle(Theme.secondary)
                    }
                    .listRowBackground(Theme.surface)
                }

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
            .fileExporter(
                isPresented: $showExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: defaultBackupFilename()
            ) { result in
                switch result {
                case .success(let url):
                    ioMessage = "내보내기 완료: \(url.lastPathComponent)"
                case .failure(let error):
                    ioMessage = "내보내기 실패: \(error.localizedDescription)"
                }
                showIOAlert = true
                exportDocument = nil
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json]
            ) { result in
                handleImport(result: result)
            }
            .alert("백업", isPresented: $showIOAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(ioMessage ?? "")
            }
        }
    }

    private func defaultBackupFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return "jlptdeck-backup-\(formatter.string(from: Date())).json"
    }

    private func performExport() {
        do {
            let repo = SwiftDataLocalRepository(modelContext: modelContext)
            let snapshot = try repo.exportSnapshot()
            let payload = ExportPayload(
                schemaVersion: ExportPayloadCodec.currentSchemaVersion,
                exportedAtUnix: Date().timeIntervalSince1970,
                appVersion: appVersion,
                srsStates: snapshot.srs,
                userOverrides: snapshot.overrides
            )
            let data = try ExportPayloadCodec.encode(payload)
            exportDocument = JSONFileDocument(data: data)
            showExporter = true
        } catch {
            ioMessage = "내보내기 실패: \(error.localizedDescription)"
            showIOAlert = true
        }
    }

    private func handleImport(result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            ioMessage = "가져오기 실패: \(error.localizedDescription)"
            showIOAlert = true
        case .success(let url):
            // Sandbox: security-scoped resource access required.
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer { if didStartAccessing { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let payload = try ExportPayloadCodec.decode(data)
                guard payload.schemaVersion == ExportPayloadCodec.currentSchemaVersion else {
                    ioMessage = "지원하지 않는 백업 버전: v\(payload.schemaVersion)"
                    showIOAlert = true
                    return
                }
                let repo = SwiftDataLocalRepository(modelContext: modelContext)
                try repo.importSnapshot(srs: payload.srsStates, overrides: payload.userOverrides)
                ioMessage = "가져오기 완료: SRS \(payload.srsStates.count)건, 숨김 \(payload.userOverrides.count)건"
                showIOAlert = true
            } catch {
                ioMessage = "가져오기 실패: \(error.localizedDescription)"
                showIOAlert = true
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    /// F6 (attribution): dataset version surfaced from a build-time
    /// constant. Mirrors the JMdict bundled JSON's pull date — when the
    /// data is refreshed, bump `JLPTDeckMetadata.datasetVersion` in one
    /// place and this row updates automatically.
    private var datasetVersion: String {
        JLPTDeckMetadata.datasetVersion
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
