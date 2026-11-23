#!/usr/bin/env python3
"""
أثير ستوديو — أداة تجهيز المحتوى لتطبيق «أثير».

الأوامر:
  add-work     إضافة عمل جديد (قصة/موعظة/معرفة...) إلى الفهرس
  add-chapter  إضافة فصل من ملف نصي بسيط
  voice        توليد الصوت للفصول التي ليس لها صوت (Gemini TTS) + توقيتات القراءة الحية
  covers       ربط وضبط الأغلفة الموجودة في content/covers تلقائيًا
  check        فحص الفهرس والتأكد من سلامة الملفات

صيغة الملف النصي للفصل (سطر لكل جملة، واسم المتحدث قبل النقطتين اختياري):
  الراوي: هدأت الريح أخيرًا...
  الأم: «تعالَ يا يوسف»
  سطر بدون اسم يُنسب إلى الراوي.

المتطلبات:
  pip install google-genai pillow
  ffmpeg مثبت على الجهاز
  متغير بيئة GEMINI_API_KEY (من Google AI Studio — الباقة المجانية تكفي للبداية)
"""
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / 'content'
CATALOG = CONTENT / 'catalog.json'
CACHE = ROOT / 'tools' / '.cache'

MODEL = os.environ.get('ATHEER_TTS_MODEL', 'gemini-2.5-flash-preview-tts')
SAMPLE_RATE = 24000
DEFAULT_SPEAKER = 'الراوي'
DEFAULT_VOICE = {'color': '#E8B04B', 'voice': 'Charon', 'style': 'راوٍ دافئ بنبرة درامية هادئة'}
ARTS = ['storm', 'lantern', 'traveler', 'deepsea', 'mind', 'morning']


# ---------------------------------------------------------------- أدوات عامة
def load_catalog():
    return json.loads(CATALOG.read_text(encoding='utf-8'))


def save_catalog(cat):
    CATALOG.write_text(json.dumps(cat, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')


def find_work(cat, wid):
    for w in cat['works']:
        if w['id'] == wid:
            return w
    sys.exit(f'لا يوجد عمل بالمعرّف: {wid}')


def slug_ok(s):
    return re.fullmatch(r'[a-z0-9][a-z0-9-]*', s) is not None


def log(*a):
    print(*a, flush=True)


# ---------------------------------------------------------------- الأغلفة
def process_cover(src: Path, wid: str) -> str:
    """يضبط الغلاف إلى 900×1200 JPG ويعيد مساره النسبي داخل content."""
    from PIL import Image, ImageOps
    dst = CONTENT / 'covers' / f'{wid}.jpg'
    dst.parent.mkdir(parents=True, exist_ok=True)
    im = Image.open(src).convert('RGB')
    im = ImageOps.fit(im, (900, 1200), method=Image.LANCZOS, centering=(0.5, 0.4))
    im.save(dst, 'JPEG', quality=84, optimize=True, progressive=True)
    if src.resolve() != dst.resolve() and src.parent.resolve() == dst.parent.resolve():
        src.unlink()
    return f'covers/{wid}.jpg'


def cmd_covers(args):
    cat = load_catalog()
    changed = False
    covers = CONTENT / 'covers'
    for w in cat['works']:
        wid = w['id']
        found = None
        for ext in ('jpg', 'jpeg', 'png', 'webp'):
            p = covers / f'{wid}.{ext}'
            if p.exists():
                found = p
                break
        if not found:
            continue
        need = found.suffix.lower() != '.jpg'
        if not need:
            from PIL import Image
            with Image.open(found) as im:
                need = im.size != (900, 1200)
        rel = process_cover(found, wid) if need else f'covers/{wid}.jpg'
        if w.get('cover') != rel or need:
            w['cover'] = rel
            changed = True
            log(f'غلاف: {wid} ← {rel}')
    if changed:
        save_catalog(cat)
    else:
        log('الأغلفة مضبوطة.')


# ---------------------------------------------------------------- إضافة محتوى
def parse_text(path: Path):
    lines = []
    for raw in path.read_text(encoding='utf-8').splitlines():
        t = raw.strip()
        if not t:
            continue
        m = re.match(r'^([^:«»"]{1,24}):\s*(.+)$', t)
        if m:
            lines.append({'speaker': m.group(1).strip(), 'text': m.group(2).strip()})
        else:
            lines.append({'speaker': DEFAULT_SPEAKER, 'text': t})
    return lines


def cmd_add_work(args):
    cat = load_catalog()
    if not slug_ok(args.id):
        sys.exit('المعرّف بالإنجليزية الصغيرة والأرقام والشرطة فقط، مثل: night-journey')
    if any(w['id'] == args.id for w in cat['works']):
        sys.exit('هذا المعرّف موجود بالفعل')
    if not any(x['id'] == args.world for x in cat['worlds']):
        sys.exit('العالم غير موجود. المتاح: ' + ', '.join(x['id'] for x in cat['worlds']))
    w = {
        'id': args.id, 'world': args.world, 'title': args.title, 'kind': args.kind,
        'description': args.desc, 'art': args.art, 'cover': '', 'narrator': args.narrator,
        'minutes': 0, 'chapters': [],
    }
    if args.cover:
        w['cover'] = process_cover(Path(args.cover), args.id)
    cat['works'].append(w)
    save_catalog(cat)
    log(f'تمت إضافة «{args.title}». أضف فصوله بالأمر add-chapter.')


def cmd_add_chapter(args):
    cat = load_catalog()
    w = find_work(cat, args.work)
    cid = args.id or f'ch{len(w["chapters"]) + 1}'
    lines = parse_text(Path(args.text))
    if not lines:
        sys.exit('الملف فارغ')
    speakers = {DEFAULT_SPEAKER: dict(DEFAULT_VOICE)}
    palette = ['#F2B8D8', '#7FD3D3', '#F6CF95', '#D3A8F2', '#8FDCC8', '#F2A7A0']
    voices = ['Aoede', 'Puck', 'Fenrir', 'Leda', 'Orus', 'Kore']
    for ln in lines:
        s = ln['speaker']
        if s not in speakers:
            i = len(speakers) - 1
            speakers[s] = {'color': palette[i % len(palette)], 'voice': voices[i % len(voices)], 'style': 'أداء طبيعي معبّر'}
    path = f'chapters/{w["id"]}-{cid}.json'
    (CONTENT / path).write_text(json.dumps({'title': args.title, 'speakers': speakers, 'lines': lines}, ensure_ascii=False, indent=1), encoding='utf-8')
    w['chapters'].append({'id': cid, 'title': args.title, 'script': path, 'audio': ''})
    save_catalog(cat)
    log(f'تمت إضافة الفصل «{args.title}» ({len(lines)} سطرًا). عدّل الأصوات من ملف {path} ثم شغّل: voice --work {w["id"]}')


# ---------------------------------------------------------------- توليد الصوت
def tts_line(client, text, voice, style):
    from google.genai import types
    prompt = f'اقرأ النص التالي بالعربية الفصحى بأسلوب: {style}. اقرأه كما هو دون إضافة أي كلمة:\n{text}'
    key = hashlib.sha1(f'{MODEL}|{voice}|{style}|{text}'.encode()).hexdigest()
    CACHE.mkdir(parents=True, exist_ok=True)
    f = CACHE / f'{key}.pcm'
    if f.exists():
        return f.read_bytes()
    delay = 20
    for attempt in range(8):
        try:
            r = client.models.generate_content(
                model=MODEL,
                contents=prompt,
                config=types.GenerateContentConfig(
                    response_modalities=['AUDIO'],
                    speech_config=types.SpeechConfig(
                        voice_config=types.VoiceConfig(prebuilt_voice_config=types.PrebuiltVoiceConfig(voice_name=voice))
                    ),
                ),
            )
            data = r.candidates[0].content.parts[0].inline_data.data
            f.write_bytes(data)
            return data
        except Exception as e:  # حدود الباقة المجانية: ننتظر ونعيد
            msg = str(e)
            wait = delay
            m = re.search(r'retry in (\d+(?:\.\d+)?)s', msg) or re.search(r"'retryDelay': '(\d+)s'", msg)
            if m:
                wait = float(m.group(1)) + 2
            log(f'  محاولة {attempt + 1}: {msg[:120]} — انتظار {int(wait)} ثانية')
            time.sleep(wait)
            delay = min(delay * 2, 120)
    raise RuntimeError('فشل توليد الصوت بعد عدة محاولات')


def trim_pcm(pcm: bytes, thr=450, pad_ms=70):
    import array
    a = array.array('h')
    a.frombytes(pcm[: len(pcm) - len(pcm) % 2])
    n = len(a)
    s = 0
    while s < n and abs(a[s]) < thr:
        s += 1
    e = n - 1
    while e > s and abs(a[e]) < thr:
        e -= 1
    pad = int(SAMPLE_RATE * pad_ms / 1000)
    s, e = max(0, s - pad), min(n, e + pad)
    return a[s:e].tobytes()


def silence(sec):
    return b'\x00\x00' * int(SAMPLE_RATE * sec)


def voice_chapter(client, w, ch):
    spath = CONTENT / ch['script']
    sc = json.loads(spath.read_text(encoding='utf-8'))
    speakers = sc.get('speakers', {})
    out = bytearray(silence(0.6))
    t = 0.6
    prev = None
    log(f'▶ {w["title"]} / {ch["title"]} ({len(sc["lines"])} سطرًا)')
    for i, ln in enumerate(sc['lines']):
        sp = speakers.get(ln['speaker']) or speakers.get(DEFAULT_SPEAKER) or DEFAULT_VOICE
        if isinstance(sp, str):
            sp = {'color': sp}
        voice = sp.get('voice', DEFAULT_VOICE['voice'])
        style = ln.get('style') or sp.get('style', DEFAULT_VOICE['style'])
        if prev is not None:
            gap = 0.85 if ln['speaker'] != prev else 0.45
            out += silence(gap)
            t += gap
        pcm = trim_pcm(tts_line(client, ln['text'], voice, style))
        dur = len(pcm) / 2 / SAMPLE_RATE
        ln['start'] = round(t, 2)
        ln['end'] = round(t + dur, 2)
        toks = ln['text'].split()
        weights = [len(x) + 1 for x in toks]
        total = sum(weights) or 1
        wt, words = t, []
        for wgt in weights:
            d = dur * wgt / total
            words.append([round(wt, 2), round(wt + d, 2)])
            wt += d
        ln['words'] = words
        out += pcm
        t += dur
        prev = ln['speaker']
        log(f'  {i + 1}/{len(sc["lines"])} ✓ {dur:.1f}s')
    out += silence(1.0)
    t += 1.0

    audio_dir = CONTENT / 'audio'
    audio_dir.mkdir(exist_ok=True)
    CACHE.mkdir(parents=True, exist_ok=True)
    wav = CACHE / f'{w["id"]}-{ch["id"]}.wav'
    with wave.open(str(wav), 'wb') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(bytes(out))
    dst = audio_dir / f'{w["id"]}-{ch["id"]}.m4a'
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', str(wav), '-af', 'loudnorm=I=-18:TP=-1.5',
                    '-c:a', 'aac', '-b:a', '64k', '-movflags', '+faststart', str(dst)], check=True)
    spath.write_text(json.dumps(sc, ensure_ascii=False, indent=1), encoding='utf-8')
    ch['audio'] = f'audio/{dst.name}'
    log(f'  ✔ {dst.relative_to(ROOT)} — {t / 60:.1f} دقيقة')
    return t


def cmd_voice(args):
    if not os.environ.get('GEMINI_API_KEY'):
        sys.exit('ضع مفتاح Gemini في متغير البيئة GEMINI_API_KEY')
    if not shutil.which('ffmpeg'):
        sys.exit('ffmpeg غير مثبت')
    from google import genai
    client = genai.Client(api_key=os.environ['GEMINI_API_KEY'])
    cat = load_catalog()
    works = [find_work(cat, args.work)] if args.work else cat['works']
    done = 0
    for w in works:
        total = 0.0
        for ch in w['chapters']:
            if args.chapter and ch['id'] != args.chapter:
                continue
            if ch.get('audio') and not args.force:
                continue
            total += voice_chapter(client, w, ch)
            done += 1
            save_catalog(cat)  # حفظ بعد كل فصل حتى لا يضيع التقدم
            if args.limit and done >= args.limit:
                break
        if total:
            w['minutes'] = max(w.get('minutes', 0), round(total / 60))
        if args.limit and done >= args.limit:
            break
    save_catalog(cat)
    log(f'تم توليد {done} فصل.' if done else 'لا توجد فصول تحتاج صوتًا.')


# ---------------------------------------------------------------- فحص
def cmd_check(args):
    cat = load_catalog()
    errors = 0
    worlds = {x['id'] for x in cat['worlds']}
    ids = set()
    for w in cat['works']:
        if w['id'] in ids:
            log(f'✗ معرّف مكرر: {w["id"]}')
            errors += 1
        ids.add(w['id'])
        if w['world'] not in worlds:
            log(f'✗ {w["id"]}: العالم {w["world"]} غير موجود')
            errors += 1
        if w.get('art') not in ARTS:
            log(f'! {w["id"]}: قيمة art غير معروفة ({w.get("art")})')
        if w.get('cover') and not w['cover'].startswith('http') and not (CONTENT / w['cover']).exists():
            log(f'✗ {w["id"]}: الغلاف غير موجود {w["cover"]}')
            errors += 1
        if not w.get('cover'):
            log(f'· {w["id"]}: بدون غلاف (سيُرسم غلاف فني تلقائيًا)')
        for ch in w['chapters']:
            if not (CONTENT / ch['script']).exists():
                log(f'✗ {w["id"]}/{ch["id"]}: ملف النص غير موجود')
                errors += 1
            else:
                json.loads((CONTENT / ch['script']).read_text(encoding='utf-8'))
            a = ch.get('audio')
            if a and not a.startswith('http') and not (CONTENT / a).exists():
                log(f'✗ {w["id"]}/{ch["id"]}: ملف الصوت غير موجود')
                errors += 1
            if not a:
                log(f'· {w["id"]}/{ch["id"]}: بدون صوت بعد (يعمل كنص مع قراءة حية تقديرية)')
    log('✔ الفهرس سليم' if not errors else f'✗ {errors} مشكلة')
    sys.exit(1 if errors else 0)


def main():
    ap = argparse.ArgumentParser(description='أثير ستوديو')
    sub = ap.add_subparsers(dest='cmd', required=True)

    p = sub.add_parser('add-work')
    p.add_argument('--id', required=True)
    p.add_argument('--world', required=True)
    p.add_argument('--title', required=True)
    p.add_argument('--kind', default='قصة')
    p.add_argument('--desc', default='')
    p.add_argument('--art', default='storm', choices=ARTS)
    p.add_argument('--narrator', default='صوت أثير')
    p.add_argument('--cover')
    p.set_defaults(fn=cmd_add_work)

    p = sub.add_parser('add-chapter')
    p.add_argument('--work', required=True)
    p.add_argument('--title', required=True)
    p.add_argument('--text', required=True, help='ملف نصي، سطر لكل جملة')
    p.add_argument('--id')
    p.set_defaults(fn=cmd_add_chapter)

    p = sub.add_parser('voice')
    p.add_argument('--work')
    p.add_argument('--chapter')
    p.add_argument('--force', action='store_true', help='إعادة التوليد حتى لو له صوت')
    p.add_argument('--limit', type=int, default=0, help='أقصى عدد فصول في هذه الجولة')
    p.set_defaults(fn=cmd_voice)

    p = sub.add_parser('covers')
    p.set_defaults(fn=cmd_covers)

    p = sub.add_parser('check')
    p.set_defaults(fn=cmd_check)

    a = ap.parse_args()
    a.fn(a)


if __name__ == '__main__':
    main()
