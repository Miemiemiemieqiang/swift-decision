import AVFoundation
import Observation

/// 端侧流式中英双语语音识别，基于 sherpa-onnx。音频只在本机处理，不会上传。
///
/// 模型文件打包在 app bundle 的 `asr-model/` 目录里
/// （由 Scripts/fetch_asr_deps.sh 下载到 ThirdParty/asr-model）。
@Observable
final class SpeechRecognizer {
    /// 当前会话的实时识别结果（边说边更新）。
    private(set) var transcript = ""
    private(set) var isRecording = false

    enum SpeechError: LocalizedError {
        case permissionDenied
        case modelMissing

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return String(localized: "没有麦克风权限。去系统设置里打开，再按住说话。")
            case .modelMissing:
                return String(localized: "语音模型没有打包进 App。先运行 Scripts/fetch_asr_deps.sh 再重新构建。")
            }
        }
    }

    private let engine = AVAudioEngine()
    private let queue = DispatchQueue(label: "com.miemieqiang.SwiftDecision.asr")
    /// 只在 `queue` 上创建和访问。
    private var recognizer: SherpaOnnxRecognizer?

    /// 后台先加载模型，让第一次按住说话不卡顿。
    func prewarm() {
        queue.async { _ = self.loadedRecognizer() }
    }

    func start() async throws {
        guard !isRecording else { return }
        guard await AVAudioApplication.requestRecordPermission() else {
            throw SpeechError.permissionDenied
        }
        guard Bundle.main.url(forResource: "asr-model", withExtension: nil) != nil else {
            throw SpeechError.modelMissing
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0,
            let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32, sampleRate: 16000,
                channels: 1, interleaved: false),
            let converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        else {
            throw SpeechError.permissionDenied
        }

        transcript = ""
        queue.async { self.loadedRecognizer()?.reset() }

        // 上一次 engine.start() 失败时 tap 会残留在 bus 上，重复 install 会直接 abort。
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            let samples = Self.resample(buffer, with: converter, to: targetFormat)
            guard !samples.isEmpty else { return }
            self.queue.async { self.feed(samples) }
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            throw error
        }
        isRecording = true
    }

    /// 停止采集，返回本次会话的最终识别文本。
    func stop() async -> String {
        guard isRecording else { return transcript }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        return await withCheckedContinuation { continuation in
            queue.async {
                var text = ""
                if let recognizer = self.recognizer {
                    // 补一段静音把特征窗口里残留的尾音冲出来，再取最终结果。
                    recognizer.acceptWaveform(samples: [Float](repeating: 0, count: 8000))
                    while recognizer.isReady() { recognizer.decode() }
                    text = Self.tidy(recognizer.getResult().text)
                    recognizer.reset()
                }
                DispatchQueue.main.async {
                    self.transcript = text
                    continuation.resume(returning: text)
                }
            }
        }
    }

    /// 只在 `queue` 上调用。
    private func loadedRecognizer() -> SherpaOnnxRecognizer? {
        if let recognizer { return recognizer }
        guard let modelDir = Bundle.main.url(forResource: "asr-model", withExtension: nil) else {
            return nil
        }
        let modelConfig = sherpaOnnxOnlineModelConfig(
            tokens: modelDir.appendingPathComponent("tokens.txt").path,
            transducer: sherpaOnnxOnlineTransducerModelConfig(
                encoder: modelDir.appendingPathComponent("encoder.int8.onnx").path,
                decoder: modelDir.appendingPathComponent("decoder.onnx").path,
                joiner: modelDir.appendingPathComponent("joiner.int8.onnx").path),
            numThreads: 2
        )
        var config = sherpaOnnxOnlineRecognizerConfig(
            featConfig: sherpaOnnxFeatureConfig(),
            modelConfig: modelConfig
        )
        let created = SherpaOnnxRecognizer(config: &config)
        recognizer = created
        return created
    }

    /// 只在 `queue` 上调用。
    private func feed(_ samples: [Float]) {
        guard let recognizer = loadedRecognizer() else { return }
        recognizer.acceptWaveform(samples: samples)
        var decoded = false
        while recognizer.isReady() {
            recognizer.decode()
            decoded = true
        }
        guard decoded else { return }
        let text = Self.tidy(recognizer.getResult().text)
        DispatchQueue.main.async { self.transcript = text }
    }

    /// 双语模型按 token 输出，中文字符之间会带空格；收掉它们，但保留英文单词间的空格。
    private static func tidy(_ text: String) -> String {
        let cjk = "[\\p{Han}，。？！、：；（）「」『』]"
        return text
            .replacingOccurrences(
                of: "(?<=\(cjk))\\s+(?=\(cjk))", with: "", options: .regularExpression
            )
            .trimmingCharacters(in: .whitespaces)
    }

    private static func resample(
        _ buffer: AVAudioPCMBuffer, with converter: AVAudioConverter, to format: AVAudioFormat
    ) -> [Float] {
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            return []
        }
        var consumed = false
        converter.convert(to: output, error: nil) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        guard let channel = output.floatChannelData, output.frameLength > 0 else { return [] }
        return Array(UnsafeBufferPointer(start: channel[0], count: Int(output.frameLength)))
    }
}
