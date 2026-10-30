# 听隅 2.0.0 · 原生重写

Android、iPhone/iPad、Windows、macOS 已从 WebView/Electron 套壳改为 **原生 Flutter 构建**，音频由 **flutter_soloud** 在原生音频线程完成多轨混音；Web 继续保留 Flutter Web + WebAudio。

## 变化

- **原生音频**：6 路循环、独立音量、总音量、定时淡出、试听；26 段 OBS 录音本机缓存并做 0.12 秒循环交叉淡化；白/粉/棕/水下噪声原生合成。
- **原生存储**：收藏、草稿、主题、默认渐弱、专注记录写入 `shared_preferences`；导入音频复制到应用支持目录，不上传。
- **番茄钟**：原生计时、SoLoud 提示音、Android/iOS 本地通知、Windows 即时通知、统计与恢复。
- **原生平台**：Windows 原生窗口/启动动画；iOS/iPad 后台音频、iPhone+iPad 四方向；macOS 网络与文件选择 entitlements。
- **外观不变**：页面、动效、主题、响应式布局、Logo 与启动动画保持原设计。
- **依赖精简**：Windows 包从 Electron 139 MB 降到约 17 MB（ZIP/安装包）。

## 安装包

- `Tingyu-v2.0.0-release.apk`：Android，`com.citro.tingyu`，versionCode `20000`，已签名。
- `Tingyu-v2.0.0-Setup.exe`：Windows x64 NSIS 安装包。
- `Tingyu-v2.0.0-win64-portable.zip`：Windows x64 免安装包，解压运行 `tingyu.exe`。
- `Tingyu-native-v2.0.0-ios-source.zip`：iOS/iPad Xcode 预打包源文件，需在 macOS 上构建。
- `Tingyu-native-v2.0.0-macos-source.zip`：macOS Xcode 预打包源文件，需在 macOS 上构建。
- `Tingyu-web-v2.0.0-deploy.zip`：Flutter Web 部署包。
- `SHA256SUMS.txt`：校验和。

## 验证

- `flutter analyze`：0 issues。
- `flutter test`：模型/存储测试通过。
- Windows 原生集成测试：SoLoud 初始化、3 轨真实播放、定时归零、提示音、收藏持久化全部通过。
- Android：`apksigner verify` 通过、`unzip -t` 无错误、版本/权限核验；APK `70,256,246` bytes。
- Windows：Release 原生应用真实启动，启动动画/窗口/图标/版本核验；安装包与 ZIP 使用同一 Release。
- Web：移动/桌面/iPad/小屏无横向溢出、无控制台错误；WebAudio 三轨播放。
- iOS/iPad/macOS：Bundle、设备族、后台音频、图标、启动屏、Podfile/SPM、entitlements 静态预检。

## 说明

- Android 未接前台服务/MediaSession，长时间锁屏后台仍可能被系统回收；iOS 通过后台音频模式尽量保持。
- iOS/iPad/macOS 的最终 IPA/APP 需在 macOS + Xcode 构建；本 Release 提供预打包源文件。
- 原生版不迁移 Web localStorage/IndexedDB 旧数据；Web 版保留原数据。
- Windows 安装包未做商业代码签名，可能出现 SmartScreen 提示。
