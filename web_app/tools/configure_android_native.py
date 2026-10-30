from pathlib import Path
import shutil

root = Path(__file__).resolve().parents[1]
android = root / 'android'
res = android / 'app' / 'src' / 'main' / 'res'
pack = root / 'packaging' / 'android' / 'app' / 'src' / 'main' / 'res'

# Copy adaptive icons and density icons from the previously generated brand assets.
for density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']:
    src = pack / f'mipmap-{density}'
    dst = res / f'mipmap-{density}'
    dst.mkdir(parents=True, exist_ok=True)
    for name in ['ic_launcher.png', 'ic_launcher_round.png', 'ic_launcher_foreground.png']:
        if (src / name).exists():
            shutil.copy2(src / name, dst / name)
(res / 'mipmap-anydpi-v26').mkdir(parents=True, exist_ok=True)
for name in ['ic_launcher.xml', 'ic_launcher_round.xml']:
    shutil.copy2(pack / 'mipmap-anydpi-v26' / name, res / 'mipmap-anydpi-v26' / name)
shutil.copy2(pack / 'values' / 'ic_launcher_background.xml', res / 'values' / 'ic_launcher_background.xml')

# Splash: deep green background + brand bitmap.
shutil.copy2(root / 'packaging' / 'android' / 'app' / 'src' / 'main' / 'res' / 'drawable' / 'splash.png', res / 'drawable' / 'splash.png')
(res / 'values' / 'colors.xml').write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<resources>\n'
    '    <color name="brand_deep">#223027</color>\n'
    '    <color name="brand_bg">#F7F4ED</color>\n'
    '</resources>\n',
    encoding='utf-8',
)
launch = '''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/brand_deep" />
    <item>
        <bitmap android:gravity="center" android:src="@drawable/splash" />
    </item>
</layer-list>
'''
(res / 'drawable' / 'launch_background.xml').write_text(launch, encoding='utf-8')
(res / 'drawable-v21' / 'launch_background.xml').write_text(launch, encoding='utf-8')

# White notification silhouette (must be a solid white small icon).
(res / 'drawable').mkdir(parents=True, exist_ok=True)
(res / 'drawable' / 'ic_stat_tingyu.xml').write_text(
    '''<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp" android:height="24dp"
    android:viewportWidth="24" android:viewportHeight="24">
    <path android:fillColor="#FFFFFFFF"
        android:pathData="M12,2C18,6 21,12 18,18C16,21 13,22 12,22C11,22 8,21 6,18C3,12 6,6 12,2ZM12,7V19M9,11C10.5,10 13.5,10 15,11M8,14C10.5,12.8 13.5,12.8 16,14M9,17C10.5,16.2 13.5,16.2 15,17" />
</vector>
''',
    encoding='utf-8',
)

# Manifest
manifest = android / 'app' / 'src' / 'main' / 'AndroidManifest.xml'
s = manifest.read_text(encoding='utf-8')
s = s.replace('android:label="tingyu_web"', 'android:label="听隅"')
s = s.replace(
    '<application\n        android:label="听隅"\n        android:name="${applicationName}"\n        android:icon="@mipmap/ic_launcher">',
    '<application\n        android:label="听隅"\n        android:name="${applicationName}"\n        android:icon="@mipmap/ic_launcher"\n        android:roundIcon="@mipmap/ic_launcher_round"\n        android:enableOnBackInvokedCallback="true"\n        android:usesCleartextTraffic="false">',
)
s = s.replace(
    '<uses-permission android:name="android.permission.INTERNET" />',
    '<uses-permission android:name="android.permission.INTERNET" />\n'
    '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />\n'
    '    <uses-permission android:name="android.permission.VIBRATE" />\n'
    '    <uses-permission android:name="android.permission.WAKE_LOCK" />',
) if '<uses-permission android:name="android.permission.INTERNET" />' in s else s
if '<uses-permission android:name="android.permission.INTERNET" />' not in s:
    # Flutter default manifest usually has no permissions.
    insert = '''    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.VIBRATE" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
'''
    s = s.replace('</application>', '</application>\n' + insert)
manifest.write_text(s, encoding='utf-8')

# Gradle Kotlin DSL: application id, min sdk, release signing, app version.
gradle = android / 'app' / 'build.gradle.kts'
g = gradle.read_text(encoding='utf-8')
g = g.replace('namespace = "com.citro.tingyu_web"', 'namespace = "com.citro.tingyu_web"')
g = g.replace('applicationId = "com.citro.tingyu_web"', 'applicationId = "com.citro.tingyu"')
g = g.replace('minSdk = flutter.minSdkVersion', 'minSdk = 23')
g = g.replace(
    '''    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }''',
    '''    signingConfigs {
        create("release") {
            val propertiesFile = rootProject.file("../packaging/keys/keystore.properties")
            if (propertiesFile.exists()) {
                val properties = java.util.Properties()
                propertiesFile.inputStream().use { properties.load(it) }
                storeFile = rootProject.file("../packaging/keys/tingyu-release.jks")
                storePassword = properties.getProperty("storePassword")
                keyAlias = properties.getProperty("keyAlias")
                keyPassword = properties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }''',
)
gradle.write_text(g, encoding='utf-8')
print('android native configured')
