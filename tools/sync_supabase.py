"""ينقل المحتوى من مجلد content/ إلى Supabase (العوالم، الأعمال، الفصول، الأجواء).

الاستخدام:
    export SUPABASE_SERVICE_ROLE_KEY=...      # من Settings ← API (سري، لا تضعه في الكود)
    python tools/sync_supabase.py             # رفع/تحديث كل شيء
    python tools/sync_supabase.py --dry-run   # عرض ما سيُرفع فقط
    python tools/sync_supabase.py --sql out.sql  # كتابة SQL بدل الرفع

آمن للتشغيل أكثر من مرة: يحدّث الموجود ويضيف الجديد، ولا يحذف شيئًا.
لا يغيّر حقول الإدارة (is_premium, allow_download, published, publish_at, scene)
للعناصر الموجودة؛ تلك تُدار من لوحة الإدارة.
"""
import argparse
import json
import os
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / 'content'
DEFAULT_URL = 'https://scrynlokpplwolbltghf.supabase.co'
RAW_BASE = 'https://raw.githubusercontent.com/starrnightt2030-oss/midad/main/content/'


def abs_url(path: str) -> str:
    """المسارات النسبية (covers/.., audio/..) تُحوَّل لروابط GitHub كاملة."""
    path = (path or '').strip()
    if not path or path.startswith('http://') or path.startswith('https://'):
        return path
    return RAW_BASE + path


def build_rows():
    cat = json.loads((CONTENT / 'catalog.json').read_text(encoding='utf-8'))
    worlds = [{
        'id': w['id'], 'name': w.get('name', ''), 'short': w.get('short', w.get('name', '')),
        'tagline': w.get('tagline', ''), 'color': w.get('color', '#B794F6'),
        'art': w.get('art', 'storm'), 'cover': abs_url(w.get('cover', '')), 'sort_order': i,
    } for i, w in enumerate(cat.get('worlds', []))]
    ambience = [{
        'id': a['id'], 'name': a.get('name', ''), 'icon': a.get('icon', 'music'),
        'file': abs_url(a['file']), 'sort_order': i,
    } for i, a in enumerate(cat.get('ambience', []))]
    works, chapters = [], []
    for i, w in enumerate(cat.get('works', [])):
        works.append({
            'id': w['id'], 'world_id': w['world'], 'title': w.get('title', ''), 'kind': w.get('kind', ''),
            'description': w.get('description', ''), 'art': w.get('art', 'storm'),
            'cover': abs_url(w.get('cover', '')), 'narrator': w.get('narrator', ''),
            'minutes': int(w.get('minutes') or 0), 'sort_order': i,
        })
        for j, ch in enumerate(w.get('chapters', [])):
            sp = CONTENT / ch['script']
            script = json.loads(sp.read_text(encoding='utf-8')) if sp.exists() else {'speakers': {}, 'lines': []}
            script.pop('title', None)
            lines = script.get('lines') or []
            dur = max((ln.get('end', 0) for ln in lines), default=0)
            chapters.append({
                'work_id': w['id'], 'id': ch['id'], 'sort_order': j, 'title': ch.get('title', ''),
                'script': script, 'audio': abs_url(ch.get('audio', '')), 'duration_seconds': dur,
            })
    return {'worlds': worlds, 'ambience': ambience, 'works': works, 'chapters': chapters}


def upsert(url, key, table, rows, conflict):
    if not rows:
        return
    req = urllib.request.Request(
        f'{url}/rest/v1/{table}?on_conflict={conflict}',
        data=json.dumps(rows, ensure_ascii=False).encode('utf-8'),
        method='POST',
        headers={
            'apikey': key, 'Authorization': f'Bearer {key}', 'Content-Type': 'application/json',
            'Prefer': 'resolution=merge-duplicates,return=minimal',
        })
    with urllib.request.urlopen(req, timeout=60) as r:
        if r.status >= 300:
            raise SystemExit(f'{table}: HTTP {r.status}')
    print(f'✓ {table}: {len(rows)}')


def sql_literal(v):
    if v is None:
        return 'null'
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, (dict, list)):
        v = json.dumps(v, ensure_ascii=False)
        return "'" + v.replace("'", "''") + "'::jsonb"
    return "'" + str(v).replace("'", "''") + "'"


def to_sql(table, rows, conflict):
    out = []
    for r in rows:
        cols = list(r)
        keys = conflict.split(',')
        upd = ', '.join(f'{c} = excluded.{c}' for c in cols if c not in keys)
        out.append(f'insert into public.{table} ({", ".join(cols)}) values ({", ".join(sql_literal(r[c]) for c in cols)}) '
                   f'on conflict ({conflict}) do update set {upd};')
    return '\n'.join(out)


PLAN = [('worlds', 'id'), ('ambience', 'id'), ('works', 'id'), ('chapters', 'work_id,id')]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--sql')
    a = ap.parse_args()
    data = build_rows()
    if a.dry_run:
        for t, _ in PLAN:
            print(f'{t}: {len(data[t])}')
        return
    if a.sql:
        Path(a.sql).write_text('\n'.join(to_sql(t, data[t], c) for t, c in PLAN) + '\n', encoding='utf-8')
        print(f'✓ {a.sql}')
        return
    key = os.environ.get('SUPABASE_SERVICE_ROLE_KEY', '').strip()
    if not key:
        print('::warning::SUPABASE_SERVICE_ROLE_KEY غير موجود، تم تخطي المزامنة')
        return
    url = os.environ.get('SUPABASE_URL', DEFAULT_URL).rstrip('/')
    for t, c in PLAN:
        upsert(url, key, t, data[t], c)


if __name__ == '__main__':
    sys.exit(main())
