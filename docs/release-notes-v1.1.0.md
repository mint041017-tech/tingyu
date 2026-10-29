# 听隅 · Quiet Nook 1.1.0

给自己，留一小片安静。

这是听隅的首个多端发布：Flutter Web 核心，Capacitor 7 承载 Android 与 iPhone/iPad，Electron 38 承载 Windows 与 macOS。

## 新增

- **番茄钟**：25/45/60 分钟与自定义专注、短休/长休、2–8 轮长休间隔；开始/暂停/跳过/重置；自动衔接；清铃/木鱼提示音与音量；系统通知；专注自动播放混音、休息自动暂停；跨页、刷新与切后台按真实结束时间恢复；今日分钟、完成次数、连续天数与最近 7 天记录。
- **动效**：页面切换淡入位移、导航胶囊、播放键回弹、场景卡悬停、主题与番茄钟控件过渡；统一节奏并尊重“减少动态效果”。
- **品牌焕新**：新的“声叶”标记（叶片 + 三条声波叶脉），同步 favicon、启动壳、应用图标与启动屏。
- **启动动画**：Web 启动壳叶片描线/叶脉绘制/内容浮现；Electron 独立启动窗；Android/iOS 原生启动屏承接 Web 启动动画。
- **多端适配**：iPad 竖屏/横屏双栏、iPhone 小屏、Windows 最小窗口与桌面宽屏均完成布局核验。

## 安装包

- `Tingyu-v1.1.0-release.apk`：Android，已签名，versionCode `10100`，versionName `1.1.0`。
- `Tingyu-v1.1.0-Setup.exe`：Windows x64 NSIS 安装包。
- `Tingyu-v1.1.0-win64-portable.zip`：Windows x64 免安装包，解压运行 `Tingyu.exe`。
- `Tingyu-v1.1.0-Portable.exe`：Windows x64 单文件便携版；若被 SmartScreen/安全软件拦截，请使用上面的 ZIP。
- `Tingyu-v1.1.0-ios-source.zip`：iOS/iPad Xcode 预打包工程与构建脚本，需在 macOS 上产出 IPA。
- `Tingyu-v1.1.0-macos-source.zip`：macOS Electron 预打包工程与构建脚本，需在 macOS 上产出 DMG。
- `Tingyu-web-v1.1.0-deploy.zip`：Web 部署包，上传到站点根目录即可。
- `SHA256SUMS.txt`：上述制品的 SHA-256 校验和。

## 验证

- `flutter analyze` 0 问题；`flutter test` 3 项通过。
- 移动端、桌面、iPad 与小屏浏览器测试无横向溢出、无控制台错误。
- 番茄钟 E2E：刷新后从 `专注 00:52` 恢复；倒计时归零后进入短休息，记录 +1、提示音调用 1 次、主题刷新保持。
- 音频：3 路声音同时播放，AudioContext `running`，RMS > 0。
- Android：`apksigner verify` 通过、`unzip -t` 无错误。
- Windows：安装包载荷与免安装 ZIP 真实启动，Flutter 首帧、语义树、音频桥正常。

## 说明

- Windows 包未使用商业代码签名证书，首次运行可能出现 SmartScreen 提示。
- Android/iOS 后台提醒受 WebView 系统挂起影响，不保证像系统闹钟一样准时；番茄钟页内已提示。
- 内置 28 种声音从公开 OBS 按需加载，需要联网；用户导入的音频只保存在本机 IndexedDB。
- iOS/iPad/macOS 最终二进制需要在 macOS + Xcode/CocoaPods 环境构建。
