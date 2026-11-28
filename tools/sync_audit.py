#!/usr/bin/env python3
"""فحص تزامن كل الفصول (تشخيص فقط، لا يغيّر شيئًا).

لكل فصل له صوت:
  ١) بيانات الملف الذي يشغّله التطبيق فعلًا (الصيغة، معدل البت، رأس Xing/VBRI، المدة).
  ٢) هل سيستخدم التطبيق التوقيتات الحقيقية أم سيرجع للتقدير؟ (نفس منطق ensureTimings في lib/models.dart)
  ٣) يسمع Whisper ثلاث نوافذ (أول/وسط/آخر الملف) ويقارن وقت كل كلمة مسموعة بوقتها المحفوظ.
     الفرق الموجب = النص المحفوظ متأخر عن الصوت (الصوت يسبق الكلام).

الاستخدام: python tools/sync_audit.py [--title "<عنوان>"] [--no-whisper]
"""
import json
import re
import statistics
import subprocess
import sys
import wave
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import voice_worker as vw  # noqa: E402
import aligner  # noqa: E402

WIN = 60.0
TMP = Path('/tmp/audit')


def probe(src):
    pr = subprocess.run(['ffprobe', '-v', 'error', '-show_entries',
                         'format=duration,bit_rate,format_name:stream=codec_name,sample_rate,channels,bit_rate,start_time,duration',
                         '-of', 'json', str(src)], capture_output=True, text=True)
    try:
        return json.loads(pr.stdout)
    except Exception:
        return {}


def mp3_header(src):
    head = src.read_bytes()[:16384]
    return [t for t in ('Xing', 'Info', 'VBRI', 'LAME') if t.encode() in head]


def mp3_frame_bitrates(src, n=400):
    """معدل البت لأول n إطار: لو متغير بدون رأس Xing فإن ExoPlayer يقدّر المدة والقفز خطأ."""
    pr = subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'a:0', '-show_entries', 'packet=size,duration_time',
                         '-read_intervals', '%+#' + str(n), '-of', 'csv=p=0', str(src)], capture_output=True, text=True)
    rates = set()
    for ln in pr.stdout.split():
        try:
            dt, size = ln.split(',')[:2] if ',' in ln else (None, None)
            rates.add(round(int(size) * 8 / float(dt) / 1000))
        except Exception:
            pass
    return sorted(rates)


def dart_check(script):
    """نسخة من منطق التطبيق: هل التوقيتات الحقيقية تُستخدم؟"""
    lines = script.get('lines') or []
    issues = []
    for i, ln in enumerate(lines):
        st, en = ln.get('start'), ln.get('end')
        st = -1 if st is None else st
        en = -1 if en is None else en
        if not (st >= 0 and en > st):
            issues.append(f'line {i} no timing start={ln.get("start")} end={ln.get("end")} text={ln.get("text", "")[:40]!r}')
        toks = [t for t in re.split(r'\s+', ln.get('text') or '') if t]
        ws = ln.get('words') or []
        if len(ws) != len(toks):
            issues.append(f'line {i} words {len(ws)} != tokens {len(toks)} (word timings get replaced by an even spread)')
    all_timed = bool(lines) and not any('no timing' in s for s in issues)
    return all_timed, issues


def flat_words(script):
    out = []
    for ln in script.get('lines') or []:
        toks = (ln.get('text') or '').split()
        ws = ln.get('words') or []
        for t, w in zip(toks, ws):
            out.append((t, float(w[0]), float(w[1])))
    return out


def window_delta(wav, total, start, words):
    """Whisper على نافذة من الملف، ثم مطابقة كلماتها على كلمات النص المحفوظة في نفس المنطقة."""
    start = max(0.0, min(start, total - WIN))
    cut = TMP / 'win.wav'
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-ss', f'{start:.3f}', '-t', f'{WIN:.3f}', '-i', str(wav),
                    '-ac', '1', '-ar', '16000', str(cut)], check=True)
    heard = [(w, a + start, b + start) for w, a, b in aligner.transcribe(str(cut))]
    if not heard:
        return start, None, 0
    # كلمات النص المحفوظة قريبًا من النافذة (بهامش واسع يسمح بانحراف كبير)
    sub = [(t, a, b) for t, a, b in words if start - 40 <= a <= start + WIN + 40]
    if not sub:
        return start, None, 0
    times = aligner.align_words([t for t, _, _ in sub], heard)
    # نأخذ فقط الكلمات المتطابقة حرفيًا مع كلمة مسموعة (مرتكزات حقيقية)
    hn = {}
    for w, a, b in heard:
        hn.setdefault(aligner.norm(w), []).append(a)
    deltas = []
    for (t, sa, _), (na, _) in zip(sub, times):
        if not (start + 1 <= na <= start + WIN - 1):
            continue
        cands = hn.get(aligner.norm(t))
        if not cands or min(abs(c - na) for c in cands) > 0.3:
            continue
        deltas.append(sa - na)
    if not deltas:
        return start, None, 0
    return start, statistics.median(deltas), len(deltas)


def main():
    title = None
    if '--title' in sys.argv:
        title = sys.argv[sys.argv.index('--title') + 1]
    whisper = '--no-whisper' not in sys.argv
    TMP.mkdir(parents=True, exist_ok=True)
    works = vw.select('works', 'select=id,title' + (f'&title=eq.{vw.q(title)}' if title else ''))
    for wk in works:
        chs = vw.select('chapters', f'work_id=eq.{vw.q(wk["id"])}&select=*&order=sort_order')
        for ch in chs:
            if not (ch.get('audio') or ch.get('audio_path')):
                continue
            s = ch.get('script') or {}
            lines = s.get('lines') or []
            print(f'\n===== {wk["title"]} / {ch.get("title")}  lines={len(lines)} duration_seconds={ch.get("duration_seconds")}')
            print('audio:', ch.get('audio') or ch.get('audio_path'))
            all_timed, issues = dart_check(s)
            print(f'APP uses real timings: {all_timed}   issues={len(issues)}')
            for x in issues[:15]:
                print('   ', x)
            words = flat_words(s)
            if words:
                print(f'stored: first word {words[0][1]:.2f}s  last word end {words[-1][2]:.2f}s  words={len(words)}')
            src = TMP / 'src'
            try:
                vw.download_audio(ch, src)
            except Exception as e:
                print('download failed:', e)
                continue
            p = probe(src)
            print('ffprobe:', json.dumps(p, ensure_ascii=False))
            fmt = (p.get('format') or {}).get('format_name', '')
            if 'mp3' in fmt:
                print('mp3 headers:', mp3_header(src), ' frame bitrates (kbps, first 400 frames):', mp3_frame_bitrates(src))
            wav = TMP / 'full.wav'
            subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', str(src), '-vn', '-ac', '1', '-ar', '16000', str(wav)], check=True)
            with wave.open(str(wav)) as wf:
                total = wf.getnframes() / wf.getframerate()
            print(f'decoded duration {total:.2f}s  container duration {(p.get("format") or {}).get("duration")}')
            if not whisper or not words:
                continue
            for pos in (0.0, total / 2 - WIN / 2, total - WIN):
                st, d, n = window_delta(wav, total, pos, words)
                if d is None:
                    print(f'  window @{st:7.1f}s: no matches')
                else:
                    print(f'  window @{st:7.1f}s: stored - heard = {d:+.2f}s  (median of {n} words)')


if __name__ == '__main__':
    main()
