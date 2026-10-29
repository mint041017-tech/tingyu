from pathlib import Path
import plistlib

root = Path(__file__).resolve().parents[1]
ios = root / 'ios' / 'App' / 'App'
info_path = ios / 'Info.plist'
with info_path.open('rb') as f:
    info = plistlib.load(f)

info.update({
    'CFBundleDevelopmentRegion': 'zh_CN',
    'CFBundleLocalizations': ['zh-Hans', 'en'],
    'NSHumanReadableCopyright': 'Copyright © 2026 Citro',
    'LSApplicationCategoryType': 'public.app-category.lifestyle',
    'ITSAppUsesNonExemptEncryption': False,
    'UIApplicationSupportsIndirectInputEvents': True,
    'UIBackgroundModes': ['audio'],
    'UIRequiredDeviceCapabilities': ['arm64'],
})
with info_path.open('wb') as f:
    plistlib.dump(info, f, sort_keys=False)

project = root / 'ios' / 'App' / 'App.xcodeproj' / 'project.pbxproj'
text = project.read_text(encoding='utf-8')
text = text.replace('MARKETING_VERSION = 1.0;', 'MARKETING_VERSION = 1.1.0;')
text = text.replace('CURRENT_PROJECT_VERSION = 1;', 'CURRENT_PROJECT_VERSION = 10100;')
project.write_text(text, encoding='utf-8')

delegate = ios / 'AppDelegate.swift'
swift = delegate.read_text(encoding='utf-8')
swift = swift.replace('import UIKit\nimport Capacitor', 'import UIKit\nimport Capacitor\nimport AVFoundation')
swift = swift.replace(
    """    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }""",
    """    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 让白噪音在锁屏/切到后台时尽量保持可听；WKWebView 仍可能按系统策略暂停。
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // 音频会话不可用时保留系统默认输出。
        }
        return true
    }""",
)
delegate.write_text(swift, encoding='utf-8')
print('ios config patched')
