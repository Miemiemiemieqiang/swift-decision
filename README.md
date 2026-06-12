# 快定 SwiftDecision

杀掉决策疲劳的 iOS 小工具：把正在纠结的事打出来（或按住麦克风说出来），LLM 直接给一个可执行的裁决——不是利弊分析——然后「就这么定」，停止反刍。

- SwiftUI + SwiftData，iOS 17+
- 语音输入用 [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) 在本机流式识别，音频不上传
- 请求从设备直连你自己配置的 OpenAI 兼容接口，没有任何中间后端

## 构建

```sh
git clone git@github.com:Miemiemiemieqiang/swift-decision.git
cd swift-decision
./Scripts/fetch_asr_deps.sh   # 下载语音识别框架和模型到 ThirdParty/（约 91MB，只需一次）
open SwiftDecision.xcodeproj  # 然后 Cmd+R
```

`ThirdParty/` 是二进制依赖，不进 git；漏跑脚本时构建会直接报错提示。

## 配置

运行后在「设置」里填一个 OpenAI 兼容的 `/chat/completions` 接口地址、模型名和 API Key（Key 存 Keychain）。
