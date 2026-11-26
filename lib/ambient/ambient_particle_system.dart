import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'ambient_scene.dart';

/// نظام جسيمات إجرائي: كل موضع محسوب من (رقم الجسيم، الزمن) فقط، بدون حالة.
/// يُرسم كل باعث بنداء واحد drawRawAtlas على أطلس صغير من الأشكال الناعمة،
/// والمصفوفات محجوزة مسبقًا فلا توجد تخصيصات ذاكرة في كل إطار.
class AmbientParticleSystem {
  AmbientParticleSystem(this.emitters) {
    for (final e in emitters) {
      _buffers.add(_Buffers(e.count));
    }
  }

  final List<ParticleEmitter> emitters;
  final List<_Buffers> _buffers = [];

  static ui.Image? _atlas;
  static const double _cell = 64;

  // خلايا الأطلس.
  static const _dot = 0, _streak = 1, _drop = 2, _petal = 3, _ring = 4;

  static final Paint _normal = Paint()..filterQuality = FilterQuality.low;
  static final Paint _additive = Paint()
    ..filterQuality = FilterQuality.low
    ..blendMode = BlendMode.plus;

  /// يبني الأطلس مرة واحدة لكل التطبيق.
  static ui.Image atlas() => _atlas ??= _buildAtlas();

  static ui.Image _buildAtlas() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    const h = _cell / 2;
    // 0: نقطة ناعمة متوهجة
    c.drawCircle(const Offset(h, h), h,
        Paint()..shader = ui.Gradient.radial(const Offset(h, h), h, const [Color(0xFFFFFFFF), Color(0x66FFFFFF), Color(0x00FFFFFF)], const [0, 0.35, 1]));
    // 1: خط مطر
    c.drawRect(
        const Rect.fromLTWH(_cell + h - 1.5, 2, 3, _cell - 4),
        Paint()
          ..shader = ui.Gradient.linear(const Offset(0, 2), const Offset(0, _cell - 2), const [Color(0x00FFFFFF), Color(0xFFFFFFFF)]));
    // 2: قطرة على الزجاج: حافة مضيئة وقلب شفاف ولمعة صغيرة
    const dc = Offset(_cell * 2 + h, h);
    c.drawCircle(dc, h - 6, Paint()..shader = ui.Gradient.radial(dc, h - 6, const [Color(0x33FFFFFF), Color(0x55FFFFFF), Color(0xCCFFFFFF)], const [0, 0.75, 1]));
    c.drawCircle(dc + const Offset(-7, -8), 5, Paint()..color = const Color(0xEEFFFFFF));
    // 3: بتلة/ورقة
    c.save();
    c.translate(_cell * 3 + h, h);
    c.drawOval(const Rect.fromLTWH(-24, -11, 48, 22), Paint()..color = const Color(0xFFFFFFFF));
    c.restore();
    // 4: فقاعة (حلقة)
    c.drawCircle(const Offset(_cell * 4 + h, h), h - 8,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xCCFFFFFF));
    final pic = rec.endRecording();
    final img = pic.toImageSync((_cell * 5).toInt(), _cell.toInt());
    pic.dispose();
    return img;
  }

  static double _r(int i, int k) {
    final x = math.sin(i * 12.9898 + k * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  /// يرسم كل الجسيمات. [density] بين 0 و1 حسب وضع الجودة.
  void paint(Canvas canvas, Size view, AmbientScene scene, CoverTransform tf, double t, double density, double dim) {
    if (density <= 0 || dim <= 0.02) return;
    final img = atlas();
    for (var e = 0; e < emitters.length; e++) {
      final em = emitters[e];
      final n = (em.count * density).ceil().clamp(0, em.count);
      if (n == 0) continue;
      final b = _buffers[e];
      final tl = tf.map(em.area.topLeft, scene.size), br = tf.map(em.area.bottomRight, scene.size);
      final area = Rect.fromPoints(tl, br);
      final unit = tf.scale * scene.size.width / 941.0; // حجم موحد بالنسبة لعرض الصورة الأصلي
      var used = 0;
      for (var i = 0; i < n; i++) {
        if (_particle(em, i, t, area, unit, b, used, dim)) used++;
      }
      if (used == 0) continue;
      final additive = em.kind == ParticleKind.embers || em.kind == ParticleKind.fireflies || em.kind == ParticleKind.motes;
      canvas.drawRawAtlas(img, Float32List.sublistView(b.xform, 0, used * 4), Float32List.sublistView(b.rects, 0, used * 4),
          Int32List.sublistView(b.colors, 0, used), BlendMode.modulate, null, additive ? _additive : _normal);
    }
  }

  /// يحسب جسيمًا واحدًا ويكتبه في المصفوفات. يرجع false لو غير مرئي الآن.
  bool _particle(ParticleEmitter em, int i, double t, Rect a, double unit, _Buffers b, int slot, double dim) {
    final sp = em.speed;
    double x, y, scale, rot = 0, alpha;
    int cell;
    switch (em.kind) {
      case ParticleKind.rain:
        final v = 0.9 + _r(i, 1) * 0.5;
        final p = (t * sp * 0.9 * v + _r(i, 2)) % 1.0;
        y = a.top + p * a.height;
        x = a.left + _r(i, 3) * a.width + (p - 0.5) * a.height * 0.06;
        scale = (0.35 + _r(i, 4) * 0.35) * em.size * unit;
        rot = -0.06;
        alpha = 0.16 + _r(i, 5) * 0.22;
        cell = _streak;
      case ParticleKind.glassDrops:
        // قطرة ثابتة تكبر ببطء، ثم تنزلق على الزجاج وتختفي، ثم تولد من جديد.
        final period = (7 + _r(i, 1) * 12) / sp;
        final p = (t / period + _r(i, 2)) % 1.0;
        final x0 = a.left + _r(i, 3) * a.width, y0 = a.top + _r(i, 4) * a.height * 0.8;
        final base = (0.06 + _r(i, 5) * 0.12) * em.size * unit;
        if (p < 0.72) {
          x = x0;
          y = y0;
          scale = base * (0.7 + p * 0.4);
          alpha = math.min(1.0, p * 8) * 0.85;
        } else {
          final q = (p - 0.72) / 0.28;
          x = x0 + math.sin(q * 5 + i) * 2;
          y = y0 + q * q * a.height * (0.25 + _r(i, 6) * 0.3);
          scale = base * 1.0;
          alpha = (1 - q) * 0.85;
        }
        cell = _drop;
      case ParticleKind.snow:
        final v = 0.5 + _r(i, 1) * 0.6;
        final p = (t * sp * 0.05 * v + _r(i, 2)) % 1.0;
        y = a.top + p * a.height;
        x = a.left + _r(i, 3) * a.width + math.sin(t * 0.5 * v + i) * 12 * unit;
        scale = (0.05 + _r(i, 4) * 0.09) * em.size * unit;
        alpha = 0.55 + _r(i, 5) * 0.4;
        cell = _dot;
      case ParticleKind.embers:
        final life = (t * sp * (0.12 + _r(i, 1) * 0.1) + _r(i, 2)) % 1.0;
        x = a.left + (0.3 + _r(i, 3) * 0.4) * a.width + math.sin(t * 1.3 + i) * a.width * 0.12 * life;
        y = a.bottom - life * a.height;
        scale = (0.05 + _r(i, 4) * 0.06) * em.size * unit * (1 - life * 0.5);
        alpha = math.sin(math.pi * life) * (1 - life) * 1.4;
        cell = _dot;
      case ParticleKind.steam:
        final life = (t * sp * 0.09 + _r(i, 1)) % 1.0;
        x = a.center.dx + (_r(i, 2) - 0.5) * a.width * 0.3 + math.sin(t * 0.6 + i * 1.7 + life * 4) * a.width * 0.25 * life;
        y = a.bottom - life * a.height;
        scale = (0.35 + life * 1.4) * em.size * unit;
        alpha = math.sin(math.pi * life) * 0.10;
        cell = _dot;
      case ParticleKind.fireflies:
        x = a.left + _r(i, 1) * a.width + math.sin(t * sp * (0.18 + _r(i, 2) * 0.25) + i) * a.width * 0.08;
        y = a.top + _r(i, 3) * a.height + math.cos(t * sp * (0.14 + _r(i, 4) * 0.2) + i) * a.height * 0.06;
        scale = (0.16 + _r(i, 5) * 0.08) * em.size * unit;
        alpha = math.max(0.0, math.sin(t * sp * (0.35 + _r(i, 6) * 0.5) + i * 2.1)) * 0.75;
        cell = _dot;
      case ParticleKind.petals:
        final v = 0.6 + _r(i, 1) * 0.6;
        final p = (t * sp * 0.035 * v + _r(i, 2)) % 1.0;
        y = a.top + p * a.height;
        x = a.left + _r(i, 3) * a.width + math.sin(t * 0.7 * v + i) * a.width * 0.06 - p * a.width * 0.15;
        scale = (0.12 + _r(i, 4) * 0.1) * em.size * unit;
        rot = t * (0.5 + _r(i, 5)) + i;
        alpha = math.min(1.0, math.min(p, 1 - p) * 10) * 0.85;
        cell = _petal;
      case ParticleKind.motes:
        x = a.left + _r(i, 1) * a.width + math.sin(t * sp * 0.12 + i) * a.width * 0.05;
        y = a.top + ((_r(i, 2) - t * sp * 0.006 * (0.5 + _r(i, 3))) % 1.0) * a.height;
        scale = (0.05 + _r(i, 4) * 0.06) * em.size * unit;
        alpha = (0.25 + 0.35 * math.sin(t * 0.8 + i * 1.3).abs()) * 0.6;
        cell = _dot;
      case ParticleKind.spray:
        final life = (t * sp * 0.22 + _r(i, 1)) % 1.0;
        x = a.left + _r(i, 2) * a.width + (_r(i, 3) - 0.5) * a.width * 0.4 * life;
        y = a.bottom - life * a.height * (0.5 + _r(i, 4) * 0.5);
        scale = (0.3 + life * 0.8) * em.size * unit;
        alpha = math.sin(math.pi * life) * 0.12;
        cell = _dot;
      case ParticleKind.bubbles:
        final life = (t * sp * (0.05 + _r(i, 1) * 0.05) + _r(i, 2)) % 1.0;
        x = a.left + _r(i, 3) * a.width + math.sin(t * 1.1 + i) * 6 * unit;
        y = a.bottom - life * a.height;
        scale = (0.05 + _r(i, 4) * 0.07) * em.size * unit;
        alpha = math.min(1.0, math.min(life, 1 - life) * 8) * 0.55;
        cell = _ring;
    }
    alpha = (alpha * dim).clamp(0.0, 1.0);
    if (alpha < 0.01 || scale <= 0) return false;
    final c = em.color;
    final argb = ((alpha * (c.a) * 255).round() << 24) | ((c.r * 255).round() << 16) | ((c.g * 255).round() << 8) | (c.b * 255).round();
    final s = scale, cs = math.cos(rot) * s, sn = math.sin(rot) * s;
    const h = _cell / 2;
    final o = slot * 4;
    b.xform[o] = cs;
    b.xform[o + 1] = sn;
    b.xform[o + 2] = x - cs * h + sn * h;
    b.xform[o + 3] = y - sn * h - cs * h;
    b.rects[o] = cell * _cell;
    b.rects[o + 1] = 0;
    b.rects[o + 2] = cell * _cell + _cell;
    b.rects[o + 3] = _cell;
    b.colors[slot] = argb.toSigned(32);
    return true;
  }
}

class _Buffers {
  final Float32List xform, rects;
  final Int32List colors;
  _Buffers(int n)
      : xform = Float32List(n * 4),
        rects = Float32List(n * 4),
        colors = Int32List(n);
}
