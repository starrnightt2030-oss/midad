"""يربط بناء release بمفتاح توقيع ثابت حتى يُثبَّت كل تحديث فوق النسخة القديمة.

يُستدعى من سكربتات تجهيز أندرويد بعد `flutter create`. لو متغير ATHEER_KEYSTORE غير موجود
(مثلًا في طلبات الدمج) يبقى التوقيع الافتراضي كما هو.
"""
import os
from pathlib import Path

ALIAS = 'atheer'


def apply(android_dir: Path) -> None:
    store = os.environ.get('ATHEER_KEYSTORE', '')
    if not store or not Path(store).is_file():
        print('signing: no ATHEER_KEYSTORE, keeping default signing')
        return
    kts = android_dir / 'app/build.gradle.kts'
    groovy = android_dir / 'app/build.gradle'
    if kts.exists():
        f, block = kts, f'''    signingConfigs {{
        create("atheer") {{
            storeFile = file(System.getenv("ATHEER_KEYSTORE"))
            storePassword = System.getenv("ATHEER_KEY_PASSWORD")
            keyAlias = "{ALIAS}"
            keyPassword = System.getenv("ATHEER_KEY_PASSWORD")
        }}
    }}
'''
        old, new = 'signingConfigs.getByName("debug")', 'signingConfigs.getByName("atheer")'
    else:
        f, block = groovy, f'''    signingConfigs {{
        atheer {{
            storeFile file(System.getenv("ATHEER_KEYSTORE"))
            storePassword System.getenv("ATHEER_KEY_PASSWORD")
            keyAlias "{ALIAS}"
            keyPassword System.getenv("ATHEER_KEY_PASSWORD")
        }}
    }}
'''
        old, new = 'signingConfig signingConfigs.debug', 'signingConfig signingConfigs.atheer'
    s = f.read_text(encoding='utf-8')
    if old not in s or '    buildTypes {' not in s:
        raise SystemExit(f'signing: unexpected {f.name} layout, cannot attach release key')
    s = s.replace('    buildTypes {', block + '\n    buildTypes {', 1).replace(old, new)
    f.write_text(s, encoding='utf-8')
    print(f'signing: release key attached to {f.name} ✓')
