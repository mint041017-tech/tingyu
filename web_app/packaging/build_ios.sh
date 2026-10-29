#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "iOS 打包需要 macOS + Xcode。本目录已生成可直接打开的 Xcode 工程。" >&2
  exit 1
fi
: "${TEAM_ID:?请先设置 Apple Developer Team ID，例如 export TEAM_ID=ABCDE12345}"
command -v pod >/dev/null || { echo "需要 CocoaPods：sudo gem install cocoapods" >&2; exit 1; }
command -v xcodebuild >/dev/null || { echo "需要 Xcode Command Line Tools" >&2; exit 1; }

npm run ios:sync
cd ios/App
pod install --repo-update
xcodebuild -workspace App.xcworkspace -scheme App -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  -archivePath build/Tingyu.xcarchive archive \
  DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates

mkdir -p build
cat > build/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>${EXPORT_METHOD:-development}</string>
  <key>teamID</key><string>${TEAM_ID}</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>compileBitcode</key><false/>
</dict>
</plist>
PLIST
xcodebuild -exportArchive -archivePath build/Tingyu.xcarchive \
  -exportPath build/ipa -exportOptionsPlist build/ExportOptions.plist -allowProvisioningUpdates
echo "IPA 输出：ios/App/build/ipa"
