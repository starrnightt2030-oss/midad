#!/usr/bin/env python3
"""
عامل الصوت لأثير (يعمل على GitHub Actions).

يقرأ الطلبات التي تضيفها لوحة الإدارة في جدول voice_jobs، وله نوعان:
- align (الأساسي): الصوت مرفوع جاهز من اللوحة، فنضبط توقيت كل سطر وكلمة من النص عليه بـ Whisper.
- tts (اختياري): نولّد صوت الفصل بـ Gemini TTS سطرًا سطرًا.
ثم يُحدَّث الفصل في Supabase.

المتغيرات: SUPABASE_SERVICE_ROLE_KEY، و GEMINI_API_KEY لطلبات التوليد فقط (و SUPABASE_URL اختياري).
"""
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import wave
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import atheer_studio as studio  # noqa: E402  (نعيد استخدام توليد السطر وقص الصمت)
import aligner  # noqa: E402

URL = os.environ.get('SUPABASE_URL', 'https://scrynlokpplwolbltghf.supabase.co').rstrip('/')
KEY = os.environ.get('SUPABASE_SERVICE_ROLE_KEY', '')
NARRATOR = 'الراوي'
NARRATOR_VOICE = {'voice': 'Charon', 'style': 'راوٍ دافئ هادئ يحكي قصة قبل النوم'}
OTHER_VOICES = ['Aoede', 'Puck', 'Fenrir', 'Leda', 'Orus', 'Kore']
TIME_BUDGET = float(os.environ.get('VOICE_TIME_BUDGET_MIN', '300')) * 60
STARTED = time.time()
log = studio.log


# ---------------------------------------------------------------- Supabase REST
def _req(method, path, body=None, headers=None, raw=False):
    h = {'apikey': KEY, 'Authorization': f'Bearer {KEY}'}
    data = None
    if body is not None:
        if isinstance(body, (bytes, bytearray)):
            data = bytes(body)
        else:
            data = json.dumps(body, ensure_ascii=False).encode()
            h['Content-Type'] = 'application/json'
    h.update(headers or {})
    r = urllib.request.Request(URL + path, data=data, method=method, headers=h)
    try:
        with urllib.request.urlopen(r, timeout=120) as res:
            out = res.read()
    except urllib.error.HTTPError as e:
        raise RuntimeError(f'{method} {path.split("?")[0]}: HTTP {e.code} {e.read()[:300].decode(errors="ignore")}') from None
    if raw:
        return out
    return json.loads(out) if out else None


def q(v):
    return urllib.parse.quote(str(v), safe='')


def select(table, query):
    return _req('GET', f'/rest/v1/{table}?{query}')


def patch(table, query, row, ret=False):
    return _req('PATCH', f'/rest/v1/{table}?{query}', row,
                {'Prefer': 'return=representation' if ret else 'return=minimal'})


def set_job(job_id, **fields):
    patch('voice_jobs', f'id=eq.{job_id}', fields)


def upload(bucket, path, data, ctype='audio/mp4'):
    _req('POST', f'/storage/v1/object/{bucket}/{path}', data, {'Content-Type': ctype, 'x-upsert': 'true'})


def remove_old(url_or_path, bucket):
    """يحذف الملف القديم من التخزين حتى لا تمتلئ المساحة المجانية."""
    if not url_or_path:
        return
    marker = f'/storage/v1/object/public/{bucket}/'
    path = url_or_path.split(marker, 1)[1] if marker in url_or_path else (url_or_path if bucket == 'premium' else '')
    if not path:
        return
    try:
        _req('DELETE', f'/storage/v1/object/{bucket}', {'prefixes': [path]})
    except Exception as e:  # الحذف ليس ضروريًا لنجاح الطلب
        log(f'  تعذّر حذف الملف القديم: {e}')


# ---------------------------------------------------------------- التوليد
def speaker_cfg(speakers, name, idx):
    sp = speakers.get(name)
    if isinstance(sp, str):
        sp = {'color': sp}
    sp = dict(sp or {})
    if name == NARRATOR:
        sp.setdefault('voice', NARRATOR_VOICE['voice'])
        sp.setdefault('style', NARRATOR_VOICE['style'])
    else:
        sp.setdefault('voice', OTHER_VOICES[idx % len(OTHER_VOICES)])
        sp.setdefault('style', 'أداء طبيعي معبّر بهدوء')
    return sp


def synthesize(client, script, on_progress):
    speakers = script.get('speakers') or {}
    lines = script.get('lines') or []
    if not lines:
        raise RuntimeError('الفصل بلا نص')
    names = []
    for ln in lines:
        if ln.get('speaker', NARRATOR) not in names:
            names.append(ln.get('speaker', NARRATOR))
    cfg = {n: speaker_cfg(speakers, n, i) for i, n in enumerate([n for n in names if n != NARRATOR])}
    cfg[NARRATOR] = speaker_cfg(speakers, NARRATOR, 0)

    out = bytearray(studio.silence(0.6))
    t, prev = 0.6, None
    for i, ln in enumerate(lines):
        if time.time() - STARTED > TIME_BUDGET:
            raise TimeoutError('انتهى وقت التشغيل؛ سيكمل في الدورة القادمة')
        name = ln.get('speaker', NARRATOR)
        sp = cfg.get(name) or cfg[NARRATOR]
        if prev is not None:
            gap = 0.85 if name != prev else 0.45
            out += studio.silence(gap)
            t += gap
        pcm = studio.trim_pcm(studio.tts_line(client, ln['text'], sp['voice'], ln.get('style') or sp['style']))
        dur = len(pcm) / 2 / studio.SAMPLE_RATE
        ln['start'], ln['end'] = round(t, 2), round(t + dur, 2)
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
        prev = name
        on_progress(i + 1, len(lines))
    out += studio.silence(1.0)
    t += 1.0
    # نحفظ الأصوات المختارة في النص حتى تبقى ثابتة عند إعادة التوليد
    for n, c in cfg.items():
        base = speakers.get(n) if isinstance(speakers.get(n), dict) else {'color': speakers.get(n) or '#B794F6'}
        speakers[n] = {**base, 'voice': c['voice'], 'style': c['style']}
    script['speakers'] = speakers
    return bytes(out), t


def encode_m4a(pcm, name):
    studio.CACHE.mkdir(parents=True, exist_ok=True)
    wav = studio.CACHE / f'{name}.wav'
    m4a = studio.CACHE / f'{name}.m4a'
    with wave.open(str(wav), 'wb') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(studio.SAMPLE_RATE)
        wf.writeframes(pcm)
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', str(wav), '-af', 'loudnorm=I=-18:TP=-1.5',
                    '-c:a', 'aac', '-b:a', '64k', '-movflags', '+faststart', str(m4a)], check=True)
    return m4a.read_bytes()


def load_chapter(job):
    wid, cid = job['work_id'], job['chapter_id']
    ch = select('chapters', f'work_id=eq.{q(wid)}&id=eq.{q(cid)}&select=*')
    wk = select('works', f'id=eq.{q(wid)}&select=id,title,world_id,is_premium')
    if not ch or not wk:
        raise RuntimeError('الفصل أو القصة غير موجودة')
    ch, wk = ch[0], wk[0]
    world = select('worlds', f'id=eq.{q(wk["world_id"])}&select=is_premium')
    premium = bool(wk['is_premium'] or (world and world[0]['is_premium']))
    log(f'▶ [{job.get("kind") or "tts"}] {wk["title"]} / {ch["title"]} {"(اشتراك)" if premium else ""}')
    return ch, wk, premium


def progress_reporter(job):
    last = [0.0]

    def on_progress(n, total, label=None):
        if time.time() - last[0] > 20 or n >= total:
            last[0] = time.time()
            txt = label or f'{n}/{total}'
            set_job(job['id'], progress=txt)
            log(f'  {txt}')
    return on_progress


def update_minutes(wid):
    """مدة القصة = مجموع فصولها."""
    durs = select('chapters', f'work_id=eq.{q(wid)}&select=duration_seconds')
    minutes = max(1, round(sum(float(d['duration_seconds'] or 0) for d in durs) / 60))
    patch('works', f'id=eq.{q(wid)}', {'minutes': minutes})


def process_tts(client, job):
    wid, cid = job['work_id'], job['chapter_id']
    ch, wk, premium = load_chapter(job)
    on_progress = progress_reporter(job)
    script = ch['script'] or {}
    pcm, dur = synthesize(client, script, on_progress)
    data = encode_m4a(pcm, f'{wid}-{cid}')
    path = f'{wid}/{cid}-{int(time.time())}.m4a'
    bucket = 'premium' if premium else 'audio'
    upload(bucket, path, data)
    row = {'script': script, 'duration_seconds': round(dur, 2)}
    if premium:
        row.update(audio='', audio_path=path)
    else:
        row.update(audio=f'{URL}/storage/v1/object/public/audio/{path}', audio_path='')
    patch('chapters', f'work_id=eq.{q(wid)}&id=eq.{q(cid)}', row)
    remove_old(ch.get('audio'), 'audio')
    remove_old(ch.get('audio_path'), 'premium')
    update_minutes(wid)
    log(f'  ✔ {dur / 60:.1f} دقيقة، {len(data) // 1024} ك.ب')


# ---------------------------------------------------------------- ضبط صوت مرفوع
def audio_source(ch):
    """(الحاوية، المسار) لملف الفصل المرفوع."""
    if ch.get('audio_path'):
        return 'premium', ch['audio_path']
    marker = '/storage/v1/object/public/audio/'
    a = ch.get('audio') or ''
    if marker in a:
        return 'audio', urllib.parse.unquote(a.split(marker, 1)[1].split('?')[0])
    return None, a


def download_audio(ch, dest):
    bucket, path = audio_source(ch)
    if bucket:
        data = _req('GET', f'/storage/v1/object/{bucket}/{urllib.parse.quote(path)}', raw=True)
    elif path.startswith('http'):
        with urllib.request.urlopen(path, timeout=300) as res:
            data = res.read()
    else:
        raise RuntimeError('ارفع ملف صوت الفصل أولًا ثم اطلب ضبط التوقيت')
    dest.write_bytes(data)
    return bucket, path, len(data)


def process_align(job):
    wid, cid = job['work_id'], job['chapter_id']
    ch, wk, premium = load_chapter(job)
    script = ch['script'] or {}
    if not script.get('lines'):
        raise RuntimeError('اكتب نص الفصل أو ارفعه أولًا')
    studio.CACHE.mkdir(parents=True, exist_ok=True)
    src = studio.CACHE / f'align-{wid}-{cid}.src'
    wav = studio.CACHE / f'align-{wid}-{cid}.wav'
    bucket, path, size = download_audio(ch, src)
    set_job(job['id'], progress='يسمع الصوت…')
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', str(src), '-ac', '1', '-ar', '16000', str(wav)], check=True)
    with wave.open(str(wav)) as wf:
        dur = wf.getnframes() / wf.getframerate()
    log(f'  الصوت {dur / 60:.1f} دقيقة، {size // 1024} ك.ب')

    added = aligner.split_long_lines(script)
    if added:
        log(f'  تقسيم الفقرات الطويلة: +{added} سطر')
    report = progress_reporter(job)
    heard = aligner.transcribe(str(wav), on_progress=lambda t, total: report(t, total, f'يسمع الصوت… {min(99, int(t * 100 / total))}%'))
    if not heard:
        raise RuntimeError('لم يُسمع كلام في ملف الصوت')
    stats = {}
    ratio = aligner.apply_to_script(script, heard, stats)
    log(f'  التطابق بين النص والصوت: {ratio:.0%}، كلمات مضبوطة مباشرة: {stats["anchored"]:.0%}، أطول فجوة: {stats["max_gap"]:.0f} ث')
    if ratio < 0.25:
        raise RuntimeError(f'النص لا يطابق الصوت (التطابق {ratio:.0%} فقط). تأكد أنه نص نفس التسجيل')
    if stats['anchored'] < 0.4:
        raise RuntimeError(f'لم يُضبط إلا {stats["anchored"]:.0%} من الكلمات على الصوت. تأكد أن النص هو نفس كلام التسجيل')

    row = {'script': script, 'duration_seconds': round(dur, 2)}
    # ملفات wav كبيرة جدًا على المساحة المجانية: نضغطها إلى m4a ونستبدلها
    if bucket and path.lower().endswith(('.wav', '.flac')):
        m4a = studio.CACHE / f'align-{wid}-{cid}.m4a'
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', str(src), '-af', 'loudnorm=I=-18:TP=-1.5',
                        '-c:a', 'aac', '-b:a', '80k', '-movflags', '+faststart', str(m4a)], check=True)
        data = m4a.read_bytes()
        new_path = f'{wid}/{cid}-{int(time.time())}.m4a'
        upload(bucket, new_path, data)
        if bucket == 'premium':
            row.update(audio='', audio_path=new_path)
        else:
            row.update(audio=f'{URL}/storage/v1/object/public/audio/{new_path}', audio_path='')
        log(f'  ضغط الصوت: {size // 1024} ← {len(data) // 1024} ك.ب')
    patch('chapters', f'work_id=eq.{q(wid)}&id=eq.{q(cid)}', row)
    if 'audio_path' in row and bucket:
        remove_old(path if bucket == 'premium' else ch.get('audio'), bucket)
    update_minutes(wid)
    log(f'  ✔ {len(script["lines"])} سطر متزامن')


def main():
    if not KEY:
        sys.exit('SUPABASE_SERVICE_ROLE_KEY غير موجود')
    # طلبات علقت في دورة سابقة (توقّف العامل) تعود للانتظار
    stale = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime(time.time() - 2 * 3600))
    patch('voice_jobs', f'status=eq.running&updated_at=lt.{stale}', {'status': 'pending'})

    jobs = select('voice_jobs', 'status=eq.pending&order=created_at.asc&select=*')
    if not jobs:
        log('لا توجد طلبات.')
        return
    client = None
    for job in jobs:
        tts = (job.get('kind') or 'tts') == 'tts'
        if tts and client is None:
            gemini = os.environ.get('GEMINI_API_KEY', '')
            if not gemini:
                set_job(job['id'], status='failed', error='توليد الصوت يحتاج مفتاح GEMINI_API_KEY في أسرار GitHub (مجاني من Google AI Studio). أو ارفع صوتك واطلب ضبط التوقيت')
                continue
            from google import genai
            client = genai.Client(api_key=gemini)
        claimed = patch('voice_jobs', f'id=eq.{job["id"]}&status=eq.pending', {'status': 'running', 'error': '', 'progress': ''}, ret=True)
        if not claimed:
            continue
        try:
            if tts:
                process_tts(client, job)
            else:
                process_align(job)
            set_job(job['id'], status='done', progress='')
        except TimeoutError as e:
            set_job(job['id'], status='pending', progress=str(e))
            log(str(e))
            break
        except Exception as e:
            log(f'  ✖ {e}')
            set_job(job['id'], status='failed', error=str(e)[:500])


if __name__ == '__main__':
    main()
