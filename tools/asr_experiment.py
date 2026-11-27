"""تجربة مؤقتة: مقارنة إعدادات Whisper على أول ٤٠ ثانية من فصل."""
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import voice_worker as vw  # noqa: E402
import aligner  # noqa: E402
from faster_whisper import WhisperModel  # noqa: E402

wk = vw.select('works', 'title=eq.' + vw.q('حكايتي') + '&select=id')[0]
ch = vw.select('chapters', f'work_id=eq.{vw.q(wk["id"])}&select=*')[0]
src = Path('/tmp/e.src')
vw.download_audio(ch, src)
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', str(src), '-ac', '1', '-ar', '16000', '/tmp/e.wav'], check=True)
audio = aligner.load_wav16k('/tmp/e.wav')
text = ' '.join(l['text'] for l in ch['script']['lines'])
print('TEXT START:', text[:300])
model = WhisperModel('medium', device='cpu', compute_type='int8')
configs = {
    'current': dict(vad_filter=True, initial_prompt=text[:400], condition_on_previous_text=False),
    'no_prompt': dict(vad_filter=True, condition_on_previous_text=False),
    'no_vad_no_prompt': dict(vad_filter=False, condition_on_previous_text=False),
    'short_prompt': dict(vad_filter=True, initial_prompt=text[:120], condition_on_previous_text=False),
}
for name, kw in configs.items():
    t = time.time()
    segs, info = model.transcribe(audio[:16000 * 45], language='ar', word_timestamps=True, beam_size=5, **kw)
    words = [(w.word.strip(), w.start, w.end, w.probability) for s in segs for w in (s.words or [])]
    print(f'== {name} ({time.time() - t:.0f}s) words={len(words)}')
    print(' | '.join(f'{w} {a:.1f}-{b:.1f} p{p:.2f}' for w, a, b, p in words))
