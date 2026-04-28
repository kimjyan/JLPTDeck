import SwiftUI

struct QuizCardView: View {
    let question: QuizQuestion
    let selectedIndex: Int?
    let isRevealed: Bool
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Top: prompt
            VStack(spacing: 12) {
                Text(question.prompt)
                    .font(.system(size: 80, weight: .bold))
                    .minimumScaleFactor(0.3)
                    .lineLimit(2)
                    .accessibilityLabel("문제: \(question.prompt)")
                if isRevealed {
                    Text(question.reading)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                        .accessibilityLabel("읽기: \(question.reading)")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)

            // Bottom: 4 choices
            VStack(spacing: 12) {
                ForEach(0..<question.choices.count, id: \.self) { i in
                    Button {
                        onSelect(i)
                    } label: {
                        Text(question.choices[i])
                            .font(.title3)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(backgroundFor(i))
                            .foregroundStyle(foregroundFor(i))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(borderFor(i), lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isRevealed)
                    .accessibilityLabel(accessibilityLabelFor(i))
                    .accessibilityHint(isRevealed ? "" : "탭하여 선택")
                }
            }
            .padding(.horizontal)
        }
        .animation(.easeInOut(duration: 0.25), value: isRevealed)
    }

    private func backgroundFor(_ i: Int) -> Color {
        guard isRevealed else { return Color(.secondarySystemBackground) }
        if i == question.correctIndex { return .green.opacity(0.85) }
        if i == selectedIndex { return .red.opacity(0.85) }
        return Color(.secondarySystemBackground).opacity(0.5)
    }

    private func foregroundFor(_ i: Int) -> Color {
        guard isRevealed else { return .primary }
        if i == question.correctIndex || i == selectedIndex { return .white }
        return .secondary
    }

    private func borderFor(_ i: Int) -> Color {
        guard isRevealed else { return .blue.opacity(0.4) }
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
