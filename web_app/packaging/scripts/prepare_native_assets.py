from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / 'resources'
ANDROID = ROOT / 'android' / 'app' / 'src' / 'main' / 'res'
IOS = ROOT / 'ios' / 'App' / 'App'

icon = Image.open(RES / 'icon.png').convert('RGB')
mark = Image.open(RES / 'icon.png').convert('RGB')
foreground = Image.open(RES / 'icon-foreground.png').convert('RGBA')
splash = Image.open(RES / 'splash.png').convert('RGB')

if ANDROID.exists():
    densities = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
    for name, size in densities.items():
        folder = ANDROID / f'mipmap-{name}'
        folder.mkdir(parents=True, exist_ok=True)
        icon.resize((size, size), Image.LANCZOS).save(folder / 'ic_launcher.png', optimize=True)
        round_icon = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        mask = Image.new('L', (size * 4, size * 4), 0)
        ImageDraw.Draw(mask).ellipse((0, 0, size * 4 - 1, size * 4 - 1), fill=255)
        mask = mask.resize((size, size), Image.LANCZOS)
        round_icon.paste(icon.resize((size, size), Image.LANCZOS), (0, 0), mask)
        round_icon.save(folder / 'ic_launcher_round.png', optimize=True)
        fg_size = int(size * 2.25)
        folder.joinpath('ic_launcher_foreground.png').write_bytes(b'')
        foreground.resize((fg_size, fg_size), Image.LANCZOS).save(
            folder / 'ic_launcher_foreground.png', optimize=True
        )
    bg_xml = ANDROID / 'values' / 'ic_launcher_background.xml'
    bg_xml.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        '    <color name="ic_launcher_background">#4F6957</color>\n</resources>\n',
        encoding='utf-8',
    )
    drawable = ANDROID / 'drawable'
    drawable.mkdir(parents=True, exist_ok=True)
    splash.resize((1920, 1920), Image.LANCZOS).save(drawable / 'splash.png', optimize=True)
    for folder in ANDROID.glob('drawable-port-*'):
        for file in folder.glob('splash.png'):
            file.unlink()
        try:
            folder.rmdir()
        except OSError:
            pass
    for folder in ANDROID.glob('drawable-land-*'):
        for file in folder.glob('splash.png'):
            file.unlink()
        try:
            folder.rmdir()
        except OSError:
            pass

if IOS.exists():
    appicon = IOS / 'Assets.xcassets' / 'AppIcon.appiconset'
    appicon.mkdir(parents=True, exist_ok=True)
    icon.resize((1024, 1024), Image.LANCZOS).save(appicon / 'AppIcon-512@2x.png', optimize=True)
    for asset in appicon.glob('*.json'):
        pass
    splashset = IOS / 'Assets.xcassets' / 'Splash.imageset'
    splashset.mkdir(parents=True, exist_ok=True)
    splash.resize((2732, 2732), Image.LANCZOS).save(splashset / 'splash-2732x2732.png', optimize=True)
    splash.resize((1366, 1366), Image.LANCZOS).save(splashset / 'splash-2732x2732-1.png', optimize=True)
    splash.resize((911, 911), Image.LANCZOS).save(splashset / 'splash-2732x2732-2.png', optimize=True)
    contents = splashset / 'Contents.json'
    contents.write_text(
        '{\n  "images" : [\n'
        '    { "filename" : "splash-2732x2732-2.png", "idiom" : "universal", "scale" : "1x" },\n'
        '    { "filename" : "splash-2732x2732-1.png", "idiom" : "universal", "scale" : "2x" },\n'
        '    { "filename" : "splash-2732x2732.png", "idiom" : "universal", "scale" : "3x" }\n'
        '  ],\n  "info" : { "author" : "xcode", "version" : 1 }\n}\n',
        encoding='utf-8',
    )

print('native assets prepared')
