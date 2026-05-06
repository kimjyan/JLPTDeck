import SwiftUI

struct SessionCompleteView: View {
    let completedCount: Int
    /// F10: first-attempt correct count. After F3, `correctCount` in the
    /// reducer is incremented only on the first attempt — retries increment
    /// `relearnedCount` instead. Naming this "first-attempt" makes the
    /// distinction explicit at the view layer.
    var firstAttemptCorrect: Int = 0
    /// F10: first-attempt wrong count. Same source as the reducer's
    /// `wrongCount` (already first-attempt only — retries don't touch it).
    var firstAttemptWrong: Int = 0
    /// F10: number of cards that were wrong on the first attempt and then
    /// correct on the in-session retry. Display-only; SRS uses the original
    /// `.again` grade for scheduling.
    var relearnedCount: Int = 0
    /// F4: number of SRS upserts that failed during the session and were
    /// queued for retry on the next session boundary. Surfaced here so the
    /// user knows their progress was captured even though the disk write
    /// is deferred. Zero hides the row.
    var failedUpsertCount: Int = 0
    /// F8: number of `setHidden` persistence failures. Card vanished from
    /// the in-memory queue but failed to persist — will reappear next
    /// session. Zero hides the row.
    var hideFailedCount: Int = 0
    /// F9: number of first-attempt correct answers that took longer than
    /// the slow threshold (likely-guess heuristic). Display-only — SM-2
    /// scheduling is unaffected. Zero hides the row.
    var slowFirstAttemptCount: Int = 0
    /// F7: cards that will be due tomorrow (best-effort snapshot taken
    /// when the session completed). nil hides the row.
    var nextDayDueCount: Int? = nil
    /// F7: streak count AFTER today's session is counted. Used for
    /// motivational copy ("오늘 학습으로 N일 연속 ✓"). nil hides the row.
    var streakAfterToday: Int? = nil
    let onDone: () -> Void

    private var firstAttemptTotal: Int { firstAttemptCorrect + firstAttemptWrong }

    private var firstAttemptPercentage: Int {
        guard firstAttemptTotal > 0 else { return 0 }
        let pct = Double(firstAttemptCorrect) / Double(firstAttemptTotal) * 100
        return Int(pct.rounded())
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.green)
                Text("오늘 \(completedCount)개 완료!")
                    .font(.system(size: 30, weight: .bold))
                    .tracking(-0.8)
                    .foregroundStyle(Theme.text)
            }
            if firstAttemptTotal > 0 {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        statChip(
                            label: "첫 시도 정답",
                            count: firstAttemptCorrect,
                            icon: "checkmark.circle.fill",
                            color: Theme.green
                        )
                        statChip(
                            label: "첫 시도 오답",
                            count: firstAttemptWrong,
                            icon: "xmark.circle.fill",
                            color: Theme.red
                        )
                    }
                    HStack(spacing: 8) {
                        Text("첫 시도 정답률")
                            .foregroundStyle(Theme.secondary)
                        Text("\(firstAttemptPercentage)%")
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.text)
                            .monospacedDigit()
                        if relearnedCount > 0 {
                            Text("·")
                                .foregroundStyle(Theme.tertiary)
                            Text("회복 \(relearnedCount)개")
                                .foregroundStyle(Theme.secondary)
                        }
                    }
                    .font(.system(size: 13))
                    .accessibilityIdentifier("session.firstAttemptSummary")
                }
                .padding(.horizontal, 32)
            }
            if failedUpsertCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .foregroundStyle(Theme.orange)
                    Text("저장 재시도 예정 \(failedUpsertCount)건")
                        .foregroundStyle(Theme.secondary)
                }
                .font(.system(size: 13))
                .accessibilityIdentifier("session.failedUpsertNotice")
            }
            if hideFailedCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.orange)
                    Text("숨김 저장 실패 \(hideFailedCount)건 — 다음에 다시 보일 수 있음")
                        .foregroundStyle(Theme.secondary)
                }
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("session.hideFailedNotice")
            }
            if slowFirstAttemptCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "hourglass")
                        .foregroundStyle(Theme.orange)
                    Text("느린 정답 \(slowFirstAttemptCount)건 (\(LatencyPolicy.slowThresholdMs / 1000)초 이상)")
                        .foregroundStyle(Theme.secondary)
                }
                .font(.system(size: 13))
                .accessibilityIdentifier("session.slowFirstAttemptNotice")
            }
            if nextDayDueCount != nil || streakAfterToday != nil {
                nextSessionPreview
            }
            Text("수고하셨습니다.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.secondary)
            Spacer()
            Button {
                onDone()
            } label: {
                Text("홈으로")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.buttonRadius)
                            .fill(Theme.accent)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
            .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg.ignoresSafeArea())
    }

    /// F7: next-session motivation block. Two rows — one factual ("내일
    /// N개 복습 예정") and one social/identity ("오늘 학습으로 N일 연속
    /// 달성"). Streak block also nudges tomorrow's session ("내일도 학습
    /// 시 +1일") when the count is positive — keeping the message
    /// future-oriented per FINAL.md F7 ("사전 동기").
    @ViewBuilder
    private var nextSessionPreview: some View {
        VStack(spacing: 8) {
            if let count = nextDayDueCount {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(Theme.accent)
                    Text(count == 0
                         ? "내일은 복습 예정 카드가 없어요"
                         : "내일 복습 예정 \(count)개")
                        .foregroundStyle(Theme.text)
                }
                .font(.system(size: 14, weight: .medium))
                .accessibilityIdentifier("session.nextDayDue")
            }
            if let streak = streakAfterToday {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Theme.orange)
                    if streak <= 1 {
                        Text("오늘 학습으로 \(streak)일 시작! 내일도 학습하면 \(streak + 1)일 연속")
                            .foregroundStyle(Theme.secondary)
                    } else {
                        Text("\(streak)일 연속 학습 ✓ — 내일도 학습 시 \(streak + 1)일, 거르면 끊김")
                            .foregroundStyle(Theme.secondary)
                    }
                }
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("session.streakCoaching")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .fill(Theme.surface)
        )
        .padding(.horizontal, 32)
    }

    private func statChip(label: String, count: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(label).foregroundStyle(Theme.secondary)
            Text("\(count)")
                .fontWeight(.semibold)
                .foregroundStyle(Theme.text)
                .monospacedDigit()
        }
        .font(.system(size: 14, weight: .medium))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .fill(Theme.surface)
        )
    }
}
