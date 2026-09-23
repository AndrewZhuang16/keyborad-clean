#!/usr/bin/env bash
set -euo pipefail

# 生成正式的 macOS 应用图标 (AppIcon.icns)
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET="$ROOT/.icon.iconset"
MASTER="$ROOT/.icon_master.png"
OUT="$ROOT/Resources/AppIcon.icns"

# 将 swift 临时/模块缓存重定向到工作区内，避免受限环境构建失败
export TMPDIR="${TMPDIR:-$ROOT/.tmp}"
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$ROOT/.tmp/clang-module-cache}"
mkdir -p "$TMPDIR" "$CLANG_MODULE_CACHE_PATH"

echo "==> 绘制 1024x1024 主图"
swift "$ROOT/scripts/render_icon.swift" "$MASTER"

echo "==> 生成 iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

# 尺寸: (name, 像素宽高)
sips -z 16 16   "$MASTER" --out "$ICONSET/icon_16x16.png"      >/dev/null
sips -z 32 32   "$MASTER" --out "$ICONSET/icon_16x16@2x.png"   >/dev/null
sips -z 32 32   "$MASTER" --out "$ICONSET/icon_32x32.png"      >/dev/null
sips -z 64 64   "$MASTER" --out "$ICONSET/icon_32x32@2x.png"   >/dev/null
sips -z 128 128 "$MASTER" --out "$ICONSET/icon_128x128.png"    >/dev/null
sips -z 256 256 "$MASTER" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$MASTER" --out "$ICONSET/icon_256x256.png"    >/dev/null
sips -z 512 512 "$MASTER" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$MASTER" --out "$ICONSET/icon_512x512.png"    >/dev/null
cp "$MASTER" "$ICONSET/icon_512x512@2x.png"

echo "==> 打包 icns"
mkdir -p "$ROOT/Resources"
iconutil -c icns "$ICONSET" -o "$OUT"

rm -rf "$ICONSET" "$MASTER"
echo "完成: $OUT"
