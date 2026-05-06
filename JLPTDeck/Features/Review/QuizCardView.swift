import SwiftUI

struct QuizCardView: View {
    let question: QuizQuestion
    let selectedIndex: Int?
    let isRevealed: Bool
    let onSelect: (Int) -> Void
    /// F8: optional hide-card callback. When provided, an ellipsis menu in
    /// the top-trailing corner exposes "이 카드 숨기기". Hidden cards drop
    /// out of `todayReviewCards` permanently (until the user clears them).
    var onHideCard: (() -> Void)? = nil

    /// F17: pre-computed pronunciation traps for the current reading.
    /// Cached so the view body doesn't re-run regex on every frame.
    private var traps: Set<PronunciationTraps.Kind> {
        guard FeatureFlags.cardPronunciationTraps else { return [] }
        return PronunciationTraps.detect(reading: question.reading)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let onHideCard {
                HStack {
                    Spacer()
                    Menu {
                        Button(role: .destructive) {
                            onHideCard()
                        } label: {
                            Label("이 카드 숨기기", systemImage: "eye.slash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 22))
                            .foregroundStyle(Theme.secondary)
                            .padding(8)
                    }
                    .accessibilityIdentifier("card.menu")
                    .accessibilityLabel("카드 옵션")
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)
            }
            // Upper half — kanji prompt
            VStack(spacing: 18) {
                Text(question.prompt)
                    .font(.system(size: Theme.kanjiSize, weight: .bold))
                    .minimumScaleFactor(0.3)
                    .lineLimit(2)
                    .foregroundStyle(Theme.text)
                    .accessibilityLabel("문제: \(question.prompt)")
                if isRevealed {
                    Text(question.reading)
                        .font(.system(size: Theme.readingSize, weight: .regular))
                        .foregroundStyle(Theme.secondary)
                        .transition(.opacity)
                        .accessibilityLabel("읽기: \(question.reading)")
                    revealMetaRow
                }
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 16)

            // Lower half — 4 choices
            VStack(spacing: 12) {
                ForEach(0..<question.choices.count, id: \.self) { i in
                    Button {
                        onSelect(i)
                    } label: {
                        Text(question.choices[i])
                            .font(.system(size: Theme.choiceSize, weight: .medium))
                            .tracking(-0.3)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(backgroundFor(i))
                            .foregroundStyle(foregroundFor(i))
                            .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.buttonRadius)
                                    .stroke(borderFor(i), lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isRevealed)
                    .accessibilityLabel(accessibilityLabelFor(i))
                    .accessibilityHint(isRevealed ? "" : "탭하여 선택")
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .animation(.easeInOut(duration: 0.25), value: isRevealed)
    }

    /// G-CardView reveal-time meta row: F12 part-of-speech (left), F16 TTS
    /// button (center), F17 trap badges (right). Each subview is itself
    /// gated — when the corresponding feature flag is OFF or the data is
    /// unavailable, that subview disappears so the row can shrink to a
    /// single element or hide entirely without a layout jump.
    @ViewBuilder
    private var revealMetaRow: some View {
        let trapList = Array(traps).sorted { $0.koreanName < $1.koreanName }
        let showPos = FeatureFlags.cardPartOfSpeech && (question.pos?.isEmpty == false)
        let showTTS = FeatureFlags.cardTTS && SpeechManager.hasJapaneseVoice
        let showTraps = !trapList.isEmpty

        if showPos || showTTS || showTraps {
            HStack(spacing: 10) {
                if showPos, let pos = question.pos {
                    posBadge(pos)
                }
                if showTTS {
                    speakerButton
                }
                if showTraps {
                    ForEach(trapList, id: \.self) { kind in
                        trapBadge(kind)
                    }
                }
            }
            .padding(.top, 8)
            .accessibilityIdentifier("card.revealMeta")
        }
    }

    private func posBadge(_ pos: String) -> some View {
        Text(pos)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Theme.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(Theme.surface2)
            )
            .accessibilityIdentifier("card.pos")
            .accessibilityLabel("품사: \(pos)")
    }

    private var speakerButton: some View {
        Button {
            SpeechManager.speak(question.prompt)
        } label: {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 14))
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(Theme.accent.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("card.tts")
        .accessibilityLabel("발음 듣기")
    }

    private func trapBadge(_ kind: PronunciationTraps.Kind) -> some View {
        let icon: String = {
            switch kind {
            case .longVowel: return "arrow.right.to.line"
            case .smallTsu:  return "pause.fill"
            case .moraN:     return "n.circle.fill"
            }
        }()
        return HStack(spacing: 4) {
            Image(systemName: icon)
            Text(kind.koreanName)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Theme.orange)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Theme.orange.opacity(0.12))
        )
        .accessibilityIdentifier("card.trap.\(kind.koreanName)")
        .accessibilityLabel(kind.koreanTooltip)
    }

    private func backgroundFor(_ i: Int) -> Color {
        guard isRevealed else { return Theme.surface2 }
        if i == question.correctIndex { return Theme.greenFill }
        if i == selectedIndex { return Theme.redFill }
        return Theme.surface2.opacity(0.5)
    }

    private func foregroundFor(_ i: Int) -> Color {
        guard isRevealed else { return Theme.text }
        if i == question.correctIndex || i == selectedIndex { return .white }
        return Theme.secondary
    }

    private func borderFor(_ i: Int) -> Color {
        guard isRevealed else { return Theme.accent.opacity(0.4) }
        return .clear
    }

    private func accessibilityLabelFor(_ i: Int) -> String {
        let choice = question.choices[i]
        guard isRevealed else { return "선택지 \(i + 1): \(choice)" }
        if i == question.correctIndex { return "\(choice), 정답" }
        if i == selectedIndex { return "\(choice), 오답" }
        return choice
    }
}
