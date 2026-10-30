from pathlib import Path
import json
import plistlib
import shutil
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[1]
icon = Image.open(root / 'packaging' / 'resources' / 'icon.png').convert('RGB')

# ---------- iOS ----------
ios = root / 'ios'
info_path = ios / 'Runner' / 'Info.plist'
with info_path.open('rb') as f:
    info = plistlib.load(f)
info.update({
    'CFBundleDisplayName': '听隅',
    'CFBundleDevelopmentRegion': 'zh_CN',
    'CFBundleLocalizations': ['zh-Hans', 'en'],
    'UIBackgroundModes': ['audio'],
    'UIRequiredDeviceCapabilities': ['arm64'],
    'ITSAppUsesNonExemptEncryption': False,
    'UIApplicationSupportsIndirectInputEvents': True,
    'LSApplicationCategoryType': 'public.app-category.lifestyle',
    'NSHumanReadableCopyright': 'Copyright © 2026 Citro',
    'UISupportedInterfaceOrientations': [
        'UIInterfaceOrientationPortrait',
        'UIInterfaceOrientationLandscapeLeft',
        'UIInterfaceOrientationLandscapeRight',
    ],
    'UISupportedInterfaceOrientations~ipad': [
        'UIInterfaceOrientationPortrait',
        'UIInterfaceOrientationPortraitUpsideDown',
        'UIInterfaceOrientationLandscapeLeft',
        'UIInterfaceOrientationLandscapeRight',
    ],
})
with info_path.open('wb') as f:
    plistlib.dump(info, f, sort_keys=False)

# App icon sizes
appicon_dir = ios / 'Runner' / 'Assets.xcassets' / 'AppIcon.appiconset'
contents = json.loads((appicon_dir / 'Contents.json').read_text(encoding='utf-8'))
for item in contents.get('images', []):
    filename = item.get('filename')
    size = item.get('size')
    scale = item.get('scale', '1x')
    if not filename or not size:
        continue
    base = float(size.split('x')[0]) * int(scale.replace('x', ''))
    icon.resize((int(base), int(base)), Image.LANCZOS).save(appicon_dir / filename, optimize=True)

# Launch image: transparent brand lockup on deep green storyboard.
launch_dir = ios / 'Runner' / 'Assets.xcassets' / 'LaunchImage.imageset'
font_zh = None
for candidate in ['C:/Windows/Fonts/msyhbd.ttc', 'C:/Windows/Fonts/msyh.ttc', 'C:/Windows/Fonts/simhei.ttf']:
    try:
        font_zh = ImageFont.truetype(candidate, 120)
        break
    except Exception:
        continue
base = Image.new('RGBA', (960, 1440), (0, 0, 0, 0))
leaf = Image.open(root / 'packaging' / 'resources' / 'icon-foreground.png').convert('RGBA')
leaf = leaf.resize((330, 330), Image.LANCZOS)
base.alpha_composite(leaf, ((960 - 330) // 2, 430))
draw = ImageDraw.Draw(base)
if font_zh:
    text = '听隅'
    box = draw.textbbox((0, 0), text, font=font_zh)
    draw.text(((960 - (box[2] - box[0])) / 2, 830), text, font=font_zh, fill=(244, 241, 232, 255))
try:
    font_en = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 34)
except Exception:
    font_en = None
if font_en:
    text = 'Q U I E T   N O O K'
    box = draw.textbbox((0, 0), text, font=font_en)
    draw.text(((960 - (box[2] - box[0])) / 2, 1010), text, font=font_en, fill=(168, 181, 166, 255))
base.resize((320, 480), Image.LANCZOS).save(launch_dir / 'LaunchImage.png', optimize=True)
base.resize((640, 960), Image.LANCZOS).save(launch_dir / 'LaunchImage@2x.png', optimize=True)
base.save(launch_dir / 'LaunchImage@3x.png', optimize=True)

# Storyboard: deep green background.
story = ios / 'Runner' / 'Base.lproj' / 'LaunchScreen.storyboard'
s = story.read_text(encoding='utf-8')
s = s.replace(
    '<color key="backgroundColor" red="1" green="1" blue="1" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>',
    '<color key="backgroundColor" red="0.1333" green="0.1882" blue="0.1529" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>',
)
story.write_text(s, encoding='utf-8')

# ---------- macOS ----------
mac = root / 'macos'
mac_info_path = mac / 'Runner' / 'Info.plist'
with mac_info_path.open('rb') as f:
    mac_info = plistlib.load(f)
mac_info.update({
    'CFBundleDisplayName': '听隅',
    'CFBundleName': '听隅',
    'CFBundleDevelopmentRegion': 'zh_CN',
    'LSApplicationCategoryType': 'public.app-category.lifestyle',
    'NSHumanReadableCopyright': 'Copyright © 2026 Citro',
})
with mac_info_path.open('wb') as f:
    plistlib.dump(mac_info, f, sort_keys=False)

mac_icon_dir = mac / 'Runner' / 'Assets.xcassets' / 'AppIcon.appiconset'
mac_contents = json.loads((mac_icon_dir / 'Contents.json').read_text(encoding='utf-8'))
for item in mac_contents.get('images', []):
    filename = item.get('filename')
    size = item.get('size')
    scale = item.get('scale', '1x')
    if not filename or not size:
        continue
    px = int(float(size.split('x')[0]) * int(scale.replace('x', '')))
    icon.resize((px, px), Image.LANCZOS).save(mac_icon_dir / filename, optimize=True)

for name in ['DebugProfile.entitlements', 'Release.entitlements']:
    path = mac / 'Runner' / name
    with path.open('rb') as f:
        ent = plistlib.load(f)
    ent['com.apple.security.network.client'] = True
    ent['com.apple.security.files.user-selected.read-only'] = True
    with path.open('wb') as f:
        plistlib.dump(ent, f, sort_keys=False)

# Bundle IDs
for project in [ios / 'Runner.xcodeproj' / 'project.pbxproj', mac / 'Runner.xcodeproj' / 'project.pbxproj']:
    text = project.read_text(encoding='utf-8')
    text = text.replace('com.citro.tingyuWeb.RunnerTests', 'com.citro.tingyu.RunnerTests')
    text = text.replace('com.citro.tingyuWeb', 'com.citro.tingyu')
    project.write_text(text, encoding='utf-8')

print('apple native assets configured')
