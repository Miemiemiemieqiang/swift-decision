#!/bin/sh
# Downloads the sherpa-onnx iOS frameworks and the bundled bilingual (zh-en)
# streaming ASR model into ThirdParty/ (gitignored). Required once before building.
set -eu

SHERPA_VERSION="v1.13.2"
# Streaming zipformer transducer, Chinese + English with punctuation, int8-quantized.
MODEL_NAME="sherpa-onnx-x-asr-480ms-streaming-zipformer-transducer-zh-en-punct-int8-2026-06-05"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/ThirdParty"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [ -d "$DEST/sherpa-onnx.xcframework" ] && [ -d "$DEST/onnxruntime.xcframework" ]; then
    echo "sherpa-onnx frameworks already present; skipping."
else
    echo "Downloading sherpa-onnx $SHERPA_VERSION iOS frameworks..."
    curl -L --fail -o "$TMP/ios.tar.bz2" \
        "https://github.com/k2-fsa/sherpa-onnx/releases/download/$SHERPA_VERSION/sherpa-onnx-$SHERPA_VERSION-ios-no-tts.tar.bz2"
    tar xjf "$TMP/ios.tar.bz2" -C "$TMP"
    rm -rf "$DEST/sherpa-onnx.xcframework" "$DEST/onnxruntime.xcframework"
    mkdir -p "$DEST"
    mv "$TMP/build-ios-no-tts/sherpa-onnx.xcframework" "$DEST/"
    mv "$TMP/build-ios-no-tts/ios-onnxruntime/1.17.1/onnxruntime.xcframework" "$DEST/"
fi

if [ -f "$DEST/asr-model/encoder.int8.onnx" ]; then
    echo "ASR model already present; delete ThirdParty/asr-model to force a re-download."
else
    echo "Downloading ASR model $MODEL_NAME..."
    curl -L --fail -o "$TMP/model.tar.bz2" \
        "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/$MODEL_NAME.tar.bz2"
    tar xjf "$TMP/model.tar.bz2" -C "$TMP"
    rm -rf "$DEST/asr-model"
    mkdir -p "$DEST/asr-model"
    cp "$TMP/$MODEL_NAME/encoder.int8.onnx" \
       "$TMP/$MODEL_NAME/decoder.onnx" \
       "$TMP/$MODEL_NAME/joiner.int8.onnx" \
       "$TMP/$MODEL_NAME/tokens.txt" \
       "$TMP/$MODEL_NAME/bpe.model" \
       "$DEST/asr-model/"
fi

echo "Done. ThirdParty/ is ready."
