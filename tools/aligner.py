#!/usr/bin/env python3
"""
ضبط نص القصة على صوت مسجَّل جاهز (بدون توليد صوت).

الفكرة: Whisper (مفتوح المصدر ومجاني، يعمل على GitHub Actions) يسمع الصوت ويعطي كل كلمة مع وقتها،
ثم نطابق كلمات النص الأصلي على ما سمعه حرفًا حرفًا. فلو أخطأ Whisper في كلمة أو تجاوزها
يظل النص الأصلي كما هو، ونقدّر وقت الكلمة الناقصة من جيرانها.

الاستخدام اليدوي للتجربة:  python tools/aligner.py audio.mp3 text.txt
"""
import bisect
import difflib
import os
import re
import sys

MODEL = os.environ.get('ALIGN_MODEL', 'medium')
MIN_RUN = 3  # أقل عدد كلمات متتالية متطابقة نعتبرها مرتكزًا موثوقًا

_TASHKEEL = re.compile('[ؐ-ًؚ-ٰٟۖ-ۭـ]')
_NON_WORD = re.compile(r'[^\w]', re.UNICODE)
_MAP = str.maketrans({'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا', 'ى': 'ي', 'ئ': 'ي', 'ؤ': 'و', 'ة': 'ه',
                      '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4', '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9'})


def norm(word):
    """كلمة بدون تشكيل ولا علامات، مع توحيد الألف والياء والتاء المربوطة."""
    w = _TASHKEEL.sub('', word).translate(_MAP).lower()
    return _NON_WORD.sub('', w).replace('_', '')


def align_words(script_words, heard, stats=None):
    """
    script_words: كلمات النص الأصلي بالترتيب.
    heard: [(كلمة, بداية, نهاية), ...] كما سمعها Whisper.
    يرجع [(بداية, نهاية), ...] لكل كلمة من كلمات النص.
    """
    # نبني سلسلة حروف لكل طرف، ونتذكّر لكل حرف كلمته.
    def build(words):
        chars, owner = [], []
        for i, w in enumerate(words):
            for c in w:
                chars.append(c)
                owner.append(i)
            chars.append(' ')
            owner.append(-1)
        return ''.join(chars), owner

    s_norm = [norm(w) for w in script_words]
    h_norm = [norm(w) for w, _, _ in heard]
    s_str, s_own = build(s_norm)
    h_str, h_own = build(h_norm)

    # لكل كلمة من النص: كلمات Whisper التي طابقت حروفها.
    hits = [[] for _ in script_words]
    sm = difflib.SequenceMatcher(None, s_str, h_str, autojunk=False)
    for a, b, n in sm.get_matching_blocks():
        for k in range(n):
            si, hi = s_own[a + k], h_own[b + k]
            if si >= 0 and hi >= 0:
                hits[si].append(hi)

    # مرشحات: مطابقة تغطي معظم الكلمة، ولا تأتي من كلمة مسموعة أطول منها بكثير (ضجيج).
    cand = [None] * len(script_words)
    for i, hs in enumerate(hits):
        if not hs or len(hs) < max(1, len(s_norm[i]) * 0.6):
            continue
        hw = sorted(set(hs))
        heard_len = sum(len(h_norm[h]) for h in hw)
        if heard_len and len(hs) / heard_len < 0.5:
            continue
        a, b = min(heard[h][1] for h in hw), max(heard[h][2] for h in hw)
        if b - a > max(2.5, 0.25 * len(s_norm[i])):  # كلمة واحدة لا تستغرق ثواني طويلة
            continue
        cand[i] = (a, b, hw[0], hw[-1])

    # نثق فقط في سلاسل من ٣ كلمات متتالية على الأقل سُمعت متتالية أيضًا؛
    # المطابقات المعزولة غالبًا صدفة (خصوصًا لو Whisper أخطأ في جزء من الصوت).
    def linked(i, j):
        x, y = cand[i], cand[j]
        return x and y and 0 <= y[2] - x[3] <= 3 and 0 <= y[0] - x[1] <= 3.0

    trusted = [False] * len(script_words)
    i = 0
    while i < len(cand):
        if not cand[i]:
            i += 1
            continue
        j = i
        while j + 1 < len(cand) and linked(j, j + 1):
            j += 1
        if j - i + 1 >= MIN_RUN:
            for k in range(i, j + 1):
                trusted[k] = True
        i = j + 1

    # ترتيب زمني صارم: أطول تتابع متصاعد من المرتكزات (بدل حذف كل ما يأتي بعد مرتكز خاطئ).
    idx = [i for i in range(len(cand)) if trusted[i]]
    prev = {}

    tails, tails_i = [], []
    for i in idx:
        st = cand[i][0]
        p = bisect.bisect_right(tails, st)
        prev[i] = tails_i[p - 1] if p > 0 else None
        if p == len(tails):
            tails.append(st)
            tails_i.append(i)
        else:
            tails[p] = st
            tails_i[p] = i
    keep = set()
    k = tails_i[-1] if tails_i else None
    while k is not None:
        keep.add(k)
        k = prev[k]
    if stats is not None:
        stats['anchored'] = len(keep) / max(1, len(script_words))
        # أطول فجوة زمنية بلا أي مرتكز (مؤشر على جزء لم يُسمع جيدًا)
        ts = [cand[i][0] for i in sorted(keep)]
        stats['max_gap'] = max([b - a for a, b in zip(ts, ts[1:])] or [0.0])
    times = [None] * len(script_words)
    last = 0.0
    for i in sorted(keep):
        a, b = max(cand[i][0], last), cand[i][1]
        times[i] = [a, max(b, a + 0.05)]
        last = times[i][1]

    # الكلمات بلا مطابقة: نوزّع الفجوة بين جارين معروفين حسب طول الكلمات.
    end_all = heard[-1][2] if heard else 0.0
    i = 0
    while i < len(times):
        if times[i] is not None:
            i += 1
            continue
        j = i
        while j < len(times) and times[j] is None:
            j += 1
        lo = times[i - 1][1] if i > 0 else (heard[0][1] if heard else 0.0)
        hi = times[j][0] if j < len(times) else max(end_all, lo + 0.3 * (j - i))
        hi = max(hi, lo)
        weights = [len(s_norm[k]) + 1 for k in range(i, j)]
        total = sum(weights) or 1
        t = lo
        for k, wgt in zip(range(i, j), weights):
            d = (hi - lo) * wgt / total
            times[k] = [t, t + d]
            t += d
        i = j
    return [(round(a, 2), round(b, 2)) for a, b in times]


_SENT = re.compile(r'(?<=[.!؟?…])\s+')


def split_long_lines(script, limit=160):
    """نص ملصوق كفقرة واحدة يصير سطرًا واحدًا طويلًا: نقسمه جملًا (بنفس المتحدث) قبل الضبط.
    يرجع عدد السطور الجديدة المضافة."""
    lines = script.get('lines') or []
    out = []
    for ln in lines:
        text = (ln.get('text') or '').strip()
        parts = [p.strip() for p in _SENT.split(text)] if len(text) > limit else [text]
        parts = [p for p in parts if p] or [text]
        for p in parts:
            out.append({**{k: v for k, v in ln.items() if k not in ('start', 'end', 'words')}, 'text': p})
    script['lines'] = out
    return len(out) - len(lines)


def apply_to_script(script, heard, stats=None):
    """يضع start و end و words لكل سطر في نص الفصل. يرجع نسبة التشابه بين النص وما سُمع.
    stats (اختياري) يُملأ بـ anchored (نسبة الكلمات المضبوطة على الصوت مباشرة) و max_gap."""
    lines = script.get('lines') or []
    words, owner = [], []
    for li, ln in enumerate(lines):
        for w in ln['text'].split():
            words.append(w)
            owner.append(li)
    if not words:
        raise RuntimeError('الفصل بلا نص')
    times = align_words(words, heard, stats)
    per_line = [[] for _ in lines]
    for (a, b), li in zip(times, owner):
        per_line[li].append([a, b])
    for ln, ws in zip(lines, per_line):
        if ws:
            ln['start'], ln['end'] = ws[0][0], ws[-1][1]
            ln['words'] = ws
    # نسبة التطابق: مؤشر لو كان النص لا يخص هذا الصوت
    h = ' '.join(norm(w) for w, _, _ in heard)
    s = ' '.join(norm(w) for w in words)
    return difflib.SequenceMatcher(None, s, h, autojunk=False).ratio() if h else 0.0


def load_wav16k(path):
    """يقرأ ملف wav أحادي 16 كيلوهرتز (من ffmpeg) كمصفوفة، بدون مكتبة av."""
    import wave

    import numpy as np
    with wave.open(str(path)) as wf:
        if wf.getframerate() != 16000 or wf.getnchannels() != 1 or wf.getsampwidth() != 2:
            raise RuntimeError('الصوت يجب أن يكون wav أحادي 16 كيلوهرتز')
        pcm = wf.readframes(wf.getnframes())
    return np.frombuffer(pcm, dtype=np.int16).astype(np.float32) / 32768.0


def transcribe(wav_path, prompt='', on_progress=None):
    """يرجع [(كلمة, بداية, نهاية), ...] من ملف wav أحادي 16 كيلوهرتز."""
    from faster_whisper import WhisperModel
    model = WhisperModel(MODEL, device='cpu', compute_type='int8')
    # بدون initial_prompt عمدًا: تمرير نص القصة كتلميح جعل Whisper يهلوس في أول ٣٠ ثانية
    # (كلمات إنجليزية وتوقيتات مشوّهة) فتجري الكلمات الأولى بعيدًا عن الصوت. بدونه يسمع بدقة وأسرع.
    segments, info = model.transcribe(
        load_wav16k(wav_path), language='ar', word_timestamps=True, vad_filter=True, beam_size=5,
        condition_on_previous_text=False)
    out = []
    for seg in segments:
        for w in seg.words or []:
            if w.word.strip():
                out.append((w.word.strip(), float(w.start), float(w.end)))
        if on_progress and info.duration:
            on_progress(seg.end, info.duration)
    return out


if __name__ == '__main__':
    audio, txt = sys.argv[1], sys.argv[2]
    text = open(txt, encoding='utf-8').read()
    script = {'lines': [{'text': t.strip()} for t in text.splitlines() if t.strip()]}
    heard = transcribe(audio, text)
    ratio = apply_to_script(script, heard)
    for ln in script['lines']:
        print(f"{ln.get('start', 0):7.2f} → {ln.get('end', 0):7.2f}  {ln['text']}")
    print(f'التطابق: {ratio:.0%}')
