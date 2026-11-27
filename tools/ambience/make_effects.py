"""يولّد مؤثرات أثير الصوتية (ليل بصراصير، عصافير الصباح، مطر ورعد، ضوضاء ناعمة).

كلها مُصنّعة رياضيًا هنا (بدون تسجيلات خارجية) فلا قيود ترخيص عليها.
كل ملف يُعاد بسلاسة: آخره يتداخل مع أوله.

  python tools/ambience/make_effects.py out_dir/ [name ...]
"""
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np

SR = 44100
LEN = 60.0
XF = 3.0


def rng(seed):
    return np.random.default_rng(seed)




def fft_filter(x, lo=None, hi=None):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    g = np.ones_like(f)
    if lo:
        g *= 1 / np.sqrt(1 + (lo / np.maximum(f, 1)) ** 4)
    if hi:
        g *= 1 / np.sqrt(1 + (f / hi) ** 4)
    return np.fft.irfft(X * g, len(x))


def pink(n, r):
    X = np.fft.rfft(r.standard_normal(n))
    f = np.fft.rfftfreq(n, 1 / SR)
    X /= np.sqrt(np.maximum(f, 20))
    y = np.fft.irfft(X, n)
    return y / np.abs(y).max()


def brown(n, r):
    X = np.fft.rfft(r.standard_normal(n))
    f = np.fft.rfftfreq(n, 1 / SR)
    X /= np.maximum(f, 20)
    y = np.fft.irfft(X, n)
    return y / np.abs(y).max()


def slow_lfo(n, r, rate=0.08, depth=0.35):
    t = np.arange(n) / SR
    ph = r.uniform(0, 2 * np.pi)
    return 1 - depth / 2 + depth / 2 * np.sin(2 * np.pi * rate * t + ph)


def pan(mono, p):
    return np.stack([mono * np.sqrt(1 - p), mono * np.sqrt(p)], 1)


def add_at(buf, sig, start):
    s = int(start * SR)
    e = min(len(buf), s + len(sig))
    if s < len(buf):
        buf[s:e] += sig[: e - s]


# ---------------------------------------------------------------- المؤثرات

def night(r, n):
    out = np.zeros((n, 2))
    # نسيم ليلي دافئ في الخلفية
    w = fft_filter(pink(n, r), 180, 900) * slow_lfo(n, r, 0.05, 0.5) * 0.18
    out += np.stack([w, np.roll(w, 800)], 1)
    # صراصير بأصوات ومواضع مختلفة
    for k in range(5):
        f0 = r.uniform(3900, 5200)
        p = r.uniform(0.15, 0.85)
        amp = r.uniform(0.05, 0.12) * (0.5 if k > 2 else 1)
        t = r.uniform(0, 1.0)
        period = r.uniform(0.55, 1.1)
        pulses = r.integers(2, 5)
        pulse = np.arange(int(0.022 * SR)) / SR
        env = np.sin(np.pi * pulse / pulse[-1]) ** 2
        chirp = np.sin(2 * np.pi * f0 * pulse) * env
        while t < LEN + XF:
            if r.random() > 0.12:
                for j in range(pulses):
                    add_at(out, pan(chirp * amp, p), t + j * 0.034)
            t += period * r.uniform(0.9, 1.1)
    # جوقة بعيدة
    far = fft_filter(r.standard_normal(n), 4200, 5600)
    am = 0.5 + 0.5 * np.sin(2 * np.pi * 28 * np.arange(n) / SR)
    out += pan(far * am * 0.02, 0.5)
    return out


def birds(r, n):
    out = np.zeros((n, 2))
    leaves = fft_filter(pink(n, r), 900, 6000) * slow_lfo(n, r, 0.11, 0.7) * 0.05
    out += np.stack([leaves, np.roll(leaves, 1500)], 1)
    species = []
    for _ in range(4):
        species.append(dict(f=r.uniform(2400, 4200), span=r.uniform(-900, 1400), d=r.uniform(0.05, 0.14),
                            notes=int(r.integers(2, 7)), gap=r.uniform(0.04, 0.12), p=r.uniform(0.1, 0.9),
                            amp=r.uniform(0.05, 0.11), every=r.uniform(3.5, 9)))
    for sp in species:
        t = r.uniform(0, 4)
        while t < LEN + XF - 2:
            for j in range(sp['notes']):
                d = sp['d'] * r.uniform(0.85, 1.15)
                tt = np.arange(int(d * SR)) / SR
                f = sp['f'] * r.uniform(0.95, 1.05) + sp['span'] * (tt / d) ** 1.5
                ph = 2 * np.pi * np.cumsum(f) / SR
                env = np.sin(np.pi * tt / d) ** 1.5
                tone = (np.sin(ph) + 0.25 * np.sin(2 * ph)) * env * sp['amp']
                add_at(out, pan(tone, sp['p']), t + j * (d + sp['gap']))
            t += sp['every'] * r.uniform(0.6, 1.5)
    return out


def thunder(r, n):
    out = np.zeros((n, 2))
    rainL = fft_filter(r.standard_normal(n), 600, 7000)
    rainR = fft_filter(r.standard_normal(n), 600, 7000)
    lfo = slow_lfo(n, r, 0.04, 0.4)
    out += np.stack([rainL, rainR], 1) * (0.09 * lfo)[:, None]
    # قطرات قريبة
    for _ in range(int(LEN * 14)):
        t = r.uniform(0, LEN + XF)
        d = int(r.uniform(0.004, 0.012) * SR)
        drop = r.standard_normal(d) * np.exp(-np.arange(d) / (d / 4)) * r.uniform(0.02, 0.07)
        add_at(out, pan(fft_filter(drop, 1500, 9000), r.uniform(0, 1)), t)
    # رعد بعيد مرّة كل ٢٠ ثانية تقريبًا
    t = r.uniform(5, 9)
    while t < LEN - 8:
        d = r.uniform(5, 8)
        m = int(d * SR)
        tt = np.arange(m) / SR
        env = (1 - np.exp(-tt / 0.35)) * np.exp(-tt / (d / 3.2))
        env *= 1 + 0.5 * np.sin(2 * np.pi * r.uniform(0.6, 1.4) * tt)
        rum = brown(m, r) * env
        crack = fft_filter(r.standard_normal(m), 150, 1200) * env * 0.35
        sig = (rum + crack) * r.uniform(0.45, 0.6)
        add_at(out, pan(sig, r.uniform(0.3, 0.7)), t)
        t += r.uniform(16, 26)
    return out


def softnoise(r, n):
    base = fft_filter(pink(n, r) + 0.6 * brown(n, r), 90, 2500)
    lfo = slow_lfo(n, r, 0.06, 0.25)
    return np.stack([base * lfo, np.roll(base, 2000) * lfo], 1) * 0.3


EFFECTS = {'night': night, 'birds': birds, 'thunder': thunder, 'softnoise': softnoise}


def loop(x):
    """تداخل آخر XF ثانية مع أولها لإعادة بلا قطع."""
    k = int(XF * SR)
    body = x[: len(x) - k].copy()
    fade = np.linspace(0, 1, k)[:, None]
    body[:k] = body[:k] * fade + x[len(x) - k:] * (1 - fade)
    return body


def render(name, out_dir: Path, seed=7):
    r = rng(seed + sum(map(ord, name)))
    n = int((LEN + XF) * SR)
    x = loop(EFFECTS[name](r, n))
    x /= max(1e-9, np.abs(x).max()) / 0.8
    with tempfile.TemporaryDirectory() as td:
        wav = Path(td) / 'x.f32'
        x.astype('<f4').tofile(wav)
        out = out_dir / f'{name}.m4a'
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'f32le', '-ar', str(SR), '-ac', '2', '-i', str(wav),
                        '-af', 'loudnorm=I=-24:TP=-3:LRA=11', '-ar', str(SR), '-c:a', 'aac', '-b:a', '64k',
                        '-movflags', '+faststart', str(out)], check=True)
    print(name, '→', out)


if __name__ == '__main__':
    out = Path(sys.argv[1] if len(sys.argv) > 1 else 'effects_out')
    out.mkdir(parents=True, exist_ok=True)
    for nm in (sys.argv[2:] or EFFECTS):
        render(nm, out)
