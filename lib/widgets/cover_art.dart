import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repository.dart';

/// غلاف مرسوم بالكود (مشهد لكل نوع)، أو صورة من الإنترنت لو الكتاب له غلاف.
class CoverArt extends StatelessWidget {
  final String art;
  final String? url;
  final BorderRadius? radius;
  final BoxShape shape;

  const CoverArt({super.key, required this.art, this.url, this.radius, this.shape = BoxShape.rectangle});

  @override
  Widget build(BuildContext context) {
    Widget child = CustomPaint(painter: ScenePainter(art), child: const SizedBox.expand());
    final u = url;
    if (u != null && u.isNotEmpty) {
      ContentRepository? repo;
      try {
        repo = Provider.of<ContentRepository>(context, listen: false);
      } catch (_) {}
      final r = repo?.resolve(u) ?? (path: u, remote: u.startsWith('http'));
      Widget fade(BuildContext _, Widget img, int? frame, bool sync) =>
          sync ? img : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 500), child: img);
      final img = r.remote
          ? Image.network(r.path, fit: BoxFit.cover, frameBuilder: fade, errorBuilder: (_, __, ___) => const SizedBox.shrink())
          : Image.asset(r.path, fit: BoxFit.cover, frameBuilder: fade, errorBuilder: (_, __, ___) => const SizedBox.shrink());
      child = Stack(fit: StackFit.expand, children: [child, img]);
    }
    if (shape == BoxShape.circle) return ClipOval(child: child);
    return ClipRRect(borderRadius: radius ?? BorderRadius.zero, child: child);
  }
}

class ScenePainter extends CustomPainter {
  final String kind;
  ScenePainter(this.kind);

  static const _w = 240.0, _h = 340.0;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.max(size.width / _w, size.height / _h);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate((size.width - _w * s) / 2, (size.height - _h * s) / 2);
    canvas.scale(s);
    switch (kind) {
      case 'lantern':
        _lantern(canvas);
        break;
      case 'traveler':
        _traveler(canvas);
        break;
      case 'deepsea':
        _deepsea(canvas);
        break;
      case 'mind':
        _mind(canvas);
        break;
      case 'morning':
        _morning(canvas);
        break;
      default:
        _storm(canvas);
    }
    canvas.restore();
  }

  Paint _grad(List<Color> c, List<double> stops, {Alignment b = Alignment.topCenter, Alignment e = Alignment.bottomCenter}) =>
      Paint()..shader = LinearGradient(begin: b, end: e, colors: c, stops: stops).createShader(const Rect.fromLTWH(0, 0, _w, _h));

  Paint _fill(Color c, [double o = 1]) => Paint()..color = c.withAlpha((o * 255).round());
  Paint _stroke(Color c, double w, [double o = 1]) => Paint()
    ..color = c.withAlpha((o * 255).round())
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;

  void _glow(Canvas c, Offset o, double r, Color col, [double o1 = 0.75]) {
    c.drawCircle(
        o,
        r,
        Paint()
          ..shader = RadialGradient(colors: [col.withAlpha((o1 * 255).round()), col.withAlpha(0)]).createShader(Rect.fromCircle(center: o, radius: r)));
  }

  Path _wave(double y, double amp, {double step = 60}) {
    final p = Path()..moveTo(0, y);
    var x = 0.0;
    var up = true;
    while (x < _w) {
      p.quadraticBezierTo(x + step / 2, y + (up ? -amp : amp), x + step, y);
      x += step;
      up = !up;
    }
    p
      ..lineTo(_w, _h)
      ..lineTo(0, _h)
      ..close();
    return p;
  }

  void _stars(Canvas c, List<List<double>> pts) {
    for (final p in pts) {
      c.drawCircle(Offset(p[0], p[1]), p[2], _fill(Colors.white, 0.7));
    }
  }

  void _storm(Canvas c) {
    c.drawRect(const Rect.fromLTWH(0, 0, _w, _h), _grad(const [Color(0xFF0B1F2C), Color(0xFF24505E), Color(0xFFC98B4A)], const [0, 0.5, 0.72]));
    _glow(c, const Offset(164, 96), 70, const Color(0xFFFCE3B0));
    c.drawCircle(const Offset(164, 96), 20, _fill(const Color(0xFFFBE6BE)));
    _stars(c, [[40, 40, 1.2], [88, 62, 1], [210, 34, 1.3], [120, 24, 0.9], [20, 110, 0.8]]);
    c.drawPath(Path()..addPolygon(const [Offset(40, 176), Offset(150, 150), Offset(150, 206)], true), _fill(const Color(0xFFFFD98A), 0.16));
    c.drawRect(const Rect.fromLTWH(32, 180, 14, 56), _fill(const Color(0xFF0A1A22)));
    c.drawPath(Path()..addPolygon(const [Offset(30, 180), Offset(48, 180), Offset(39, 166)], true), _fill(const Color(0xFF0A1A22)));
    c.drawCircle(const Offset(39, 176), 4, _fill(const Color(0xFFFFD98A)));
    c.drawPath(_wave(232, 12), _fill(const Color(0xFF163F4C)));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(150, 240, 28, 2), const Radius.circular(1)), _fill(const Color(0xFFFBE6BE), 0.6));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(156, 250, 18, 2), const Radius.circular(1)), _fill(const Color(0xFFFBE6BE), 0.45));
    final boat = Path()
      ..moveTo(98, 236)
      ..lineTo(132, 236)
      ..lineTo(125, 245)
      ..lineTo(104, 245)
      ..close();
    c.drawPath(boat, _fill(const Color(0xFF0A1A22)));
    c.drawLine(const Offset(114, 236), const Offset(114, 206), _stroke(const Color(0xFF0A1A22), 1.5));
    c.drawPath(Path()..addPolygon(const [Offset(115, 208), Offset(115, 234), Offset(132, 234)], true), _fill(const Color(0xFF0A1A22)));
    c.drawPath(_wave(256, 14), _fill(const Color(0xFF0F2F3A)));
    c.drawPath(_wave(286, 14), _fill(const Color(0xFF0A212A)));
  }

  void _lantern(Canvas c) {
    c.drawRect(const Rect.fromLTWH(0, 0, _w, _h), _grad(const [Color(0xFF140C24), Color(0xFF3B2A4A), Color(0xFF6A3F5A)], const [0, 0.6, 1]));
    for (final x in [30.0, 130.0]) {
      final p = Path()
        ..moveTo(x, _h)
        ..lineTo(x, 150)
        ..quadraticBezierTo(x, 104, x + 40, 88)
        ..quadraticBezierTo(x + 80, 104, x + 80, 150)
        ..lineTo(x + 80, _h);
      c.drawPath(p, _stroke(const Color(0xFFE8B86A), 1, 0.2));
    }
    _glow(c, const Offset(120, 160), 100, const Color(0xFFFFD58A), 0.8);
    c.drawLine(const Offset(120, 0), const Offset(120, 118), _stroke(const Color(0xFFE8B86A), 1.2));
    c.drawPath(Path()..addPolygon(const [Offset(104, 126), Offset(136, 126), Offset(120, 112)], true), _fill(const Color(0xFFC9934A)));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(104, 126, 32, 52), const Radius.circular(6)), _fill(const Color(0xFFF2C878)));
    for (final x in [112.0, 120.0, 128.0]) {
      c.drawLine(Offset(x, 126), Offset(x, 178), _stroke(const Color(0xFFB5803C), 1, 0.6));
    }
    c.drawOval(Rect.fromCenter(center: const Offset(120, 152), width: 12, height: 20), _fill(const Color(0xFFFFF6D8)));
    c.drawPath(Path()..addPolygon(const [Offset(106, 178), Offset(134, 178), Offset(120, 190)], true), _fill(const Color(0xFFC9934A)));
    _stars(c, [[40, 36, 1.2], [200, 54, 1.4], [170, 22, 1], [70, 70, 0.8]]);
    final ground = _fill(const Color(0xFF140C22));
    c.drawRect(const Rect.fromLTWH(0, 300, _w, 40), ground);
    c.drawArc(const Rect.fromLTWH(30, 266, 68, 68), math.pi, math.pi, true, ground);
    c.drawRect(const Rect.fromLTWH(104, 246, 10, 54), ground);
    c.drawPath(Path()..addPolygon(const [Offset(102, 246), Offset(116, 246), Offset(109, 232)], true), ground);
    c.drawArc(const Rect.fromLTWH(140, 256, 88, 88), math.pi, math.pi, true, ground);
    c.drawCircle(const Offset(184, 252), 2, _fill(const Color(0xFFE8B86A)));
  }

  void _traveler(Canvas c) {
    c.drawRect(const Rect.fromLTWH(0, 0, _w, _h), _grad(const [Color(0xFF3E2A4F), Color(0xFFC8604A), Color(0xFFF2B66D)], const [0, 0.45, 0.7]));
    c.drawCircle(const Offset(120, 214), 38, _fill(const Color(0xFFFFE3A3)));
    final bird = _stroke(const Color(0xFF3E2A4F), 1.5);
    for (final b in [const Offset(56, 92), const Offset(150, 70)]) {
      final p = Path()
        ..moveTo(b.dx, b.dy)
        ..quadraticBezierTo(b.dx + 6, b.dy - 6, b.dx + 12, b.dy)
        ..quadraticBezierTo(b.dx + 18, b.dy - 6, b.dx + 24, b.dy);
      c.drawPath(p, bird);
    }
    final d1 = Path()
      ..moveTo(0, 232)
      ..quadraticBezierTo(70, 204, 140, 228)
      ..quadraticBezierTo(190, 240, 240, 220)
      ..lineTo(240, 340)
      ..lineTo(0, 340)
      ..close();
    c.drawPath(d1, _fill(const Color(0xFF9A5233)));
    final fig = _fill(const Color(0xFF2A140E));
    c.drawCircle(const Offset(160, 204), 3.5, fig);
    c.drawPath(Path()..addPolygon(const [Offset(157, 208), Offset(163, 208), Offset(165, 224), Offset(155, 224)], true), fig);
    c.drawLine(const Offset(166, 206), const Offset(170, 226), _stroke(const Color(0xFF2A140E), 1.2));
    final d2 = Path()
      ..moveTo(0, 264)
      ..quadraticBezierTo(80, 238, 160, 264)
      ..quadraticBezierTo(200, 276, 240, 258)
      ..lineTo(240, 340)
      ..lineTo(0, 340)
      ..close();
    c.drawPath(d2, _fill(const Color(0xFF6A3522)));
    for (var i = 0; i < 3; i++) {
      c.drawOval(Rect.fromCenter(center: Offset(150 - i * 11.0, 236 + i * 8.0), width: 4, height: 2), _fill(const Color(0xFF2A140E), 0.5 - i * 0.1));
    }
    final d3 = Path()
      ..moveTo(0, 302)
      ..quadraticBezierTo(100, 276, 240, 302)
      ..lineTo(240, 340)
      ..lineTo(0, 340)
      ..close();
    c.drawPath(d3, _fill(const Color(0xFF4A2418)));
  }

  void _deepsea(Canvas c) {
    c.drawRect(const Rect.fromLTWH(0, 0, _w, _h), _grad(const [Color(0xFF1A7A94), Color(0xFF0A3550), Color(0xFF05121F)], const [0, 0.45, 1]));
    c.drawPath(Path()..addPolygon(const [Offset(60, 0), Offset(90, 0), Offset(150, 340), Offset(100, 340)], true), _fill(const Color(0xFFBFF0F5), 0.07));
    c.drawPath(Path()..addPolygon(const [Offset(140, 0), Offset(160, 0), Offset(220, 300), Offset(180, 300)], true), _fill(const Color(0xFFBFF0F5), 0.06));
    void fish(Offset o, double s, double a) {
      final p = Path()
        ..moveTo(o.dx, o.dy)
        ..quadraticBezierTo(o.dx + 14 * s, o.dy - 12 * s, o.dx + 28 * s, o.dy)
        ..quadraticBezierTo(o.dx + 14 * s, o.dy + 12 * s, o.dx, o.dy)
        ..close()
        ..moveTo(o.dx + 28 * s, o.dy)
        ..lineTo(o.dx + 38 * s, o.dy - 8 * s)
        ..lineTo(o.dx + 38 * s, o.dy + 8 * s)
        ..close();
      c.drawPath(p, _fill(const Color(0xFF7FC8C8), a));
    }

    fish(const Offset(70, 150), 1, 0.8);
    fish(const Offset(150, 186), 0.72, 0.6);
    fish(const Offset(126, 108), 0.6, 0.5);
    _glow(c, const Offset(182, 76), 40, const Color(0xFFF2B8D8), 0.35);
    c.drawArc(const Rect.fromLTWH(164, 58, 36, 28), math.pi, math.pi, true, _fill(const Color(0xFFF2B8D8), 0.85));
    for (final x in [170.0, 182.0, 194.0]) {
      final p = Path()
        ..moveTo(x, 72)
        ..quadraticBezierTo(x + 3, 86, x - 2, 100);
      c.drawPath(p, _stroke(const Color(0xFFF2B8D8), 1.2, 0.7));
    }
    for (final b in [[50.0, 90.0, 4.0], [58.0, 70.0, 2.5], [46.0, 54.0, 1.8]]) {
      c.drawCircle(Offset(b[0], b[1]), b[2], _stroke(const Color(0xFFBFF0F5), 1, 0.55));
    }
    c.drawPath(_wave(290, 12, step: 80), _fill(const Color(0xFF03101A)));
    final coral1 = _stroke(const Color(0xFFE0A84F), 2, 0.8);
    c.drawLine(const Offset(40, 292), const Offset(40, 264), coral1);
    c.drawLine(const Offset(40, 274), const Offset(32, 266), coral1);
    c.drawLine(const Offset(40, 280), const Offset(48, 270), coral1);
    final coral2 = _stroke(const Color(0xFFF2B8D8), 2, 0.7);
    c.drawLine(const Offset(190, 294), const Offset(190, 256), coral2);
    c.drawLine(const Offset(190, 268), const Offset(182, 258), coral2);
    c.drawLine(const Offset(190, 276), const Offset(200, 264), coral2);
  }

  void _mind(Canvas c) {
    c.drawRect(const Rect.fromLTWH(0, 0, _w, _h),
        _grad(const [Color(0xFF1B3324), Color(0xFF0D1A12)], const [0, 1], b: Alignment.topLeft, e: Alignment.bottomRight));
    _glow(c, const Offset(120, 160), 90, const Color(0xFFE4F28F), 0.55);
    c.drawCircle(const Offset(120, 160), 60, _stroke(const Color(0xFFC9D97A), 0.8, 0.3));
    c.drawCircle(const Offset(120, 160), 96, _stroke(const Color(0xFFC9D97A), 0.8, 0.18));
    const nodes = [
      Offset(70, 110), Offset(40, 150), Offset(170, 100), Offset(200, 140), Offset(80, 220),
      Offset(50, 250), Offset(176, 214), Offset(196, 262), Offset(120, 70), Offset(130, 260),
    ];
    const center = Offset(120, 160);
    final line = _stroke(const Color(0xFFC9D97A), 1, 0.45);
    const edges = [[0, 1], [2, 3], [4, 5], [6, 7], [0, 8], [8, 2], [4, 9], [9, 6]];
    for (final n in [0, 2, 4, 6]) {
      c.drawLine(center, nodes[n], line);
    }
    for (final e in edges) {
      c.drawLine(nodes[e[0]], nodes[e[1]], line);
    }
    c.drawCircle(center, 9, _fill(const Color(0xFFE4F28F)));
    for (final n in nodes) {
      c.drawCircle(n, 3.5, _fill(const Color(0xFFC9D97A)));
    }
  }

  void _morning(Canvas c) {
    c.drawRect(const Rect.fromLTWH(0, 0, _w, _h), _grad(const [Color(0xFFBFE3EA), Color(0xFFFDE2C4), Color(0xFFF8C9A4)], const [0, 0.6, 1]));
    _glow(c, const Offset(150, 168), 70, const Color(0xFFFFF4DA), 0.95);
    c.drawCircle(const Offset(150, 168), 28, _fill(const Color(0xFFFFF1CF)));
    final bird = _stroke(const Color(0xFF4E8A8A), 1.5);
    for (final b in [const Offset(44, 96), const Offset(78, 80)]) {
      final p = Path()
        ..moveTo(b.dx, b.dy)
        ..quadraticBezierTo(b.dx + 5, b.dy - 5, b.dx + 10, b.dy)
        ..quadraticBezierTo(b.dx + 15, b.dy - 5, b.dx + 20, b.dy);
      c.drawPath(p, bird);
    }
    c.drawPath(
        Path()
          ..addPolygon(const [Offset(0, 228), Offset(60, 168), Offset(110, 212), Offset(170, 146), Offset(240, 218), Offset(240, 340), Offset(0, 340)], true),
        _fill(const Color(0xFFA9D2CC)));
    c.drawPath(
        Path()
          ..addPolygon(const [Offset(0, 262), Offset(80, 204), Offset(140, 250), Offset(200, 208), Offset(240, 240), Offset(240, 340), Offset(0, 340)], true),
        _fill(const Color(0xFF76AFAB)));
    final hill = Path()
      ..moveTo(0, 300)
      ..quadraticBezierTo(120, 258, 240, 300)
      ..lineTo(240, 340)
      ..lineTo(0, 340)
      ..close();
    c.drawPath(hill, _fill(const Color(0xFF4E8A8A)));
    final road = Path()
      ..moveTo(120, 340)
      ..quadraticBezierTo(100, 310, 130, 296)
      ..quadraticBezierTo(160, 282, 140, 262);
    final dash = _stroke(const Color(0xFFFFF4DA), 3);
    for (final m in road.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        c.drawPath(m.extractPath(d, math.min(d + 6, m.length)), dash);
        d += 12;
      }
    }
  }

  @override
  bool shouldRepaint(covariant ScenePainter old) => old.kind != kind;
}
