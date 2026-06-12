import SwiftUI

struct SettingsView: View {
    @State private var baseURL: String = LLMConfig.baseURL
    @State private var apiKey: String = KeychainHelper.loadAPIKey() ?? ""
    @State private var model: String = LLMConfig.model
    @State private var saved = false

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
                Text("任意 OpenAI 兼容服务的地址，填到 /v1 这一级，例如 https://api.deepseek.com/v1。")
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
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}
