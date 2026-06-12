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
    @State private var willCancelVoice = false
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
            .contentShape(Rectangle())
            .onTapGesture { inputFocused = false }
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

    /// 上滑超过这个距离进入「松开取消」状态，松手即丢弃本次语音。
    private static let voiceCancelDistance: CGFloat = 60

    // 视觉状态全部跟随 isHoldingMic（按下瞬间生效），不等引擎真正启动，
    // 否则权限检查 + 激活音频会话 + 起引擎的几百毫秒会让按下显得「顿一下」。
    private var micBar: some View {
        VStack(spacing: 10) {
            if isHoldingMic {
                Text(willCancelVoice ? "松开手指，取消这次输入" : "上滑取消")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }

            HStack(spacing: 8) {
                Image(systemName: micBarIcon)
                Text(micBarTitle)
            }
            .font(.headline)
            .foregroundStyle(isHoldingMic ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(micBarBackground, in: Capsule())
            .scaleEffect(isHoldingMic && !willCancelVoice ? 1.03 : 1)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        beginVoiceInput()
                        setWillCancelVoice(value.translation.height < -Self.voiceCancelDistance)
                    }
                    .onEnded { _ in endVoiceInput() }
            )
        }
        .animation(.snappy, value: isHoldingMic)
        .animation(.snappy, value: willCancelVoice)
    }

    private var micBarIcon: String {
        guard isHoldingMic else { return "mic.fill" }
        return willCancelVoice ? "xmark" : "waveform"
    }

    private var micBarTitle: LocalizedStringKey {
        guard isHoldingMic else { return "按住说话，松开上字" }
        return willCancelVoice ? "松开取消" : "在听，松开就好"
    }

    private var micBarBackground: AnyShapeStyle {
        guard isHoldingMic else { return AnyShapeStyle(.thinMaterial) }
        return willCancelVoice ? AnyShapeStyle(Color(.systemGray2)) : AnyShapeStyle(Color.red)
    }

    private func beginVoiceInput() {
        guard !isHoldingMic else { return }
        isHoldingMic = true
        willCancelVoice = false
        inputFocused = false
        questionBeforeVoice = question
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        voiceStartTask = Task {
            do {
                try await speech.start()
            } catch {
                errorMessage = error.localizedDescription
                // 启动失败时把条退回空闲态，不再等用户松手。
                isHoldingMic = false
                willCancelVoice = false
            }
        }
    }

    private func setWillCancelVoice(_ cancelling: Bool) {
        guard isHoldingMic, willCancelVoice != cancelling else { return }
        willCancelVoice = cancelling
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    private func endVoiceInput() {
        guard isHoldingMic else { return }
        isHoldingMic = false
        let cancelled = willCancelVoice
        willCancelVoice = false
        Task {
            // 等 start() 真正完成再停，避免快速点按时引擎停不下来。
            await voiceStartTask?.value
            let text = await speech.stop()
            if cancelled {
                question = questionBeforeVoice
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            } else {
                question = questionBeforeVoice + text
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
