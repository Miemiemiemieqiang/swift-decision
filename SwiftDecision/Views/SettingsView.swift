import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var decisions: [Decision]
    @State private var baseURL: String = LLMConfig.baseURL
    @State private var apiKey: String = KeychainHelper.loadAPIKey() ?? ""
    @State private var model: String = LLMConfig.model
    @State private var saved = false
    @State private var confirmingClear = false

    private var canSave: Bool {
        !baseURL.trimmingCharacters(in: .whitespaces).isEmpty
            && !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
            && !model.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            Section {
                TextField("https://api.openai.com/v1", text: $baseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            } header: {
                Text("Base URL")
            } footer: {
                Text("任意 OpenAI 兼容服务的地址，填到 /v1 这一级，例如 https://api.openai.com/v1。")
            }

            Section("API Key") {
                SecureField("sk-...", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section {
                TextField("gpt-4o / deepseek-chat / ...", text: $model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("模型名")
            }

            Section {
                Button(saved ? "已保存" : "保存") {
                    LLMConfig.baseURL = baseURL.trimmingCharacters(in: .whitespaces)
                    LLMConfig.model = model.trimmingCharacters(in: .whitespaces)
                    KeychainHelper.saveAPIKey(apiKey.trimmingCharacters(in: .whitespaces))
                    saved = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        saved = false
                    }
                }
                .disabled(!canSave)
            } footer: {
                Text("API Key 保存在本机钥匙串里，所有请求从手机直连你配置的服务，不经过任何中间服务器。")
            }

            Section {
                Button("清空已定记录", role: .destructive) {
                    confirmingClear = true
                }
                .disabled(decisions.isEmpty)
                .confirmationDialog(
                    "清空全部 \(decisions.count) 条记录？",
                    isPresented: $confirmingClear,
                    titleVisibility: .visible
                ) {
                    Button("清空，不留痕迹", role: .destructive) {
                        try? modelContext.delete(model: Decision.self)
                    }
                } message: {
                    Text("删了就找不回来了。")
                }
            } footer: {
                Text("删掉所有定下来的事，不可恢复。")
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}
