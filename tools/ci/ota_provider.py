"""يضيف مزوّد الملفات الخاص بإضافة ota_update: تنزيل التحديث وتثبيته من داخل التطبيق."""
from pathlib import Path

PROVIDER = """
        <provider
            android:name="sk.fourq.otaupdate.OtaUpdateFileProvider"
            android:authorities="${applicationId}.ota_update_provider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/ota_filepaths" />
        </provider>
"""

PATHS = """<?xml version="1.0" encoding="utf-8"?>
<paths xmlns:android="http://schemas.android.com/apk/res/android">
    <files-path name="internal_apk_storage" path="ota_update/"/>
</paths>
"""


def apply(android_dir: Path) -> None:
    main = android_dir / 'app/src/main'
    manifest = main / 'AndroidManifest.xml'
    s = manifest.read_text(encoding='utf-8')
    if 'OtaUpdateFileProvider' not in s:
        s = s.replace('</application>', PROVIDER + '    </application>', 1)
    if 'REQUEST_INSTALL_PACKAGES' not in s:
        s = s.replace('<application', '<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>\n    <application', 1)
    manifest.write_text(s, encoding='utf-8')
    (main / 'res/xml').mkdir(parents=True, exist_ok=True)
    (main / 'res/xml/ota_filepaths.xml').write_text(PATHS, encoding='utf-8')
    _desugaring(android_dir)
    print('ota_update provider added ✓')


def _desugaring(android_dir: Path) -> None:
    """ota_update تحتاج core library desugaring في تطبيق أندرويد."""
    kts = android_dir / 'app/build.gradle.kts'
    groovy = android_dir / 'app/build.gradle'
    f = kts if kts.exists() else groovy
    s = f.read_text(encoding='utf-8')
    if 'oreLibraryDesugaring' in s:
        return
    if 'compileOptions {' not in s:
        raise SystemExit(f'ota: unexpected {f.name} layout, cannot enable desugaring')
    if f is kts:
        s = s.replace('compileOptions {', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true', 1)
        s += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    else:
        s = s.replace('compileOptions {', 'compileOptions {\n        coreLibraryDesugaringEnabled true', 1)
        s += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
    f.write_text(s, encoding='utf-8')
