from pathlib import Path
import json
import plistlib
from zipfile import ZipFile, ZIP_DEFLATED
import os
from PIL import Image

root = Path(__file__).resolve().parents[1]
pack = root / 'dist' / 'native' / 'ios-mac'
pack.mkdir(parents=True, exist_ok=True)


def zip_paths(zip_path, roots, excludes=()):
    with ZipFile(zip_path, 'w', ZIP_DEFLATED, compresslevel=6) as z:
        for src, prefix in roots:
            src = Path(src)
            if src.is_file():
                z.write(src, Path(prefix) / src.name)
                continue
            for base, dirs, files in os.walk(src):
                dirs[:] = [d for d in dirs if d not in excludes and not d.endswith('.xcuserdata')]
                for name in files:
                    if name.endswith('.wav') and '/web/assets/audio/' in (Path(base) / name).as_posix():
                        continue
                    full = Path(base) / name
                    z.write(full, Path(prefix) / full.relative_to(src))


# iOS static checks
info = plistlib.load(open(root / 'ios/Runner/Info.plist', 'rb'))
pbx_ios = (root / 'ios/Runner.xcodeproj/project.pbxproj').read_text(encoding='utf-8')
icon_dir = root / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
launch_dir = root / 'ios/Runner/Assets.xcassets/LaunchImage.imageset'
icon_checks = []
for name in ['Icon-App-20x20@2x.png', 'Icon-App-60x60@3x.png', 'Icon-App-1024x1024@1x.png']:
    p = icon_dir / name
    icon_checks.append({'file': name, 'exists': p.exists(), 'size': list(Image.open(p).size) if p.exists() else None})
ios = {
    'displayName': info.get('CFBundleDisplayName'),
    'developmentRegion': info.get('CFBundleDevelopmentRegion'),
    'bundleIdentifier': 'com.citro.tingyu' if 'PRODUCT_BUNDLE_IDENTIFIER = com.citro.tingyu;' in pbx_ios else 'missing',
    'deviceFamily': '1,2' if 'TARGETED_DEVICE_FAMILY = "1,2";' in pbx_ios else 'missing',
    'backgroundAudio': 'audio' in (info.get('UIBackgroundModes') or []),
    'iPadOrientations': info.get('UISupportedInterfaceOrientations~ipad'),
    'launchStoryboard': (root / 'ios/Runner/Base.lproj/LaunchScreen.storyboard').exists(),
    'launchImages': [p.name for p in launch_dir.glob('LaunchImage*.png')],
    'appIcons': icon_checks,
    'swiftPackageManager': 'FlutterGeneratedPluginSwiftPackage' in pbx_ios,
    'podfile': (root / 'ios/Podfile').exists(),
    'dependencies': {
        'flutter_soloud': 'flutter_soloud' in (root / 'pubspec.yaml').read_text(encoding='utf-8'),
        'audio_session': 'audio_session' in (root / 'pubspec.yaml').read_text(encoding='utf-8'),
        'file_picker': 'file_picker' in (root / 'pubspec.yaml').read_text(encoding='utf-8'),
        'local_notifications': 'flutter_local_notifications' in (root / 'pubspec.yaml').read_text(encoding='utf-8'),
    },
}
assert ios['bundleIdentifier'] != 'missing'
assert ios['deviceFamily'] == '1,2'
assert ios['backgroundAudio']

# macOS static checks
mac_info = plistlib.load(open(root / 'macos/Runner/Info.plist', 'rb'))
mac_appinfo = (root / 'macos/Runner/Configs/AppInfo.xcconfig').read_text(encoding='utf-8')
release_ent = plistlib.load(open(root / 'macos/Runner/Release.entitlements', 'rb'))
mac_icon = root / 'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png'
macos = {
    'displayName': mac_info.get('CFBundleDisplayName'),
    'bundleIdentifier': 'com.citro.tingyu' if 'PRODUCT_BUNDLE_IDENTIFIER = com.citro.tingyu' in mac_appinfo else 'missing',
    'networkClient': release_ent.get('com.apple.security.network.client') is True,
    'userSelectedFiles': release_ent.get('com.apple.security.files.user-selected.read-only') is True,
    'icon1024': mac_icon.exists() and Image.open(mac_icon).size == (1024, 1024),
    'appName': 'Tingyu' if 'PRODUCT_NAME = Tingyu' in mac_appinfo else 'missing',
}
assert macos['bundleIdentifier'] != 'missing'
assert macos['networkClient']

ios_zip = pack / 'Tingyu-native-v2.0.0-ios-source.zip'
zip_paths(
    ios_zip,
    [
        (root / 'ios', 'Tingyu-native-v2.0.0-ios/ios'),
        (root / 'lib', 'Tingyu-native-v2.0.0-ios/lib'),
        (root / 'assets', 'Tingyu-native-v2.0.0-ios/assets'),
        (root / 'web', 'Tingyu-native-v2.0.0-ios/web'),
        (root / 'pubspec.yaml', 'Tingyu-native-v2.0.0-ios'),
        (root / 'pubspec.lock', 'Tingyu-native-v2.0.0-ios'),
        (root / 'analysis_options.yaml', 'Tingyu-native-v2.0.0-ios'),
        (root / 'README.md', 'Tingyu-native-v2.0.0-ios'),
    ],
    excludes={'build', 'Pods', '.dart_tool', 'node_modules', 'ephemeral'},
)
mac_zip = pack / 'Tingyu-native-v2.0.0-macos-source.zip'
zip_paths(
    mac_zip,
    [
        (root / 'macos', 'Tingyu-native-v2.0.0-macos/macos'),
        (root / 'lib', 'Tingyu-native-v2.0.0-macos/lib'),
        (root / 'assets', 'Tingyu-native-v2.0.0-macos/assets'),
        (root / 'web', 'Tingyu-native-v2.0.0-macos/web'),
        (root / 'pubspec.yaml', 'Tingyu-native-v2.0.0-macos'),
        (root / 'pubspec.lock', 'Tingyu-native-v2.0.0-macos'),
        (root / 'analysis_options.yaml', 'Tingyu-native-v2.0.0-macos'),
        (root / 'README.md', 'Tingyu-native-v2.0.0-macos'),
    ],
    excludes={'build', 'Pods', '.dart_tool', 'node_modules', 'ephemeral'},
)

data = {
    'platform': 'iOS / iPad / macOS prebuild source',
    'status': 'prepared-not-compiled-on-windows',
    'ios': ios,
    'macos': macos,
    'packages': {
        'ios': {'file': str(ios_zip.relative_to(root.parent)), 'bytes': ios_zip.stat().st_size},
        'macos': {'file': str(mac_zip.relative_to(root.parent)), 'bytes': mac_zip.stat().st_size},
    },
}
(pack / 'preflight.json').write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(data, ensure_ascii=False, indent=2))
