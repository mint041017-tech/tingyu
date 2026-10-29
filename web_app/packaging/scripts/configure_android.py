from pathlib import Path
import secrets

root = Path(__file__).resolve().parents[1]
res = root / 'android' / 'app' / 'src' / 'main' / 'res'

(res / 'values' / 'colors.xml').write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<resources>\n'
    '    <color name="colorPrimary">#4F6957</color>\n'
    '    <color name="colorPrimaryDark">#223027</color>\n'
    '    <color name="colorAccent">#AAC4A2</color>\n'
    '    <color name="brand_deep">#223027</color>\n'
    '    <color name="brand_bg">#F7F4ED</color>\n'
    '    <color name="brand_text">#35433E</color>\n'
    '</resources>\n',
    encoding='utf-8',
)

(res / 'values' / 'styles.xml').write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<resources>\n'
    '    <style name="AppTheme" parent="Theme.AppCompat.DayNight.NoActionBar">\n'
    '        <item name="colorPrimary">@color/colorPrimary</item>\n'
    '        <item name="colorPrimaryDark">@color/colorPrimaryDark</item>\n'
    '        <item name="colorAccent">@color/colorAccent</item>\n'
    '        <item name="android:windowBackground">@color/brand_bg</item>\n'
    '        <item name="android:statusBarColor">@color/brand_deep</item>\n'
    '        <item name="android:navigationBarColor">@color/brand_deep</item>\n'
    '        <item name="android:windowLightStatusBar">false</item>\n'
    '        <item name="android:windowLightNavigationBar">false</item>\n'
    '        <item name="android:forceDarkAllowed">false</item>\n'
    '        <item name="android:windowActionModeOverlay">true</item>\n'
    '    </style>\n\n'
    '    <style name="AppTheme.NoActionBar" parent="AppTheme">\n'
    '        <item name="windowActionBar">false</item>\n'
    '        <item name="windowNoTitle">true</item>\n'
    '        <item name="android:background">@null</item>\n'
    '    </style>\n\n'
    '    <style name="AppTheme.NoActionBarLaunch" parent="Theme.SplashScreen">\n'
    '        <item name="windowSplashScreenBackground">@color/brand_deep</item>\n'
    '        <item name="windowSplashScreenAnimatedIcon">@mipmap/ic_launcher_foreground</item>\n'
    '        <item name="postSplashScreenTheme">@style/AppTheme.NoActionBar</item>\n'
    '        <item name="android:background">@drawable/splash</item>\n'
    '    </style>\n'
    '</resources>\n',
    encoding='utf-8',
)

manifest = root / 'android' / 'app' / 'src' / 'main' / 'AndroidManifest.xml'
text = manifest.read_text(encoding='utf-8')
text = text.replace(
    '<application\n        android:allowBackup="true"',
    '<application\n        android:allowBackup="true"\n        android:enableOnBackInvokedCallback="true"\n        android:usesCleartextTraffic="false"',
)
text = text.replace(
    'android:launchMode="singleTask"\n            android:exported="true">',
    'android:launchMode="singleTask"\n            android:windowSoftInputMode="adjustResize"\n            android:exported="true">',
)
text = text.replace(
    '    <uses-permission android:name="android.permission.INTERNET" />',
    '    <uses-permission android:name="android.permission.INTERNET" />\n'
    '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />\n'
    '    <uses-permission android:name="android.permission.VIBRATE" />',
)
manifest.write_text(text, encoding='utf-8')

gradle = root / 'android' / 'app' / 'build.gradle'
g = gradle.read_text(encoding='utf-8')
g = g.replace('versionCode 1\n        versionName "1.0"', 'versionCode 10100\n        versionName "1.1.0"')
g = g.replace(
    """    buildTypes {
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }""",
    """    signingConfigs {
        release {
            def propertiesFile = rootProject.file('../keys/keystore.properties')
            if (propertiesFile.exists()) {
                def properties = new Properties()
                properties.load(new FileInputStream(propertiesFile))
                storeFile file(properties['storeFile'])
                storePassword properties['storePassword']
                keyAlias properties['keyAlias']
                keyPassword properties['keyPassword']
            }
        }
    }
    buildTypes {
        release {
            minifyEnabled false
            signingConfig signingConfigs.release
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }""",
)
gradle.write_text(g, encoding='utf-8')

keys = root / 'keys'
keys.mkdir(exist_ok=True)
password = secrets.token_urlsafe(18)
props = keys / 'keystore.properties'
props.write_text(
    'storeFile=../../keys/tingyu-release.jks\n'
    f'storePassword={password}\n'
    'keyAlias=tingyu\n'
    f'keyPassword={password}\n',
    encoding='utf-8',
)
print('android config patched; keystore password generated')
