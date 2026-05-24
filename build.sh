#!/usr/bin/env bash
# 构建脚本：用 SwiftPM 编译可执行文件，然后手工组装一个标准 .app bundle。
# 用法：./build.sh [debug|release]   默认 release
set -euo pipefail

CONFIG="${1:-release}"
APP_NAME="ControlDisplay"
BUNDLE_ID="com.local.ControlDisplay"
BUILD_DIR=".build/${CONFIG}"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"

echo "==> swift build (${CONFIG})"
swift build -c "${CONFIG}"

EXEC_PATH="${BUILD_DIR}/${APP_NAME}"
if [[ ! -f "${EXEC_PATH}" ]]; then
    echo "找不到可执行文件 ${EXEC_PATH}" >&2
    exit 1
fi

echo "==> 组装 .app bundle"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${EXEC_PATH}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
cp Resources/Info.plist "${APP_DIR}/Contents/Info.plist"
cp Resources/AppIcon.icns "${APP_DIR}/Contents/Resources/AppIcon.icns"
if [[ -f "Resources/AppIcon.icns" ]]; then
    cp Resources/AppIcon.icns "${APP_DIR}/Contents/Resources/AppIcon.icns"
fi

# 给 .app 一个 ad-hoc 签名，否则 macOS 在首次启动时可能直接拦掉。
# 真正分发还是要换成正式开发者证书。
echo "==> ad-hoc 签名"
codesign --force --deep --sign - "${APP_DIR}"

echo ""
echo "✅ 构建完成：${APP_DIR}"
echo "运行：open '${APP_DIR}'"
