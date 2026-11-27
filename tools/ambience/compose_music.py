"""يؤلّف موسيقى الخلفية الهادئة لأثير ويسجّلها بآلات حقيقية.

كل المقطوعات مؤلفة هنا خوارزميًا (بذرة ثابتة = نفس الناتج كل مرة)، وتُعزف بمكتبة
أصوات FluidR3_GM (رخصة MIT) عبر fluidsynth، فالناتج ملكنا بالكامل ومسموح نشره.

الاستخدام:
  sudo apt-get install fluidsynth fluid-soundfont-gm ffmpeg
  pip install pretty_midi
  python tools/ambience/compose_music.py out_dir/
"""
import random
import subprocess
import sys
from pathlib import Path

import pretty_midi as pm

SF2 = '/usr/share/sounds/sf2/FluidR3_GM.sf2'

NOTE = {n: i for i, n in enumerate(['C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B'])}


def pc(name):
    return NOTE[name]


def chord_notes(root, quality):
    iv = {
        'maj': [0, 4, 7], 'min': [0, 3, 7], 'sus4': [0, 5, 7], 'sus2': [0, 2, 7],
        'maj7': [0, 4, 7, 11], 'min7': [0, 3, 7, 10], 'add9': [0, 4, 7, 14], 'min9': [0, 3, 7, 14],
        'dom7': [0, 4, 7, 10],
    }[quality]
    return [pc(root) + i for i in iv]


def near(pcs, lo, hi):
    """كل نغمات الفئات المعطاة داخل المدى [lo, hi]."""
    out = []
    for n in range(lo, hi + 1):
        if n % 12 in [p % 12 for p in pcs]:
            out.append(n)
    return out


class Song:
    def __init__(self, bpm, beats_per_bar, seed):
        self.m = pm.PrettyMIDI(initial_tempo=bpm)
        self.beat = 60.0 / bpm
        self.bpb = beats_per_bar
        self.rng = random.Random(seed)
        self.inst = {}

    def track(self, name, program, drum=False):
        i = pm.Instrument(program=program, is_drum=drum, name=name)
        self.m.instruments.append(i)
        self.inst[name] = i
        return i

    def note(self, name, pitch, start_beats, dur_beats, vel):
        r = self.rng
        t0 = start_beats * self.beat + r.uniform(0, 0.018)
        t1 = t0 + max(0.05, dur_beats * self.beat)
        v = int(max(1, min(127, vel + r.randint(-5, 5))))
        self.inst[name].notes.append(pm.Note(velocity=v, pitch=int(pitch), start=t0, end=t1))

    def cc(self, name, num, val, at_beats):
        self.inst[name].control_changes.append(pm.ControlChange(number=num, value=val, time=at_beats * self.beat))

    def pedal(self, name, bar_start, bar_len):
        self.cc(name, 64, 0, bar_start - 0.02 if bar_start > 0 else 0)
        self.cc(name, 64, 100, bar_start + 0.05)
        self.cc(name, 64, 0, bar_start + bar_len - 0.05)


def melody(song, name, chords, scale_pcs, lo, hi, vel, patterns, start_bar=0, phrase=4, rest_prob=0.15):
    """لحن هادئ: نغمة من الكورد على أول الزمن، وخطوات قريبة من السلّم بعدها."""
    r = song.rng
    scale = near(scale_pcs, lo, hi)
    prev = scale[len(scale) // 2]
    for bi, ch in enumerate(chords):
        bar = (start_bar + bi) * song.bpb
        tones = near(ch, lo, hi)
        end_phrase = (bi % phrase) == phrase - 1
        pat = [song.bpb] if end_phrase else r.choice(patterns)
        t = 0.0
        for k, d in enumerate(pat):
            if k > 0 and r.random() < rest_prob:
                t += d
                continue
            if k == 0 or end_phrase:
                cand = sorted(tones, key=lambda n: abs(n - prev))[:2]
                n = r.choice(cand)
            else:
                idx = min(range(len(scale)), key=lambda i: abs(scale[i] - prev))
                step = r.choice([-2, -1, -1, 1, 1, 2])
                idx = max(0, min(len(scale) - 1, idx + step))
                n = scale[idx]
            song.note(name, n, bar + t, d * 0.95, vel + (6 if k == 0 else 0))
            prev = n
            t += d


def arpeggio(song, name, chords, lo, hi, pattern_idx, step_beats, vel, start_bar=0, bass=None):
    for bi, ch in enumerate(chords):
        bar = (start_bar + bi) * song.bpb
        tones = near(ch, lo, hi)
        steps = int(round(song.bpb / step_beats))
        for s in range(steps):
            i = pattern_idx[s % len(pattern_idx)] % len(tones)
            song.note(name, tones[i], bar + s * step_beats, step_beats * 2.2, vel - (8 if s % 2 else 0))
        if bass is not None:
            song.note(bass[0], near([ch[0]], bass[1], bass[1] + 11)[0], bar, song.bpb, bass[2])


def pad(song, name, chords, lo, hi, vel, start_bar=0, every=1):
    for bi, ch in enumerate(chords):
        if bi % every:
            continue
        bar = (start_bar + bi) * song.bpb
        tones = near(ch, lo, hi)[:4]
        for n in tones:
            song.note(name, n, bar, song.bpb * every, vel)


def P(spec):
    """'D:maj A/C#:maj' → قائمة كوردات (نغمات)."""
    out = []
    for tok in spec.split():
        root, q = tok.split(':')
        root = root.split('/')[0]
        out.append(chord_notes(root, q))
    return out


# ---------------------------------------------------------------- المقطوعات

def calm_piano():
    s = Song(64, 4, 11)
    s.track('piano', 0)
    s.track('strings', 49)
    s.track('pad', 89)
    prog = P('D:add9 A:sus4 B:min7 G:maj7 D:maj G:add9 E:min7 A:sus4')
    cycles = 5
    for c in range(cycles):
        sb = c * len(prog)
        arpeggio(s, 'piano', prog, 50, 74, [0, 2, 4, 5, 3, 4, 2, 1], 0.5, 52, sb, bass=('piano', 38, 50))
        for b in range(len(prog)):
            s.pedal('piano', (sb + b) * 4, 4)
        if c >= 1:
            pad(s, 'strings', prog, 55, 69, 34 if c < 4 else 26, sb)
        if 1 <= c <= 3:
            melody(s, 'piano', prog, [pc(x) for x in 'D E F# G A B C#'.split()], 74, 88, 58,
                   [[2, 2], [1, 1, 2], [3, 1], [2, 1, 1]], sb)
        pad(s, 'pad', prog, 45, 60, 30, sb, every=2)
    return s, cycles * len(prog)


def lullaby():
    s = Song(76, 3, 23)
    s.track('box', 10)
    s.track('celesta', 8)
    s.track('pad', 89)
    prog = P('F:maj C:maj D:min Bb:maj F:maj C:maj Bb:maj C:sus4')
    tune = [  # لحن تهويدة بسيط (نغمة، مدة بالأزمنة) لكل مازورة
        [(77, 2), (76, 1)], [(74, 1), (76, 1), (79, 1)], [(77, 3)], [(74, 2), (72, 1)],
        [(72, 1), (77, 1), (81, 1)], [(79, 2), (76, 1)], [(74, 1), (77, 1), (74, 1)], [(72, 3)],
    ]
    cycles = 6
    for c in range(cycles):
        sb = c * len(prog)
        arpeggio(s, 'celesta', prog, 53, 72, [0, 2, 4], 1, 40, sb)
        pad(s, 'pad', prog, 48, 62, 28, sb)
        if c % 3 != 2:
            for bi, bar in enumerate(tune):
                t = 0
                for n, d in bar:
                    s.note('box', n + (12 if c % 3 == 1 and bi >= 4 else 0), (sb + bi) * 3 + t, d, 56)
                    t += d
        else:
            melody(s, 'box', prog, [pc(x) for x in 'F G A C D'.split()], 72, 86, 50, [[1, 1, 1], [2, 1]], sb)
    return s, cycles * len(prog)


def oriental_nights():
    s = Song(62, 4, 37)
    s.track('oud', 24)
    s.track('ney', 77)
    s.track('drone', 48)
    s.track('drum', 0, drum=True)
    hijaz = [pc(x) for x in 'D Eb F# G A Bb C'.split()]
    prog = P('D:maj D:maj C:min D:maj G:min C:min D:maj D:maj')
    cycles = 5
    for c in range(cycles):
        sb = c * len(prog)
        for bi, ch in enumerate(prog):
            bar = (sb + bi) * 4
            tones = near(ch, 50, 69)
            pat = [0, 2, 1, 3, 2, 1, 0, 2]
            for k, i in enumerate(pat):
                s.note('oud', tones[i % len(tones)], bar + k * 0.5, 1.2, 50 - (6 if k % 2 else 0))
            s.note('drone', 38, bar, 4, 30)
            s.note('drone', 45, bar, 4, 24)
            if 1 <= c <= 3:  # إيقاع خفيف جدًا (دُم تك)
                for t, n, v in [(0, 64, 30), (1.5, 63, 18), (2, 64, 24), (3, 63, 18)]:
                    s.note('drum', n, bar + t, 0.4, v)
        if c >= 1:
            melody(s, 'ney', prog, hijaz, 62, 81, 60, [[2, 2], [3, 1], [1, 1, 2], [4]], sb, rest_prob=0.25)
    return s, cycles * len(prog)


def warm_strings():
    s = Song(56, 4, 41)
    s.track('strings', 48)
    s.track('cello', 42)
    s.track('piano', 0)
    prog = P('A:min F:maj C:maj G:maj A:min D:min F:maj E:sus4')
    cycles = 4
    for c in range(cycles):
        sb = c * len(prog)
        pad(s, 'strings', prog, 57, 72, 44 if c else 36, sb)
        for bi, ch in enumerate(prog):
            bar = (sb + bi) * 4
            s.note('cello', near([ch[0]], 36, 47)[0], bar, 4, 50)
            if c >= 1:
                for k, n in enumerate(near(ch, 72, 84)[:3]):
                    s.note('piano', n, bar + k * 1.0 + 0.5, 2.5, 34)
        if c in (1, 2):
            melody(s, 'cello', prog, [pc(x) for x in 'A B C D E F G'.split()], 50, 64, 52,
                   [[2, 2], [3, 1], [4]], sb, rest_prob=0.1)
    return s, cycles * len(prog)


def harp_dream():
    s = Song(66, 4, 53)
    s.track('harp', 46)
    s.track('choir', 52)
    s.track('flute', 73)
    prog = P('C:maj7 D:add9 E:min7 A:min7 F:maj7 G:sus4 E:min7 F:maj7')
    cycles = 5
    for c in range(cycles):
        sb = c * len(prog)
        arpeggio(s, 'harp', prog, 48, 79, [0, 1, 2, 3, 4, 5, 4, 3], 0.5, 48, sb)
        pad(s, 'choir', prog, 55, 67, 30, sb)
        if c in (1, 3):
            melody(s, 'flute', prog, [pc(x) for x in 'C D E F# G A B'.split()], 72, 86, 46,
                   [[2, 2], [3, 1], [4]], sb, rest_prob=0.3)
    return s, cycles * len(prog)


def gentle_mystery():
    s = Song(58, 4, 67)
    s.track('vibes', 11)
    s.track('pad', 94)
    s.track('bass', 42)
    prog = P('D:min9 Bb:maj7 G:min7 A:sus4 D:min9 F:maj7 G:min7 A:min7')
    cycles = 4
    for c in range(cycles):
        sb = c * len(prog)
        pad(s, 'pad', prog, 57, 72, 34, sb)
        for bi, ch in enumerate(prog):
            s.note('bass', near([ch[0]], 45, 56)[0], (sb + bi) * 4, 4, 34)
        arpeggio(s, 'vibes', prog, 65, 84, [0, 2, 1, 3], 1.0, 46, sb)
        if c in (1, 2):
            melody(s, 'vibes', prog, [pc(x) for x in 'D E F G A Bb C'.split()], 74, 88, 44,
                   [[2, 2], [3, 1]], sb, rest_prob=0.35)
    return s, cycles * len(prog)


def bright_morning():
    s = Song(74, 4, 79)
    s.track('guitar', 24)
    s.track('flute', 73)
    s.track('strings', 49)
    prog = P('G:maj E:min C:maj D:sus4 G:maj B:min C:maj D:maj')
    cycles = 5
    for c in range(cycles):
        sb = c * len(prog)
        arpeggio(s, 'guitar', prog, 47, 71, [0, 3, 1, 4, 2, 4, 1, 3], 0.5, 50, sb, bass=('guitar', 40, 52))
        if c >= 1:
            pad(s, 'strings', prog, 55, 67, 28, sb)
        if 1 <= c <= 3:
            melody(s, 'flute', prog, [pc(x) for x in 'G A B D E'.split()], 74, 88, 52,
                   [[1, 1, 2], [2, 1, 1], [2, 2], [1, 1, 1, 1]], sb)
    return s, cycles * len(prog)


SONGS = {
    'calm': calm_piano,
    'lullaby': lullaby,
    'oriental': oriental_nights,
    'strings': warm_strings,
    'harp': harp_dream,
    'mystery': gentle_mystery,
    'morning': bright_morning,
}


def render(name, out_dir: Path):
    song, bars = SONGS[name]()
    length = bars * song.bpb * song.beat
    mid = out_dir / f'{name}.mid'
    wav = out_dir / f'{name}.wav'
    song.m.write(str(mid))
    subprocess.run(['fluidsynth', '-ni', '-q', '-g', '0.7', '-r', '44100',
                    '-o', 'synth.reverb.active=1', '-o', 'synth.reverb.room-size=0.85',
                    '-o', 'synth.reverb.damp=0.35', '-o', 'synth.reverb.width=0.9', '-o', 'synth.reverb.level=0.75',
                    '-o', 'synth.chorus.active=1', '-o', 'synth.chorus.level=0.6',
                    '-F', str(wav), SF2, str(mid)], check=True)
    tail = 5.0  # ذيل الصدى ثم خفوت، والبداية تظهر بنعومة (الإعادة تبدو كتنفّس)
    total = length + tail
    out = out_dir / f'{name}.m4a'
    af = (f'atrim=0:{total:.2f},highpass=f=70,lowpass=f=12000,'
          f'afade=t=in:st=0:d=2.5,afade=t=out:st={total - 6:.2f}:d=6,'
          'loudnorm=I=-19:TP=-2:LRA=9')
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', str(wav), '-af', af,
                    '-ar', '44100', '-ac', '2', '-c:a', 'aac', '-b:a', '80k', '-movflags', '+faststart', str(out)],
                   check=True)
    wav.unlink()
    mid.unlink()
    print(f'{name}: {total:.0f}s → {out}')


if __name__ == '__main__':
    out = Path(sys.argv[1] if len(sys.argv) > 1 else 'music_out')
    out.mkdir(parents=True, exist_ok=True)
    for n in (sys.argv[2:] or SONGS):
        render(n, out)
