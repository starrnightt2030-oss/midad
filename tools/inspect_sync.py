#!/usr/bin/env python3
"""فحص تزامن فصل: يطبع توقيتات السطور من Supabase ويقارنها بالصوت الفعلي (للتشخيص فقط، لا يغيّر شيئًا).

الاستخدام: python tools/inspect_sync.py "<عنوان القصة>"
"""
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import voice_worker as vw  # noqa: E402

WHISPER = '--whisper' in sys.argv


def main(title):
    works = vw.select('works', f'title=eq.{vw.q(title)}&select=id,title')
    if not works:
        sys.exit(f'لا توجد قصة بعنوان {title}')
    for wk in works:
        chs = vw.select('chapters', f'work_id=eq.{vw.q(wk["id"])}&select=*&order=sort_order')
        jobs = vw.select('voice_jobs', f'work_id=eq.{vw.q(wk["id"])}&select=*&order=created_at.desc&limit=5')
        print('jobs:', json.dumps([{k: j.get(k) for k in ('kind', 'status', 'error', 'created_at', 'updated_at')} for j in jobs], ensure_ascii=False))
        for ch in chs:
            s = ch.get('script') or {}
            lines = s.get('lines') or []
            print(f'== {wk["title"]} / {ch["title"]}  lines={len(lines)} duration_seconds={ch.get("duration_seconds")}')
            print('audio:', (ch.get('audio') or '')[-60:], 'audio_path:', ch.get('audio_path'))
            src = Path('/tmp/inspect.src')
            try:
                vw.download_audio(ch, src)
                pr = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration,bit_rate,format_name:stream=codec_name,sample_rate,channels,bit_rate,start_time',
                                     '-of', 'json', str(src)], capture_output=True, text=True)
                print('ffprobe:', pr.stdout.replace('\n', ' '))
                dec = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(src), '-f', 'null', '-'], capture_output=True, text=True)
                print('decode errors:', dec.stderr[:300] or 'none')
            except Exception as e:
                print('audio download failed:', e)
            if WHISPER and src.exists():
                wav = Path('/tmp/inspect.wav')
                subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', str(src), '-ac', '1', '-ar', '16000', str(wav)], check=True)
                import aligner
                prompt = ' '.join(ln['text'] for ln in lines)
                heard = aligner.transcribe(str(wav), prompt)
                print(f'HEARD {len(heard)} words')
                for k in range(0, len(heard), 8):
                    print('H', ' | '.join(f'{w} {a:.2f}-{b:.2f}' for w, a, b in heard[k:k + 8]))
                k = 0
                for i, ln in enumerate(lines):
                    toks = (ln.get('text') or '').split()
                    ws = ln.get('words') or []
                    for j in range(0, len(toks), 8):
                        print(f'S{i:02d}', ' | '.join(f'{toks[t]} {ws[t][0]:.2f}-{ws[t][1]:.2f}' if t < len(ws) else toks[t] for t in range(j, min(j + 8, len(toks)))))
            for i, ln in enumerate(lines):
                toks = (ln.get('text') or '').split()
                ws = ln.get('words') or []
                print(f'{i:3d} {ln.get("start")!s:>7} → {ln.get("end")!s:>7}  words={len(ws)}/{len(toks)}  {" ".join(toks[:4])} … {" ".join(toks[-2:])}')
                if i < 2 and ws:
                    print('     first words:', ws[:6])


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    main(args[0] if args else 'حكايتي')
