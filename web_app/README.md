# 听隅 · Quiet Nook 1.1.0

给自己，留一小片安静。多轨白噪音、番茄钟、收藏与定时渐弱，现已适配 Web、Windows、Android、iPhone/iPad 与 macOS。

## 交付物

| 端 | 路径 | 状态 |
| --- | --- | --- |
| Android | [dist/android/Tingyu-v1.1.0-release.apk](dist/android/Tingyu-v1.1.0-release.apk) | 已签名、已核验版本/权限/压缩包完整性 |
| Windows 安装版 | [dist/windows/Tingyu-v1.1.0-Setup.exe](dist/windows/Tingyu-v1.1.0-Setup.exe) | NSIS 安装包；载荷已解包并真实启动核验 |
| Windows 便携版 | [dist/windows/Tingyu-v1.1.0-Portable.exe](dist/windows/Tingyu-v1.1.0-Portable.exe) | 单文件便携版；若被 SmartScreen/安全软件拦截，请改用安装版或免安装 ZIP |
| Windows 免安装包 | [dist/windows/Tingyu-v1.1.0-win64-portable.zip](dist/windows/Tingyu-v1.1.0-win64-portable.zip) | 解压后运行 `Tingyu.exe`；已真实启动核验 |
| iOS / iPad | [dist/ios-mac/Tingyu-v1.1.0-ios-source.zip](dist/ios-mac/Tingyu-v1.1.0-ios-source.zip) | 预打包：Xcode 工程、图标、启动屏、构建脚本 |
| macOS | [dist/ios-mac/Tingyu-v1.1.0-macos-source.zip](dist/ios-mac/Tingyu-v1.1.0-macos-source.zip) | 预打包：Electron 配置、icns、构建脚本 |
| Web | [dist/web/Tingyu-web-v1.1.0-deploy.zip](dist/web/Tingyu-web-v1.1.0-deploy.zip) | 可直接部署到站点根目录 |

校验和见各目录下的 `SHA256SUMS.txt`，机器可读结果见 `dist/verification.json`。

## 这版新增

- **番茄钟**：25/45/60 分钟与自定义专注，短休/长休，2–8 轮长休间隔；开始、暂停、跳过、重置、自动衔接；完成提示音（清铃/木鱼）与音量；系统通知；专注时自动播放混音、休息时暂停；切页/刷新/切后台按真实结束时间恢复；今日分钟、完成次数、连续天数与最近 7 天记录；全主题适配。
- **动效**：页面切换淡入位移、导航胶囊与图标、播放键回弹、场景卡悬停、选项卡、主题按钮与状态切换；全部尊重“减少动态效果”和系统 `prefers-reduced-motion`。
- **Logo 与启动**：新的“声叶”标记（叶片 + 三条声波叶脉），同步 favicon、应用图标、启动屏；Web 启动壳有叶片描线/叶脉绘制/内容浮现，Android 原生启动屏、iOS LaunchScreen、Windows 启动窗与 Web 启动壳使用同一套品牌语言。
- **多端壳**：Capacitor 7（Android/iOS/iPad）+ Electron 38（Windows/macOS）；统一 Web 资源，保留快速首屏 HTML 启动壳。

## 构建与验证

### Web

```bash
cd web_app
flutter analyze
flutter test
flutter build web --release
node tools/ui-check.mjs      # 需要先启动 build/web 静态服务
node tools/boot-check.mjs
node tools/audio-check.mjs
```

### Android（Windows 本机已验证）

```bash
cd web_app/packaging
npm install
node scripts/sync-web.mjs
npx cap sync android
# 需要 JDK 21；本机工具链在 packaging/tools/jdk-21.0.2
cd android
gradlew.bat assembleRelease
```

签名密钥在 `packaging/keys/tingyu-release.jks`，口令在 `packaging/keys/keystore.properties`。升级时必须复用同一密钥，并递增 `versionCode`。

### Windows（Windows 本机已验证）

```bash
cd web_app/packaging
npm install
node scripts/sync-web.mjs
npx electron-packager dist/win-stage "听隅" --platform=win32 --arch=x64 \
  --out=dist/win-final --asar --icon=resources/icon.ico \
  --app-version=1.1.0 --executable-name=Tingyu \
  --electron-version=38.8.6 --electron-zip-dir="<Electron 缓存目录>"
npx electron-builder --win nsis portable --x64 \
  --prepackaged "dist/win-final/听隅-win32-x64" \
  --config.directories.output=dist/installer-final
```

Windows 安装包/便携版未使用商业代码签名证书，首次运行可能出现 SmartScreen 提示；应用本身以 Electron 38 + 本地 `app://` 协议运行，不依赖外网服务器即可打开界面。安装包载荷与免安装 ZIP 已在本机真实启动核验。

### iOS / iPad（需 macOS + Xcode + CocoaPods）

```bash
cd web_app/packaging
npm install
export TEAM_ID=你的Apple团队ID
./build_ios.sh
```

脚本会同步 Web 资源、执行 `pod install`、归档并导出 IPA。工程已设置：

- Bundle ID：`com.citro.tingyu`，版本 `1.1.0 (10100)`
- iPhone + iPad（`TARGETED_DEVICE_FAMILY = 1,2`），iPad 支持四方向与分屏
- 全局启动屏 `LaunchScreen`、1024 图标、深绿品牌启动色
- `UIBackgroundModes: audio` 与 `AVAudioSession(.playback, mixWithOthers)`，尽量保持锁屏/后台可听
- `ITSAppUsesNonExemptEncryption = false`，便于 TestFlight

### macOS（需 macOS）

```bash
cd web_app/packaging
npm install
./build_mac.sh
```

输出 `packaging/dist/Tingyu-1.1.0-x64.dmg` 与 `Tingyu-1.1.0-arm64.dmg`（未签名，本地自用）。图标、启动窗、深浅色、网络权限配置已就绪。

## 验证记录

- `flutter analyze`：无问题；`flutter test`：3 项通过。
- Playwright（393×852 与 1440×1000）：无控制台错误；首页、专注、声音、收藏、设置可切换；番茄钟 `25:00 → 24:57`，导航与顶栏倒计时同步；主题切换、暂停/继续、清铃试听调用正常。
- 音频实测：点击播放后 3 路声音 `playing: true`，AudioContext `running`，`sources: 3`，RMS `0.044`；提示音返回 `true`。
- 启动动画：Web 启动壳的 `brandIn/leafIn/veinIn` 均在运行，manifest 与 SVG 标记存在。
- 番茄钟 E2E：开始后刷新仍以 `专注 00:52` 恢复；真实倒计时归零后自动进入短休息，今日记录 +1、提示音被调用 1 次；明暗主题在刷新后保持。
- Android：`versionCode 10100 / versionName 1.1.0`，minSdk 23、targetSdk 35；`apksigner verify` 通过；`unzip -t` 无错误；APK 内无重复 WAV，Service Worker 已对原生壳关闭。
- Windows：打包目录与安装包载荷分别真实启动，Flutter 首帧、语义树、音频桥均正常；安装包/便携版均为 1.1.0。
- iOS/macOS：工程、图标、启动屏、设备族、权限与版本已做静态预检，详见 `dist/ios-mac/ios-mac-preflight.json`。

## 边界与注意

- 内置 28 种声音仍从公开 OBS 按需加载，需要联网；个人导入音频只留在此设备的 IndexedDB，不上传。
- 网页/壳内后台计时按真实结束时间恢复，但系统可能在锁屏后挂起 WebView，提示音与系统通知不保证像原生闹钟一样准时；番茄钟页内已明确提示。
- Android/iOS 原生壳当前使用 Web 通知与页内提示，不包含原生闹钟/前台服务；如需商店级后台提醒，需要再接原生本地通知插件。
- Windows 安装包与便携版未签名；macOS 包按未签名本地自用配置准备。
- iOS/iPad/macOS 无法在 Windows 上完成最终二进制，已交付可直接在 Mac 上构建的预打包工程与脚本。
