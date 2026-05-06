import SwiftUI
import SwiftData

struct StatsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var todayReviewedCount: Int = 0
    @State private var totalReviewedCount: Int = 0
    @State private var accuracyText: String = "\u{2014}"
    @State private var averageEaseText: String = "\u{2014}"
    @State private var levelProgress: [(level: JLPTLevel, reviewed: Int, total: Int)] = []
    /// F15: local D1/D7 retention preview (DEBUG builds only).
    @State private var retentionSnapshot: RetentionStats.Snapshot? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    scopeBanner
                    summarySection
                    levelSection
                    #if DEBUG
                    if FeatureFlags.eventCounter {
                        debugRetentionSection
                    }
                    #endif
                }
                .padding()
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("통계")
            .onAppear(perform: loadStats)
        }
        .tint(Theme.accent)
    }

    /// F11 (결핍 명시): tells the user upfront that these numbers measure
    /// only the recognition-of-Korean-meaning task — not pronunciation,
    /// listening, context, or production. Light/dark legibility verified
    /// via Theme tokens.
    private var scopeBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(Theme.secondary)
            Text("이 통계는 한국어 뜻 인식만 반영합니다. 문맥규정·용법·읽기·발음 약점은 측정하지 않습니다.")
                .font(.caption)
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .fill(Theme.surface2.opacity(0.6))
        )
        .accessibilityIdentifier("stats.scopeNotice")
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("학습 현황")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            VStack(spacing: 12) {
                statRow(label: "오늘 학습", value: "\(todayReviewedCount)장")
                Divider().background(Theme.separator)
                statRow(label: "총 학습 카드", value: "\(totalReviewedCount)장")
                Divider().background(Theme.separator)
                statRow(label: "정답률", value: accuracyText)
                Divider().background(Theme.separator)
                statRow(label: "평균 ease", value: averageEaseText)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .fill(Theme.surface)
            )
        }
    }

    // MARK: - Level Progress

    private var levelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("레벨별 진행률")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            VStack(spacing: 14) {
                ForEach(levelProgress, id: \.level) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.level.rawValue.uppercased())
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.text)
                            Spacer()
                            Text("\(item.reviewed)/\(item.total)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.secondary)
                                .monospacedDigit()
                        }
                        ProgressView(
                            value: item.total > 0 ? Double(item.reviewed) / Double(item.total) : 0
                        )
                        .tint(Theme.accent)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .fill(Theme.surface)
            )
        }
    }

    // MARK: - Helpers

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(Theme.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text)
                .monospacedDigit()
        }
    }

    // MARK: - F15 debug retention preview (DEBUG only)

    private var debugRetentionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DEBUG · 로컬 리텐션")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            VStack(spacing: 12) {
                if let snap = retentionSnapshot {
                    statRow(label: "고유 학습일", value: "\(snap.totalOpenDays)일")
                    Divider().background(Theme.separator)
                    statRow(
                        label: "D1 리텐션",
                        value: snap.d1Retained.map { $0 ? "유지" : "이탈" } ?? "(미달)"
                    )
                    Divider().background(Theme.separator)
                    statRow(
                        label: "D7 리텐션",
                        value: snap.d7Retained.map { $0 ? "유지" : "이탈" } ?? "(미달)"
                    )
                } else {
                    statRow(label: "이벤트 데이터", value: "없음")
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .fill(Theme.surface)
            )
        }
        .accessibilityIdentifier("stats.debugRetention")
    }

    // MARK: - Data Loading

    private func loadStats() {
        do {
            let allStates = try modelContext.fetch(FetchDescriptor<SRSState>())

            // Today reviewed
            let calendar = Calendar.current
            let startOfToday = calendar.startOfDay(for: Date())
            todayReviewedCount = allStates.filter { state in
                guard let lastReview = state.lastReview else { return false }
                return lastReview >= startOfToday
            }.count

            // Total reviewed (reps > 0 or lapses > 0)
            let reviewed = allStates.filter { $0.reps > 0 || $0.lapses > 0 }
            totalReviewedCount = reviewed.count

            // Accuracy
            let totalReps = allStates.reduce(0) { $0 + $1.reps }
            let totalLapses = allStates.reduce(0) { $0 + $1.lapses }
            let totalAttempts = totalReps + totalLapses
            if totalAttempts > 0 {
                let pct = Double(totalReps) / Double(totalAttempts) * 100
                accuracyText = String(format: "%.1f%%", pct)
            } else {
                accuracyText = "\u{2014}"
            }

            // Average ease
            if !allStates.isEmpty {
                let avgEase = allStates.reduce(0.0) { $0 + $1.ease } / Double(allStates.count)
                averageEaseText = String(format: "%.2f", avgEase)
            } else {
                averageEaseText = "\u{2014}"
            }

            // Level progress
            let reviewedCardIDs = Set(reviewed.map(\.cardID))
            var progress: [(level: JLPTLevel, reviewed: Int, total: Int)] = []
            for level in JLPTLevel.allCases {
                var descriptor = FetchDescriptor<VocabCard>(
                    predicate: #Predicate<VocabCard> { $0.jlptLevel == level.rawValue }
                )
                let cards = try modelContext.fetch(descriptor)
                let totalAtLevel = cards.count
                let reviewedAtLevel = cards.filter { reviewedCardIDs.contains($0.id) }.count
                progress.append((level: level, reviewed: reviewedAtLevel, total: totalAtLevel))
            }
            levelProgress = progress

            // F15: load app-open events and compute retention snapshot.
            #if DEBUG
            if FeatureFlags.eventCounter {
                if let events = try? modelContext.fetch(FetchDescriptor<AppOpenEvent>()) {
                    let dates = events.map { $0.date }
                    retentionSnapshot = RetentionStats.snapshot(eventDates: dates, now: Date())
                }
            }
            #endif

        } catch {
            // Silently handle — stats will show defaults
        }
    }
}
