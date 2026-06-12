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

    @State private var speech = SpeechRecognizer()
    @State private var isHoldingMic = false
    @State private var questionBeforeVoice = ""
    @State private var voiceStartTask: Task<Void, Never>?

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
            .safeAreaInset(edge: .bottom) {
                micBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }
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
            .task { speech.prewarm() }
            .onChange(of: speech.transcript) { _, text in
                guard isHoldingMic || speech.isRecording else { return }
                question = questionBeforeVoice + text
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

    private var micBar: some View {
        HStack(spacing: 8) {
            Image(systemName: speech.isRecording ? "waveform" : "mic.fill")
            Text(speech.isRecording ? "在听，松开就好" : "按住说话，松开上字")
        }
        .font(.headline)
        .foregroundStyle(speech.isRecording ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(
            speech.isRecording ? AnyShapeStyle(Color.red) : AnyShapeStyle(.thinMaterial),
            in: Capsule()
        )
        .scaleEffect(isHoldingMic ? 1.03 : 1)
        .animation(.snappy, value: isHoldingMic)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in beginVoiceInput() }
                .onEnded { _ in endVoiceInput() }
        )
    }

    private func beginVoiceInput() {
        guard !isHoldingMic else { return }
        isHoldingMic = true
        inputFocused = false
        questionBeforeVoice = question
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        voiceStartTask = Task {
            do {
                try await speech.start()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func endVoiceInput() {
        guard isHoldingMic else { return }
        isHoldingMic = false
        Task {
            // 等 start() 真正完成再停，避免快速点按时引擎停不下来。
            await voiceStartTask?.value
            let text = await speech.stop()
            question = questionBeforeVoice + text
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
