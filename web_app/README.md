# 听隅 2.0.0 · 原生多端

这次不是 WebView/Electron 套壳：Android、iPhone/iPad、Windows、macOS 都是原生 Flutter 构建，音频由 **flutter_soloud** 在原生音频线程混音；Web 仍保留 Flutter Web + WebAudio 版本。

## 平台

| 平台 | 音频 | 构建 |
| --- | --- | --- |
| Android | SoLoud 原生多轨，6 路循环/音量/淡出 | `flutter build apk --release` |
| iPhone / iPad | SoLoud + AVAudioSession(`playback`) | Xcode / `flutter build ipa` |
| Windows | SoLoud + WASAPI | `flutter build windows --release` |
| macOS | SoLoud + CoreAudio | Xcode / `flutter build macos --release` |
| Web | WebAudio（原 JS 引擎） | `flutter build web --release` |

## 功能

- 28 种声音、最多 6 轨混音、每轨独立音量、总音量、OBS 按需加载与本地缓存。
- 26 段录音在原生侧做 0.12 秒循环交叉淡化；白/粉/棕/水下为原生合成并缓存。
- 收藏、草稿、主题、默认渐弱、专注记录走 `shared_preferences`；导入音频复制到应用支持目录，不上传。
- 番茄钟：原生计时、提示音（SoLoud 合成铃/木鱼）、Android/iOS 系统定时通知、桌面即时通知、统计与恢复。
- 原有页面、动效、主题、响应式布局与品牌启动动画保留。

## 构建

```bash
cd web_app
flutter pub get
```

### Android

```bash
export JAVA_HOME=/path/to/jdk-21
flutter build apk --release
```

- 包名 `com.citro.tingyu`，versionCode `20000`，versionName `2.0.0`。
- 使用 `packaging/keys/tingyu-release.jks` 签名；不要把密钥提交到仓库。
- 已声明 INTERNET、POST_NOTIFICATIONS、VIBRATE、WAKE_LOCK。

### Windows

```bash
flutter build windows --release
```

输出 `build/windows/x64/runner/Release/tingyu.exe`，整个 Release 目录即便携版。

### iOS / iPad

```bash
flutter pub get
cd ios && pod install
open Runner.xcworkspace
```

工程同时提供 CocoaPods 配置（部分通知/文件选择插件尚未迁移 SPM）。在 Xcode 选择 Team 后 Archive/Export；或 `flutter build ipa --release`。工程已设置：

- Bundle ID `com.citro.tingyu`
- iPhone + iPad（`TARGETED_DEVICE_FAMILY = 1,2`），iPad 四方向
- `UIBackgroundModes: audio`
- 深绿启动屏、1024 AppIcon
- `ITSAppUsesNonExemptEncryption = false`

### macOS

```bash
flutter pub get
cd macos && pod install
cd .. && flutter build macos --release
```

`com.apple.security.network.client` 与用户选择文件读取权限已加入 entitlements；签名/公证需要在 Mac 上配置 Team。

## 验证

- `flutter analyze`：0 error。
- `flutter test`：模型/存储单测。
- `flutter test integration_test/native_smoke_test.dart -d windows`：真实初始化 SoLoud、播放 3 轨、定时结束、提示音、收藏持久化。
- Android APK：`apksigner verify`、`unzip -t`、aapt 版本/权限核验。
- Windows：Release 应用真实启动；安装包载荷可解包启动。
- iOS/macOS：静态预检（Bundle、设备族、背景音频、图标、启动屏、entitlements）。

## 已知边界

- Android 没有接入前台服务/MediaSession，长时间锁屏后台仍可能被系统回收；iOS 通过后台音频模式尽量保持。
- 系统通知在 Android/iOS 走本地通知；Windows 走 `local_notifier` 即时通知，macOS 走本地通知。
- 原生版不迁移 Web 的 localStorage/IndexedDB 旧数据。
- 首次播放某声音需要从 OBS 下载并缓存，之后离线可复用缓存。
