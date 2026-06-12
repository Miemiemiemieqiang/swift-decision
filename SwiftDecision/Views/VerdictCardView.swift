import SwiftUI
import SwiftData

struct VerdictCardView: View {
    let question: String
    let initialVerdict: Verdict
    var onSealed: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var current: Verdict
    @State private var hasRetried = false
    @State private var isRetrying = false
    @State private var isSealed = false
    @State private var errorMessage: String?

    private let service = LLMService()

    init(question: String, initialVerdict: Verdict, onSealed: @escaping () -> Void) {
        self.question = question
        self.initialVerdict = initialVerdict
        self.onSealed = onSealed
        _current = State(initialValue: initialVerdict)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                Text(question)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.top, 32)

                Spacer()

                if current.trivial {
                    Label("这事不值得想", systemImage: "circle.dotted")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(current.verdict)
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)

                Text(current.reason)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                DisclosureGroup("为什么这么判断") {
                    Text(current.detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                }
                .font(.callout)
                .padding(.horizontal, 8)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button(action: seal) {
                        Text("就这么定")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(action: retry) {
                        if isRetrying {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(hasRetried ? "角度只能换一次" : "换个角度")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(hasRetried || isRetrying)
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 28)
            .disabled(isSealed)

            if isSealed {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.green)
                    Text("已定，不再想了")
                        .font(.headline)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .interactiveDismissDisabled(isRetrying)
    }

    private func seal() {
        let decision = Decision(
            question: question,
            verdict: current.verdict,
            reason: current.reason,
            detail: current.detail,
            isTrivial: current.trivial
        )
        modelContext.insert(decision)

        withAnimation(.spring(duration: 0.35)) {
            isSealed = true
        }
        Task {
            try? await Task.sleep(for: .seconds(0.9))
            onSealed()
            dismiss()
        }
    }

    private func retry() {
        guard !hasRetried, !isRetrying else { return }
        isRetrying = true
        errorMessage = nil
        Task {
            defer { isRetrying = false }
            do {
                let next = try await service.decide(question, anotherAngleFrom: current)
                withAnimation {
                    current = next
                    hasRetried = true
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
