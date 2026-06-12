import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \Decision.createdAt, order: .reverse) private var decisions: [Decision]

    var body: some View {
        Group {
            if decisions.isEmpty {
                ContentUnavailableView(
                    "还没有决定过什么",
                    systemImage: "checkmark.seal",
                    description: Text("定下来的事会记在这里，只回看，不重新纠结。")
                )
            } else {
                List(decisions) { decision in
                    DecisionRow(decision: decision)
                }
            }
        }
        .navigationTitle("已定")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DecisionRow: View {
    @Bindable var decision: Decision

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(decision.verdict)
                    .font(.headline)
                Spacer()
                Text(decision.createdAt, format: .dateTime.month().day())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(decision.question)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 16) {
                Text("结果还行吗？")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Button {
                    decision.feedback = decision.feedback == 1 ? 0 : 1
                } label: {
                    Image(systemName: decision.feedback == 1 ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .foregroundStyle(decision.feedback == 1 ? .green : .secondary)
                }
                .buttonStyle(.plain)
                Button {
                    decision.feedback = decision.feedback == -1 ? 0 : -1
                } label: {
                    Image(systemName: decision.feedback == -1 ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        .foregroundStyle(decision.feedback == -1 ? .orange : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}
