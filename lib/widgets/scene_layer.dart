import 'dart:math' as math;

import 'package:flutter/material.dart';

/// طبقة مشهد متحركة هادئة فوق الغلاف في المشغّل: مطر، نجوم، بحر، يراعات، صحراء، ثلج، جمر.
/// كل الحركة محسوبة من الزمن فقط (بدون حالة)، فتكون خفيفة على البطارية.
class SceneLayer extends StatefulWidget {
  final String scene;
  final Color tint;
  const SceneLayer({super.key, required this.scene, this.tint = Colors.white});

  /// مشهد افتراضي من رسم الغلاف لو لم يُحدَّد في اللوحة.
  static String resolve(String scene, String art) {
    if (scene.isNotEmpty) return scene;
    return switch (art) {
      'storm' => 'rain',
      'deepsea' => 'sea',
      'lantern' => 'embers',
      'traveler' => 'desert',
      'morning' => 'forest',
      _ => 'night',
    };
  }

  @override
  State<SceneLayer> createState() => _SceneLayerState();
}

class _SceneLayerState extends State<SceneLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _ScenePainter(widget.scene, widget.tint, _c),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  final String scene;
  final Color tint;
  final Animation<double> anim;
  _ScenePainter(this.scene, this.tint, this.anim) : super(repaint: anim);

  // أرقام شبه عشوائية ثابتة لكل جسيم
  static double _r(int i, int k) {
    final x = math.sin(i * 12.9898 + k * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size s) {
    final t = anim.value * 60; // ثوانٍ
    switch (scene) {
      case 'rain':
        _rain(canvas, s, t);
      case 'sea':
        _sea(canvas, s, t);
      case 'forest':
        _fireflies(canvas, s, t);
      case 'desert':
        _desert(canvas, s, t);
      case 'snow':
        _snow(canvas, s, t);
      case 'embers':
        _embers(canvas, s, t);
      default:
        _night(canvas, s, t);
    }
  }

  void _night(Canvas c, Size s, double t) {
    final p = Paint();
    for (var i = 0; i < 70; i++) {
      final x = _r(i, 1) * s.width, y = _r(i, 2) * s.height * 0.75;
      final tw = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * (0.6 + _r(i, 3) * 1.4) + i));
      p.color = Colors.white.withValues(alpha: 0.55 * tw);
      c.drawCircle(Offset(x, y), 0.6 + _r(i, 4) * 1.3, p);
    }
    // شهاب كل ١٢ ثانية
    final k = (t / 12).floor(), f = (t % 12) / 1.2;
    if (f < 1) {
      final sx = _r(k, 5) * s.width * 0.8 + s.width * 0.2, sy = _r(k, 6) * s.height * 0.3;
      final a = Offset(sx - f * 160, sy + f * 70);
      c.drawLine(a, a + const Offset(60, -26), Paint()
        ..strokeWidth = 1.4
        ..shader = LinearGradient(colors: [Colors.white.withValues(alpha: 0.8 * (1 - f)), Colors.transparent])
            .createShader(Rect.fromPoints(a, a + const Offset(60, -26))));
    }
  }

  void _rain(Canvas c, Size s, double t) {
    final p = Paint()
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 90; i++) {
      final speed = 0.55 + _r(i, 1) * 0.5;
      final y = ((t * speed + _r(i, 2)) % 1) * (s.height + 60) - 30;
      final x = _r(i, 3) * (s.width + 80) - 40 + y * 0.12;
      p.color = Colors.white.withValues(alpha: 0.12 + _r(i, 4) * 0.18);
      final len = 14 + _r(i, 5) * 16;
      c.drawLine(Offset(x, y), Offset(x - len * 0.12, y - len), p);
    }
  }

  void _sea(Canvas c, Size s, double t) {
    for (var layer = 0; layer < 4; layer++) {
      final base = s.height * (0.7 + layer * 0.08);
      final path = Path()..moveTo(0, s.height);
      for (double x = 0; x <= s.width + 8; x += 8) {
        final y = base + math.sin(x / (70 + layer * 25) + t * (0.5 + layer * 0.15) + layer) * (6 + layer * 2);
        path.lineTo(x, y);
      }
      path
        ..lineTo(s.width, s.height)
        ..close();
      c.drawPath(path, Paint()..color = Color.lerp(tint, const Color(0xFF0B2A3C), 0.6)!.withValues(alpha: 0.10 + layer * 0.06));
    }
    final p = Paint();
    for (var i = 0; i < 26; i++) {
      final x = _r(i, 1) * s.width, y = s.height * (0.7 + _r(i, 2) * 0.28);
      p.color = Colors.white.withValues(alpha: 0.25 * (0.5 + 0.5 * math.sin(t * 1.3 + i)));
      c.drawCircle(Offset(x + math.sin(t * 0.4 + i) * 6, y), 1.2, p);
    }
  }

  void _fireflies(Canvas c, Size s, double t) {
    const glow = Color(0xFFE9F29B);
    for (var i = 0; i < 28; i++) {
      final x = _r(i, 1) * s.width + math.sin(t * (0.2 + _r(i, 2) * 0.3) + i) * 30;
      final y = s.height * (0.35 + _r(i, 3) * 0.6) + math.cos(t * (0.15 + _r(i, 4) * 0.25) + i) * 24;
      final a = math.max(0.0, math.sin(t * (0.5 + _r(i, 5)) + i * 2));
      c.drawCircle(Offset(x, y), 7, Paint()
        ..color = glow.withValues(alpha: 0.18 * a)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      c.drawCircle(Offset(x, y), 1.6, Paint()..color = glow.withValues(alpha: 0.9 * a));
    }
  }

  void _desert(Canvas c, Size s, double t) {
    for (var layer = 0; layer < 3; layer++) {
      final base = s.height * (0.76 + layer * 0.08);
      final path = Path()..moveTo(0, s.height);
      for (double x = 0; x <= s.width + 10; x += 10) {
        path.lineTo(x, base + math.sin(x / (160 - layer * 30) + layer * 2) * (18 - layer * 4));
      }
      path
        ..lineTo(s.width, s.height)
        ..close();
      c.drawPath(path, Paint()..color = const Color(0xFFD9A066).withValues(alpha: 0.10 + layer * 0.07));
    }
    final p = Paint();
    for (var i = 0; i < 60; i++) {
      final x = ((t * (0.03 + _r(i, 1) * 0.05) + _r(i, 2)) % 1) * (s.width + 40) - 20;
      final y = s.height * (0.6 + _r(i, 3) * 0.38) + math.sin(t + i) * 4;
      p.color = const Color(0xFFF3D9A4).withValues(alpha: 0.18 + _r(i, 4) * 0.2);
      c.drawCircle(Offset(s.width - x, y), 0.9, p);
    }
  }

  void _snow(Canvas c, Size s, double t) {
    final p = Paint();
    for (var i = 0; i < 80; i++) {
      final speed = 0.04 + _r(i, 1) * 0.06;
      final y = ((t * speed + _r(i, 2)) % 1) * (s.height + 20) - 10;
      final x = _r(i, 3) * s.width + math.sin(t * 0.6 + i) * 14;
      p.color = Colors.white.withValues(alpha: 0.35 + _r(i, 4) * 0.4);
      c.drawCircle(Offset(x, y), 1 + _r(i, 5) * 2, p);
    }
  }

  void _embers(Canvas c, Size s, double t) {
    for (var i = 0; i < 40; i++) {
      final life = (t * (0.08 + _r(i, 1) * 0.08) + _r(i, 2)) % 1;
      final x = s.width * (0.2 + _r(i, 3) * 0.6) + math.sin(t * 0.8 + i) * 18 * life;
      final y = s.height * (1.02 - life * 0.75);
      final a = (1 - life) * 0.8;
      c.drawCircle(Offset(x, y), 4, Paint()
        ..color = const Color(0xFFFF9D4D).withValues(alpha: 0.2 * a)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      c.drawCircle(Offset(x, y), 1.3, Paint()..color = const Color(0xFFFFC27A).withValues(alpha: a));
    }
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) => old.scene != scene || old.tint != tint;
}

/// تكبير بطيء جدًا للغلاف (حركة «كين برنز») حتى تبدو الشاشة حيّة.
class SlowZoom extends StatefulWidget {
  final Widget child;
  const SlowZoom({super.key, required this.child});

  @override
  State<SlowZoom> createState() => _SlowZoomState();
}

class _SlowZoomState extends State<SlowZoom> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 40))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final v = Curves.easeInOut.transform(_c.value);
        return Transform.scale(scale: 1.08 + v * 0.1, alignment: Alignment(-0.3 + v * 0.6, -0.2), child: child);
      },
      child: widget.child,
    );
  }
}
