#!/usr/bin/env python3
"""يبني أقنعة المشاهد الحية من مواصفات JSON قابلة للتعديل.

لكل مشهد ملف tools/ambient/masks/<id>.json يصف مناطق الحركة بإحداثيات
نسبية (0..1) على الصورة الأصلية نفسها، فتكون الأقنعة مطابقة لبكسلات الصورة.
الناتج assets/ambient/<id>/mask.webp (RGB بدون ضغط فاقد):
  R / G / B = ثلاث قنوات مستقلة، كل مؤثر في scene.json يختار قناته.

الاستخدام:
  python3 tools/ambient/build_masks.py            # كل المشاهد
  python3 tools/ambient/build_masks.py 01_moonlight_lake --preview out/

--preview يحفظ صورة تحقق: القناع ملوّن فوق الصورة، لمراجعة الحدود بالعين.

صيغة الملف:
{
  "scale": 0.5,                       // دقة القناع نسبةً للصورة
  "channels": {
    "r": {
      "add":  [shape, ...],           // مناطق تُضاف (أقصى قيمة)
      "sub":  [shape, ...],           // مناطق تُستبعد (صخور، مبانٍ...)
      "keep": cond, "drop": cond,     // تنقية باللون داخل المنطقة
      "grow": 0, "feather": 3, "gain": 1.0
    }
  }
}
shape: {"poly": [[x,y],...]} | {"rect": [x0,y0,x1,y1]} | {"ellipse": [cx,cy,rx,ry]}
       + اختياري "v": القيمة، "grad": [أعلى, أسفل] تدرج رأسي داخل الشكل.
cond:  {"lum": [lo,hi], "sat": [lo,hi], "hue": [lo,hi], "warm": min(r-b)}
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SPECS = os.path.join(ROOT, 'tools', 'ambient', 'masks')
ASSETS = os.path.join(ROOT, 'assets', 'ambient')


def shape_mask(shape, w, h):
    img = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(img)
    v = int(round(255 * float(shape.get('v', 1.0))))
    if 'poly' in shape:
        pts = [(x * w, y * h) for x, y in shape['poly']]
        d.polygon(pts, fill=v)
        ys = [p[1] for p in pts]
    elif 'rect' in shape:
        x0, y0, x1, y1 = shape['rect']
        d.rectangle([x0 * w, y0 * h, x1 * w, y1 * h], fill=v)
        ys = [y0 * h, y1 * h]
    elif 'ellipse' in shape:
        cx, cy, rx, ry = shape['ellipse']
        d.ellipse([(cx - rx) * w, (cy - ry) * h, (cx + rx) * w, (cy + ry) * h], fill=v)
        ys = [(cy - ry) * h, (cy + ry) * h]
    else:
        raise ValueError(f'unknown shape {shape}')
    a = np.asarray(img, dtype=np.float32) / 255.0
    if 'grad' in shape:
        top, bot = shape['grad']
        y0, y1 = max(min(ys), 0), min(max(ys), h - 1)
        yy = np.clip((np.arange(h) - y0) / max(y1 - y0, 1), 0, 1)
        a = a * (top + (bot - top) * yy)[:, None]
    return a


def color_cond(cond, rgb, hsv):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    out = np.ones(lum.shape, dtype=np.float32)

    def band(x, lo, hi, soft=0.04):
        return np.clip((x - lo) / soft + 0.5, 0, 1) * np.clip((hi - x) / soft + 0.5, 0, 1)

    if 'lum' in cond:
        out *= band(lum, *cond['lum'])
    if 'sat' in cond:
        out *= band(hsv[..., 1], *cond['sat'])
    if 'hue' in cond:
        lo, hi = cond['hue']
        hue = hsv[..., 0] * 360.0
        if lo <= hi:
            out *= band(hue, lo, hi, 8.0)
        else:  # يلتف حول 360
            out *= np.maximum(band(hue, lo, 360.0 + 8, 8.0), band(hue, -8, hi, 8.0))
    if 'warm' in cond:
        out *= np.clip((r - b - cond['warm']) / 0.08 + 0.5, 0, 1)
    return out


def build(scene_id, preview_dir=None):
    spec_path = os.path.join(SPECS, f'{scene_id}.json')
    spec = json.load(open(spec_path, encoding='utf-8'))
    src = Image.open(os.path.join(ASSETS, scene_id, 'background.webp')).convert('RGB')
    scale = float(spec.get('scale', 0.5))
    w, h = max(8, round(src.width * scale)), max(8, round(src.height * scale))
    small = src.resize((w, h), Image.LANCZOS)
    rgb = np.asarray(small, dtype=np.float32) / 255.0
    hsv = np.asarray(small.convert('HSV'), dtype=np.float32) / 255.0
    out = np.zeros((h, w, 3), dtype=np.float32)
    for ci, ch in enumerate('rgb'):
        c = spec.get('channels', {}).get(ch)
        if not c:
            continue
        m = np.zeros((h, w), dtype=np.float32)
        for s in c.get('add', []):
            m = np.maximum(m, shape_mask(s, w, h))
        for s in c.get('sub', []):
            m *= 1.0 - shape_mask(s, w, h)
        if 'keep' in c:
            m *= color_cond(c['keep'], rgb, hsv)
        if 'drop' in c:
            m *= 1.0 - color_cond(c['drop'], rgb, hsv)
        # القيم بالبكسل مكتوبة لقناع عرضه 470 (نصف صورة 941)، فنحوّلها حسب عرض هذا القناع.
        k = w / 470.0
        grow = int(round(c.get('grow', 0) * k))
        if grow > 0:
            m = ndimage.grey_dilation(m, size=(grow * 2 + 1, grow * 2 + 1))
        feather = float(c.get('feather', 3)) * k
        if feather > 0:
            m = ndimage.gaussian_filter(m, feather)
        out[..., ci] = np.clip(m * float(c.get('gain', 1.0)), 0, 1)
    mask = Image.fromarray((out * 255).round().astype(np.uint8), 'RGB')
    dst = os.path.join(ASSETS, scene_id, 'mask.webp')
    mask.save(dst, 'WEBP', lossless=True, quality=100, method=6)
    if preview_dir:
        os.makedirs(preview_dir, exist_ok=True)
        base = np.asarray(small, dtype=np.float32) / 255.0 * 0.55
        tint = np.array([[1.0, 0.25, 0.25], [0.3, 1.0, 0.35], [0.35, 0.5, 1.0]], dtype=np.float32)
        over = base.copy()
        for ci in range(3):
            a = out[..., ci:ci + 1] * 0.6
            over = over * (1 - a) + tint[ci] * a
        side = np.concatenate([np.asarray(small, dtype=np.float32) / 255.0, over], axis=1)
        Image.fromarray((side * 255).astype(np.uint8)).save(os.path.join(preview_dir, f'{scene_id}.png'))
    return dst, mask.size


def main(argv):
    preview = None
    if '--preview' in argv:
        i = argv.index('--preview')
        preview = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    ids = argv or sorted(f[:-5] for f in os.listdir(SPECS) if f.endswith('.json'))
    for sid in ids:
        dst, size = build(sid, preview)
        print(f'{sid}: {size[0]}x{size[1]} -> {os.path.relpath(dst, ROOT)}')


if __name__ == '__main__':
    main(sys.argv[1:])
