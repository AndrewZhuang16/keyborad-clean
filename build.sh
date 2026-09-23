#!/usr/bin/env bash
set -euo pipefail

APP_NAME="键盘清理"
EXECUTABLE="KeyboardClean"
BUNDLE_ID="com.keyboardclean.app"
APP_DIR="dist/${APP_NAME}.app"

# 将 SwiftPM / clang 的临时与缓存目录重定向到工作区内，
# 避免在受限环境（无 /var/folders、~/Library 写权限）下构建失败。
export TMPDIR="${TMPDIR:-$PWD/.tmp}"
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$PWD/.tmp/clang-module-cache}"
mkdir -p "$TMPDIR" "$CLANG_MODULE_CACHE_PATH"

echo "==> 编译 (swift build -c release)"
swift build --disable-sandbox -c release

if [ ! -f "Resources/AppIcon.icns" ]; then
    echo "==> 未找到图标，生成 AppIcon.icns"
    ./scripts/make_icon.sh
fi

echo "==> 组装 ${APP_DIR}"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp ".build/release/${EXECUTABLE}" "$APP_DIR/Contents/MacOS/${EXECUTABLE}"
cp "Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

cat > "$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key>
    <string>${EXECUTABLE}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "==> 签名 (ad-hoc)"
codesign --force --deep --sign - "$APP_DIR"

echo
echo "构建完成: ${APP_DIR}"
echo "双击运行后，首次开启开关会提示授予「辅助功能」权限。"
