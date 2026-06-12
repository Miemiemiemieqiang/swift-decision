#!/bin/sh
# Downloads the sherpa-onnx iOS frameworks and the bundled Chinese streaming
# ASR model into ThirdParty/ (gitignored). Required once before building.
set -eu

SHERPA_VERSION="v1.13.2"
MODEL_NAME="sherpa-onnx-streaming-zipformer-small-ctc-zh-int8-2025-04-01"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/ThirdParty"

if [ -d "$DEST/sherpa-onnx.xcframework" ] && [ -f "$DEST/asr-model/model.int8.onnx" ]; then
    echo "ThirdParty/ already populated; delete it to force a re-download."
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading sherpa-onnx $SHERPA_VERSION iOS frameworks..."
curl -L --fail -o "$TMP/ios.tar.bz2" \
    "https://github.com/k2-fsa/sherpa-onnx/releases/download/$SHERPA_VERSION/sherpa-onnx-$SHERPA_VERSION-ios-no-tts.tar.bz2"

echo "Downloading ASR model $MODEL_NAME..."
curl -L --fail -o "$TMP/model.tar.bz2" \
    "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/$MODEL_NAME.tar.bz2"

tar xjf "$TMP/ios.tar.bz2" -C "$TMP"
tar xjf "$TMP/model.tar.bz2" -C "$TMP"

mkdir -p "$DEST/asr-model"
rm -rf "$DEST/sherpa-onnx.xcframework" "$DEST/onnxruntime.xcframework"
mv "$TMP/build-ios-no-tts/sherpa-onnx.xcframework" "$DEST/"
mv "$TMP/build-ios-no-tts/ios-onnxruntime/1.17.1/onnxruntime.xcframework" "$DEST/"
cp "$TMP/$MODEL_NAME/model.int8.onnx" \
   "$TMP/$MODEL_NAME/tokens.txt" \
   "$TMP/$MODEL_NAME/bbpe.model" \
   "$DEST/asr-model/"

echo "Done. ThirdParty/ is ready."
