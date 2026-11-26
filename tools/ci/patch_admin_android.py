"""يجهّز مجلد android لتطبيق لوحة الإدارة بعد `flutter create`: الاسم، الإنترنت، والأيقونة."""
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / 'admin'
manifest = APP / 'android/app/src/main/AndroidManifest.xml'
s = manifest.read_text(encoding='utf-8')
if 'android.permission.INTERNET' not in s:
    s = s.replace('<application', '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)
s = re.sub(r'android:label="[^"]*"', 'android:label="إدارة أثير"', s, count=1)
manifest.write_text(s, encoding='utf-8')

res_src = ROOT / 'branding/android/res'
res_dst = APP / 'android/app/src/main/res'
for d in res_src.iterdir():
    for f in d.iterdir():
        (res_dst / d.name).mkdir(parents=True, exist_ok=True)
        shutil.copy(f, res_dst / d.name / f.name)

for p in res_dst.glob('drawable*/launch_background.xml'):
    p.write_text('''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item><color android:color="#130B22" /></item>
</layer-list>
''', encoding='utf-8')

print('admin android patched ✓')
