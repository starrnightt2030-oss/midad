#!/usr/bin/env python3
"""
ضبط نص القصة على صوت مسجَّل جاهز (بدون توليد صوت).

الفكرة: Whisper (مفتوح المصدر ومجاني، يعمل على GitHub Actions) يسمع الصوت ويعطي كل كلمة مع وقتها،
ثم نطابق كلمات النص الأصلي على ما سمعه حرفًا حرفًا. فلو أخطأ Whisper في كلمة أو تجاوزها
يظل النص الأصلي كما هو، ونقدّر وقت الكلمة الناقصة من جيرانها.

الاستخدام اليدوي للتجربة:  python tools/aligner.py audio.mp3 text.txt
"""
import difflib
import os
import re
import sys

MODEL = os.environ.get('ALIGN_MODEL', 'medium')

_TASHKEEL = re.compile('[ؐ-ًؚ-ٰٟۖ-ۭـ]')
_NON_WORD = re.compile(r'[^\w]', re.UNICODE)
_MAP = str.maketrans({'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا', 'ى': 'ي', 'ئ': 'ي', 'ؤ': 'و', 'ة': 'ه',
                      '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4', '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9'})


def norm(word):
    """كلمة بدون تشكيل ولا علامات، مع توحيد الألف والياء والتاء المربوطة."""
    w = _TASHKEEL.sub('', word).translate(_MAP).lower()
    return _NON_WORD.sub('', w).replace('_', '')


def align_words(script_words, heard):
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

    times = [None] * len(script_words)
    for i, hs in enumerate(hits):
        # نقبل المطابقة لو غطّت جزءًا معقولًا من الكلمة (حتى لا تلتصق كلمة بحرف عابر).
        if hs and len(hs) >= max(1, len(s_norm[i]) * 0.4):
            times[i] = [min(heard[h][1] for h in hs), max(heard[h][2] for h in hs)]

    # ترتيب متصاعد: نتجاهل أي مطابقة ترجع بالزمن للخلف.
    last = 0.0
    for i, t in enumerate(times):
        if t is None:
            continue
        if t[0] < last - 0.05:
            times[i] = None
            continue
        t[1] = max(t[1], t[0] + 0.05)
        last = t[1]

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


def apply_to_script(script, heard):
    """يضع start و end و words لكل سطر في نص الفصل. يرجع نسبة الكلمات التي طابقت فعلًا."""
    lines = script.get('lines') or []
    words, owner = [], []
    for li, ln in enumerate(lines):
        for w in ln['text'].split():
            words.append(w)
            owner.append(li)
    if not words:
        raise RuntimeError('الفصل بلا نص')
    times = align_words(words, heard)
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
    segments, info = model.transcribe(
        load_wav16k(wav_path), language='ar', word_timestamps=True, vad_filter=True, beam_size=5,
        initial_prompt=prompt[:400] or None, condition_on_previous_text=False)
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
