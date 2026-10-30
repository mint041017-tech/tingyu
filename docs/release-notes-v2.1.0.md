# 听隅 2.1.0 · 本地声音与呼吸页

## 变化

- **取消 Web 端**：项目、安装包和发布制品不再包含 Flutter Web 版本；只维护 Android、iPhone/iPad、Windows、macOS 原生应用。
- **声音全部改为本地加载**：28 种声音以 48 kHz FLAC 直接打进安装包，不再访问 OBS；26 段录音预做 0.12 秒循环交叉淡化，白/粉/棕/水下噪声为生成音频。断网、弱网均可直接播放。
- **安装包变大但完全离线**：Android APK 约 115 MB，Windows 免安装包约 65 MB；换来启动即播放、无下载等待。
- **呼吸页重做**：呼吸光球、相位倒计时（4 秒吸气 / 6 秒呼气）、本次进度环、1/3/5 分钟选择、深浅色主题、粒子与柔光背景；保留原引导逻辑和暂停/重新开始。
- **原生番茄钟、收藏、导入、启动动画**保持；启动页文字下划线已修复。

## 安装包

- `Tingyu-v2.1.0-release.apk`：Android，`com.citro.tingyu`，versionCode `20100`，已签名。
- `Tingyu-v2.1.0-Setup.exe`：Windows x64 NSIS 安装包。
- `Tingyu-v2.1.0-win64-portable.zip`：Windows x64 免安装包，解压运行 `tingyu.exe`。
- `Tingyu-native-v2.1.0-ios-source.zip`：iOS/iPad Xcode 预打包源文件，需在 macOS 上构建。
- `Tingyu-native-v2.1.0-macos-source.zip`：macOS Xcode 预打包源文件，需在 macOS 上构建。
- `SHA256SUMS.txt`：校验和。

## 验证

- `flutter analyze` 0 issues；`flutter test` 模型测试 + 3 张呼吸页 golden 通过。
- Windows 原生集成测试：28 个本地 FLAC 全部可加载、3 轨真实播放、定时归零、提示音、收藏持久化通过。
- Android：签名、versionCode/versionName、`unzip -t` 通过。
- Windows：原生 Release 真实启动，启动动画/窗口/图标/版本核验。
- iOS/iPad/macOS：Bundle、设备族、后台音频、图标、启动屏、Podfile/SPM、entitlements 静态预检。

## 说明

- Android 未接前台服务/MediaSession，长时间锁屏后台仍可能被系统回收；iOS 通过后台音频模式尽量保持。
- iOS/iPad/macOS 最终 IPA/APP 需在 macOS + Xcode 构建。
- Windows 安装包未签名，可能出现 SmartScreen 提示。
- 项目只保留原生端；旧 Web 版本不再发布。
