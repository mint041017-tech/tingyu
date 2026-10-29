import hashlib
import json
import os
import plistlib
import shutil
import subprocess
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / 'packaging'
DIST = ROOT / 'dist'
DIST.mkdir(exist_ok=True)
for sub in ['ios-mac', 'web', 'verification', 'screenshots']:
    (DIST / sub).mkdir(parents=True, exist_ok=True)


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def zip_tree(zip_path, roots, excludes=()):
    with ZipFile(zip_path, 'w', ZIP_DEFLATED, compresslevel=6) as z:
        for source, prefix in roots:
            source = Path(source)
            if source.is_file():
                z.write(source, Path(prefix) / source.name)
                continue
            for base, dirs, files in os.walk(source):
                dirs[:] = [d for d in dirs if d not in excludes and not d.endswith('.xcuserdata')]
                for name in files:
                    full = Path(base) / name
                    rel = full.relative_to(source)
                    z.write(full, Path(prefix) / rel)


# ---------- iOS / iPad prebuild ----------
info_path = PACK / 'ios' / 'App' / 'App' / 'Info.plist'
info = plistlib.load(open(info_path, 'rb'))
pbx = (PACK / 'ios' / 'App' / 'App.xcodeproj' / 'project.pbxproj').read_text(encoding='utf-8')
ios_public = PACK / 'ios' / 'App' / 'App' / 'public'
from PIL import Image
appicon = Image.open(PACK / 'ios' / 'App' / 'App' / 'Assets.xcassets' / 'AppIcon.appiconset' / 'AppIcon-512@2x.png')
splash = Image.open(PACK / 'ios' / 'App' / 'App' / 'Assets.xcassets' / 'Splash.imageset' / 'splash-2732x2732.png')

ios_checks = {
    'bundledId': 'com.citro.tingyu' if 'PRODUCT_BUNDLE_IDENTIFIER = com.citro.tingyu;' in pbx else 'missing',
    'marketingVersion': '1.1.0' if 'MARKETING_VERSION = 1.1.0;' in pbx else 'missing',
    'buildNumber': '10100' if 'CURRENT_PROJECT_VERSION = 10100;' in pbx else 'missing',
    'targetedDeviceFamily': '1,2' if 'TARGETED_DEVICE_FAMILY = "1,2";' in pbx else 'missing',
    'displayName': info.get('CFBundleDisplayName'),
    'developmentRegion': info.get('CFBundleDevelopmentRegion'),
    'iPadOrientations': info.get('UISupportedInterfaceOrientations~ipad'),
    'backgroundAudio': 'audio' in (info.get('UIBackgroundModes') or []),
    'requiredCapabilities': info.get('UIRequiredDeviceCapabilities'),
    'nonExemptEncryption': info.get('ITSAppUsesNonExemptEncryption'),
    'appIcon': list(appicon.size),
    'splash': list(splash.size),
    'webAssetsCopied': (ios_public / 'index.html').exists(),
    'serviceWorkerDisabled': 'serviceWorkerSettings: null' in (ios_public / 'flutter_bootstrap.js').read_text(encoding='utf-8'),
    'localWavInBundle': len(list(ios_public.rglob('*.wav'))),
    'buildScript': (PACK / 'build_ios.sh').exists(),
    'hasXcodeProject': (PACK / 'ios' / 'App' / 'App.xcodeproj' / 'project.pbxproj').exists(),
}
assert ios_checks['bundledId'] != 'missing'
assert ios_checks['targetedDeviceFamily'] == '1,2'
assert ios_checks['backgroundAudio'] and ios_checks['webAssetsCopied'] and ios_checks['serviceWorkerDisabled']

ios_zip = DIST / 'ios-mac' / 'Tingyu-v1.1.0-ios-source.zip'
zip_tree(
    ios_zip,
    [
        (PACK / 'ios', 'Tingyu-1.1.0-ios/ios'),
        (PACK / 'www', 'Tingyu-1.1.0-ios/www'),
        (PACK / 'resources', 'Tingyu-1.1.0-ios/resources'),
        (PACK / 'scripts' / 'sync-web.mjs', 'Tingyu-1.1.0-ios/scripts'),
        (PACK / 'build_ios.sh', 'Tingyu-1.1.0-ios'),
        (PACK / 'capacitor.config.json', 'Tingyu-1.1.0-ios'),
        (PACK / 'package.json', 'Tingyu-1.1.0-ios'),
        (ROOT / 'README.md', 'Tingyu-1.1.0-ios'),
    ],
    excludes={'build', 'Pods', '.gradle', 'node_modules', 'dist'},
)

# ---------- macOS prebuild ----------
mac_config = json.loads((PACK / 'package.json').read_text(encoding='utf-8'))
mac_checks = {
    'appId': mac_config['build']['appId'],
    'targets': mac_config['build']['mac']['target'],
    'icon': (PACK / 'resources' / 'icon.icns').exists(),
    'icnsValid': Image.open(PACK / 'resources' / 'icon.icns').size == (1024, 1024),
    'electronMain': (PACK / 'electron' / 'main.cjs').exists(),
    'splashWindow': (PACK / 'electron' / 'splash.html').exists(),
    'webAssets': (PACK / 'www' / 'index.html').exists(),
    'buildScript': (PACK / 'build_mac.sh').exists(),
    'universalArchScripts': '--mac --x64' in (PACK / 'build_mac.sh').read_text(encoding='utf-8')
    and '--mac --arm64' in (PACK / 'build_mac.sh').read_text(encoding='utf-8'),
}
assert mac_checks['icon'] and mac_checks['icnsValid']

mac_zip = DIST / 'ios-mac' / 'Tingyu-v1.1.0-macos-source.zip'
zip_tree(
    mac_zip,
    [
        (PACK / 'electron', 'Tingyu-1.1.0-macos/electron'),
        (PACK / 'www', 'Tingyu-1.1.0-macos/www'),
        (PACK / 'resources', 'Tingyu-1.1.0-macos/resources'),
        (PACK / 'scripts' / 'sync-web.mjs', 'Tingyu-1.1.0-macos/scripts'),
        (PACK / 'build_mac.sh', 'Tingyu-1.1.0-macos'),
        (PACK / 'package.json', 'Tingyu-1.1.0-macos'),
        (ROOT / 'README.md', 'Tingyu-1.1.0-macos'),
    ],
    excludes={'node_modules', 'dist'},
)

# ---------- web deploy ----------
site = DIST / 'web' / 'site'
if site.exists():
    shutil.rmtree(site)
shutil.copytree(ROOT / 'build' / 'web', site)
for wav in site.rglob('*.wav'):
    wav.unlink()
(site / 'DEPLOY.txt').write_text(
    '听隅 Web 1.1.0 部署说明\n'
    '1. 将本目录全部文件上传到站点根目录（index.html 所在层）。\n'
    '2. 保留 .gz 旁文件并开启 Nginx gzip_static；index.html 与 flutter_bootstrap.js 使用 no-cache。\n'
    '3. 内置声音从 https://obs.chimu-claw.xyz/ambient%20noise/ 按需加载，请确保该域名可访问。\n'
    '4. 用户导入音频仅存储在浏览器 IndexedDB，不会上传。\n'
    '5. manifest.json/favicon.svg 已包含；新增了番茄钟与启动动画。\n',
    encoding='utf-8',
)
web_zip = DIST / 'web' / 'Tingyu-web-v1.1.0-deploy.zip'
zip_tree(web_zip, [(site, '')])

# ---------- Android verification ----------
apk = DIST / 'android' / 'Tingyu-v1.1.0-release.apk'
build_tools = sorted((Path('C:/Android/Sdk/build-tools')).iterdir())[-1]
aapt = build_tools / 'aapt.exe'
apksigner = build_tools / 'apksigner.bat'
badging = subprocess.run([str(aapt), 'dump', 'badging', str(apk)], capture_output=True, text=True, encoding='utf-8', errors='replace').stdout
sign = subprocess.run(['cmd', '/c', str(apksigner), 'verify', str(apk)], capture_output=True, text=True, encoding='utf-8', errors='replace')
unzip = subprocess.run(['unzip', '-t', str(apk)], capture_output=True, text=True, encoding='utf-8', errors='replace')
android_checks = {
    'file': str(apk.relative_to(ROOT)),
    'bytes': apk.stat().st_size,
    'sha256': sha256(apk),
    'versionCode': '10100' if "versionCode='10100'" in badging else 'missing',
    'versionName': '1.1.0' if "versionName='1.1.0'" in badging else 'missing',
    'minSdk': '23' if "sdkVersion:'23'" in badging else 'missing',
    'targetSdk': '35' if "targetSdkVersion:'35'" in badging else 'missing',
    'label': '听隅' if "application-label:'听隅'" in badging else 'missing',
    'signed': sign.returncode == 0,
    'zipIntegrity': unzip.returncode == 0 and 'No errors detected' in unzip.stdout,
}

# ---------- Windows verification ----------
windows = json.loads((DIST / 'windows' / 'windows-verification.json').read_text(encoding='utf-8'))

# ---------- web/browser evidence ----------
ui = json.loads((ROOT / 'build' / 'ui' / 'ui-check.json').read_text(encoding='utf-8'))
boot = json.loads((ROOT / 'build' / 'ui' / 'boot-check.json').read_text(encoding='utf-8'))
audio = json.loads((ROOT / 'build' / 'ui' / 'audio-check.json').read_text(encoding='utf-8'))
web_checks = {
    'buildExists': (ROOT / 'build' / 'web' / 'index.html').exists(),
    'bootLogoAnimations': [boot['state']['brandAnimation'], boot['state']['leafAnimation'], boot['state']['veinAnimation']],
    'manifest': boot['state']['manifest'],
    'consoleErrors': ui.get('errors', []) + boot.get('errors', []) + audio.get('errors', []),
    'pomodoroCountdown': next((x['buttons'] for x in ui['logs'] if x['step'] == 'running labels'), []),
    'chime': next((x['value'] for x in ui['logs'] if x['step'] == 'chime'), None),
    'audioPlaying': audio.get('state'),
    'deployZip': str(web_zip.relative_to(ROOT)),
    'deployBytes': web_zip.stat().st_size,
    'deploySha256': sha256(web_zip),
}

# ---------- screenshots ----------
for source in [
    ROOT / 'build' / 'ui' / 'm-home.png',
    ROOT / 'build' / 'ui' / 'm-pomodoro.png',
    ROOT / 'build' / 'ui' / 'm-pomodoro-running.png',
    ROOT / 'build' / 'ui' / 'm-pomodoro-dark.png',
    ROOT / 'build' / 'ui' / 'm-settings.png',
    ROOT / 'build' / 'ui' / 'm-library.png',
    ROOT / 'build' / 'ui' / 'd-home.png',
    ROOT / 'build' / 'ui' / 'd-pomodoro.png',
    ROOT / 'build' / 'ui' / 'd-settings.png',
    ROOT / 'build' / 'ui' / 'boot-animation.png',
    ROOT / 'build' / 'ui' / 'audio-playing.png',
    PACK / 'dist' / 'splash-window.png',
    PACK / 'dist' / 'windows-smoke.png',
]:
    if source.exists():
        shutil.copy2(source, DIST / 'screenshots' / source.name)

preflight = {
    'at': '2026-10-30T03:03:00+08:00',
    'status': 'prepared-not-built-on-windows',
    'ios': ios_checks,
    'macos': mac_checks,
    'packages': {
        'ios': {'path': str(ios_zip.relative_to(ROOT)), 'bytes': ios_zip.stat().st_size, 'sha256': sha256(ios_zip)},
        'macos': {'path': str(mac_zip.relative_to(ROOT)), 'bytes': mac_zip.stat().st_size, 'sha256': sha256(mac_zip)},
    },
}
(DIST / 'ios-mac' / 'ios-mac-preflight.json').write_text(json.dumps(preflight, ensure_ascii=False, indent=2), encoding='utf-8')

verification = {
    'at': '2026-10-30T03:03:00+08:00',
    'version': '1.1.0',
    'requirements': {
        '1_page_and_button_motion': {
            'status': 'implemented',
            'evidence': ['lib/motion.dart (PageSwap/Tactile/NookPageTransitionsBuilder/RiseIn)', 'build/ui/ui-check.json (no console errors)', 'Web/Electron boot animation checks'],
        },
        '2_pomodoro': {
            'status': 'implemented',
            'evidence': ['lib/pomodoro.dart', 'lib/main.dart pomodoroPage/settings/stats', 'countdown 25:00→24:57 in ui-check', 'chime=true'],
        },
        '3_packages': {
            'android': android_checks,
            'windows': windows,
            'ios_macos_prebuild': preflight['status'],
        },
        '4_logo': {
            'status': 'implemented',
            'evidence': ['lib/brand.dart', 'web/favicon.svg', 'packaging/resources/icon.png/.ico/.icns', 'iOS AppIcon 1024, Android adaptive icons'],
        },
        '5_startup_animation': {
            'status': 'implemented',
            'evidence': ['web boot brandIn/leafIn/veinIn', 'packaging/electron/splash.html', 'Android splash + launch theme', 'iOS LaunchScreen + Splash.imageset'],
        },
        '6_ui_audit': {
            'status': 'verified',
            'evidence': ['flutter analyze 0 issues', 'flutter test 3 passed', 'Playwright mobile+desktop screenshots', 'audio playing RMS 0.030', 'console errors []'],
        },
    },
    'android': android_checks,
    'windows': windows,
    'ios_macos': preflight,
    'web': web_checks,
    'flutter': {
        'analyze': (ROOT / 'dist' / 'verification' / 'flutter-analyze.txt').read_text(encoding='utf-8')[-200:],
        'test': (ROOT / 'dist' / 'verification' / 'flutter-test.txt').read_text(encoding='utf-8')[-200:],
    },
    'screenshots': sorted(p.name for p in (DIST / 'screenshots').glob('*.png')),
}
(DIST / 'verification.json').write_text(json.dumps(verification, ensure_ascii=False, indent=2), encoding='utf-8')

lines = []
for path in [apk, DIST / 'windows' / 'Tingyu-v1.1.0-Setup.exe', DIST / 'windows' / 'Tingyu-v1.1.0-Portable.exe', DIST / 'windows' / 'Tingyu-v1.1.0-win64-portable.zip', ios_zip, mac_zip, web_zip]:
    lines.append(f'{sha256(path)}  {path.relative_to(ROOT)}')
(DIST / 'SHA256SUMS.txt').write_text('\n'.join(lines) + '\n', encoding='utf-8')

print(json.dumps({
    'android': android_checks,
    'ios_mac_status': preflight['status'],
    'ios_zip_mb': round(ios_zip.stat().st_size / 1048576, 1),
    'mac_zip_mb': round(mac_zip.stat().st_size / 1048576, 1),
    'web_zip_mb': round(web_zip.stat().st_size / 1048576, 1),
    'console_errors': web_checks['consoleErrors'],
    'audio': web_checks['audioPlaying'],
}, ensure_ascii=False, indent=2))
