# 听隅 2.1.0 · 原生多端

Android、iPhone/iPad、Windows、macOS 均为原生 Flutter 构建；音频由 **flutter_soloud** 在原生音频线程混音，28 种声音以本地 FLAC 随安装包分发，无需联网。Web 端已移除。

## 平台与构建

### Android

```bash
export JAVA_HOME=/path/to/jdk-21
flutter pub get
flutter build apk --release
```

包名 `com.citro.tingyu`，versionCode `20100`，versionName `2.1.0`；使用 `packaging/keys/tingyu-release.jks` 签名，密钥不进入仓库。

### Windows

```bash
flutter pub get
flutter build windows --release
```

输出 `build/windows/x64/runner/Release/tingyu.exe`，整个 Release 目录即免安装版。

### iOS / iPad

```bash
flutter pub get
cd ios && pod install
open Runner.xcworkspace
```

工程已设置 Bundle ID `com.citro.tingyu`、iPhone+iPad 四方向、`UIBackgroundModes: audio`、深绿启动屏、1024 AppIcon。需在 macOS + Xcode 选择 Team 后 Archive；也可 `flutter build ipa --release`。

### macOS

```bash
flutter pub get
cd macos && pod install
cd .. && flutter build macos --release
```

`com.apple.security.files.user-selected.read-only` 已配置；App Sandbox 保留。

## 声音

- `assets/audio/builtin/*.flac`：28 个 48 kHz 本地循环音频，安装包内直接加载。
- 26 段录音在生成时已做 0.12 秒循环交叉淡化；白/粉/棕/水下噪声为生成音频。
- 导入音频复制到应用支持目录，只在本机使用，不上传。

## 验证

- `flutter analyze`：0 issues。
- `flutter test`：模型测试 + 呼吸页三尺寸 golden。
- `flutter test integration_test/native_smoke_test.dart -d windows`：28 个本地音频全部可加载、3 轨播放、定时归零、提示音、收藏持久化。
- Android：签名/版本/压缩完整性核验。
- Windows：原生 Release 真实启动，启动动画/窗口/图标/版本核验。
- iOS/macOS：Bundle、设备族、后台音频、图标、启动屏、Podfile/SPM、entitlements 静态预检。

## 边界

- Android 未接前台服务/MediaSession，长时间锁屏后台可能被系统回收；iOS 通过后台音频模式尽量保持。
- iOS/iPad/macOS 的最终 IPA/APP 需在 macOS + Xcode 构建。
- Windows 安装包未做商业代码签名，可能出现 SmartScreen 提示。
- 原生版不迁移旧 Web localStorage/IndexedDB 数据。
