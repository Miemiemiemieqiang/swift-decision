import SwiftUI
import SwiftData

struct PendingVerdict: Identifiable {
    let id = UUID()
    let question: String
    let verdict: Verdict
}

struct HomeView: View {
    @State private var question = ""
    @State private var isLoading = false
    @State private var pending: PendingVerdict?
    @State private var errorMessage: String?
    @FocusState private var inputFocused: Bool

    private let service = LLMService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Text("在纠结什么？")
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)

                TextField("比如：要不要去周五那个饭局", text: $question, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(16)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .focused($inputFocused)
                    .submitLabel(.go)
                    .onSubmit(submit)

                Button(action: submit) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("帮我定")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isLoading || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationTitle("快定")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        HistoryView()
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(item: $pending) { item in
                VerdictCardView(question: item.question, initialVerdict: item.verdict) {
                    question = ""
                }
            }
            .alert("出了点问题", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func submit() {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoading else { return }
        inputFocused = false
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                let verdict = try await service.decide(trimmed)
                pending = PendingVerdict(question: trimmed, verdict: verdict)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
