import SwiftUI

struct QuizCardView: View {
    let question: QuizQuestion
    let selectedIndex: Int?
    let isRevealed: Bool
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
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
