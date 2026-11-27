"""يضيف الأقسام الـ16 لـ«عوالم أثير» في Supabase لو مش موجودة.

- لا يحذف ولا يغيّر أي قصة.
- القسم الموجود بنفس الاسم (حتى لو بمعرّف تاني) مش بيتكرر.
- لو أعمدة 0006_worlds.sql موجودة، بيكمّل الوصف واللون الثاني للأقسام الجديدة.
آمن للتشغيل أكثر من مرة.

المتغيرات: SUPABASE_SERVICE_ROLE_KEY (و SUPABASE_URL اختياري).
"""
import json
import os
import re
import sys
import urllib.error
import urllib.request

URL = os.environ.get('SUPABASE_URL', 'https://scrynlokpplwolbltghf.supabase.co').rstrip('/')
KEY = os.environ['SUPABASE_SERVICE_ROLE_KEY']
HERE = os.path.dirname(os.path.abspath(__file__))


def req(method, path, body=None, prefer=None):
    h = {'apikey': KEY, 'Authorization': f'Bearer {KEY}', 'Content-Type': 'application/json'}
    if prefer:
        h['Prefer'] = prefer
    data = None if body is None else json.dumps(body).encode()
    r = urllib.request.Request(f'{URL}/rest/v1/{path}', data=data, method=method, headers=h)
    try:
        with urllib.request.urlopen(r, timeout=60) as res:
            txt = res.read().decode()
            return res.status, (json.loads(txt) if txt else None)
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()


def norm(s):
    s = re.sub(r'[\s.\-ـ«»]', '', s or '')
    s = re.sub('[أإآ]', 'ا', s)
    return s.replace('ة', 'ه').replace('ى', 'ي')


def main():
    seed = json.load(open(os.path.join(HERE, 'worlds_seed.json'), encoding='utf-8'))
    code, rows = req('GET', 'worlds?select=id,name,sort_order')
    if code != 200:
        sys.exit(f'تعذّر قراءة الأقسام: {code} {rows}')
    by_id = {r['id']: r for r in rows}
    by_name = {norm(r['name']): r for r in rows}
    seed_ids = {s['id'] for s in seed}
    matched = set()  # أقسام قديمة بنفس اسم قسم أساسي

    added = []
    for s in seed:
        old = by_id.get(s['id']) or by_name.get(norm(s['name']))
        if old:
            matched.add(old['id'])
            if old['id'] != s['id']:
                print(f'موجود بنفس الاسم: {old["name"]} ({old["id"]})')
                req('PATCH', f'worlds?id=eq.{old["id"]}', {'sort_order': s['sort_order']})
            continue
        row = {k: s[k] for k in ('id', 'name', 'tagline', 'color', 'art', 'sort_order')}
        row['short'] = s['name']
        code, out = req('POST', 'worlds', row, prefer='return=minimal,resolution=ignore-duplicates')
        if code not in (200, 201, 204):
            sys.exit(f'تعذّر إضافة {s["name"]}: {code} {out}')
        added.append(s)
        print(f'اتضاف: {s["name"]}')

    # الأقسام القديمة اللي مش من الـ16 تنزل بعدهم بنفس ترتيبها.
    for r in rows:
        if r['id'] not in seed_ids and r['id'] not in matched and (r.get('sort_order') or 0) < 100:
            req('PATCH', f'worlds?id=eq.{r["id"]}', {'sort_order': (r.get('sort_order') or 0) + 100})

    # الوصف واللون الثاني (محتاجين 0006_worlds.sql).
    extra_ok = True
    for s in seed:
        code, out = req('PATCH', f'worlds?id=eq.{s["id"]}&description=eq.', {'description': s['description'], 'color2': s['color2']})
        if code >= 400:
            extra_ok = False
            break
    print(f'خلص: اتضاف {len(added)} قسم.')
    if not extra_ok:
        print('ملاحظة: أعمدة الوصف مش موجودة لسه؛ شغّل supabase/migrations/0006_worlds.sql. التطبيق بيعرض الوصف من النسخة المضمّنة لحد كده.')


if __name__ == '__main__':
    main()
