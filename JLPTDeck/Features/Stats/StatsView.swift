import SwiftUI
import SwiftData

struct StatsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var todayReviewedCount: Int = 0
    @State private var totalReviewedCount: Int = 0
    @State private var accuracyText: String = "\u{2014}"
    @State private var averageEaseText: String = "\u{2014}"
    @State private var levelProgress: [(level: JLPTLevel, reviewed: Int, total: Int)] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summarySection
                    levelSection
                }
                .padding()
            }
            .navigationTitle("통계")
            .onAppear(perform: loadStats)
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        GroupBox("학습 현황") {
            VStack(spacing: 12) {
                statRow(label: "오늘 학습", value: "\(todayReviewedCount)장")
                Divider()
                statRow(label: "총 학습 카드", value: "\(totalReviewedCount)장")
                Divider()
                statRow(label: "정답률", value: accuracyText)
                Divider()
                statRow(label: "평균 ease", value: averageEaseText)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Level Progress

    private var levelSection: some View {
        GroupBox("레벨별 진행률") {
            VStack(spacing: 12) {
                ForEach(levelProgress, id: \.level) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.level.rawValue.uppercased())
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(item.reviewed)/\(item.total)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        ProgressView(
                            value: item.total > 0 ? Double(item.reviewed) / Double(item.total) : 0
                        )
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Helpers

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
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
                descriptor.propertiesToFetch = [\.id]
                let cards = try modelContext.fetch(descriptor)
                let totalAtLevel = cards.count
                let reviewedAtLevel = cards.filter { reviewedCardIDs.contains($0.id) }.count
                progress.append((level: level, reviewed: reviewedAtLevel, total: totalAtLevel))
            }
            levelProgress = progress

        } catch {
            // Silently handle — stats will show defaults
        }
    }
}
