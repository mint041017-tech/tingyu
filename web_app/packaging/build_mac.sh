#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "macOS 打包需要 macOS。预打包配置与图标已准备完成。" >&2
  exit 1
fi

npm run sync:web
CSC_IDENTITY_AUTO_DISCOVERY=false npx electron-builder --mac --x64
CSC_IDENTITY_AUTO_DISCOVERY=false npx electron-builder --mac --arm64
echo "DMG/ZIP 输出：packaging/dist"
