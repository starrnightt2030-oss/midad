import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme.dart';

/// طبقة زجاجية مُضبّبة.
class Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final double opacity;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final Color tint;

  const Glass({super.key, required this.child, this.radius = 24, this.opacity = 0.10, this.blur = 22, this.padding, this.tint = Colors.white});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint.op(opacity),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.op(0.18)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// زر دائري زجاجي بأيقونة.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final double size;
  final Color? color;

  const GlassIconButton({super.key, required this.icon, required this.tooltip, this.onTap, this.size = 44, this.color});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Glass(
            radius: size / 2,
            opacity: 0.1,
            child: SizedBox(width: size, height: size, child: Icon(icon, size: size * 0.45, color: color ?? Colors.white)),
          ),
        ),
      ),
    );
  }
}

/// بقعة لون ضبابية كبيرة تتغير بنعومة (خلفية محيطية).
class AmbientGlow extends StatelessWidget {
  final Color color;
  final Alignment alignment;
  final double size;
  final double opacity;

  const AmbientGlow({super.key, required this.color, this.alignment = Alignment.center, this.size = 420, this.opacity = 0.35});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90, tileMode: TileMode.decal),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOut,
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.op(opacity)),
        ),
      ),
    );
  }
}

/// سماء نجوم تلمع + شهاب يعبر كل فترة.
class Starfield extends StatefulWidget {
  final int count;
  const Starfield({super.key, this.count = 40});

  @override
  State<Starfield> createState() => _StarfieldState();
}

class _StarfieldState extends State<Starfield> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat();
  late final List<List<double>> _stars;

  @override
  void initState() {
    super.initState();
    final r = math.Random(7);
    _stars = List.generate(widget.count, (_) => [r.nextDouble(), r.nextDouble(), 0.5 + r.nextDouble() * 1.2, r.nextDouble() * math.pi * 2]);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(painter: _StarPainter(_stars, _c.value), size: Size.infinite),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  final List<List<double>> stars;
  final double t;
  _StarPainter(this.stars, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white;
    for (final s in stars) {
      final a = 0.15 + 0.75 * (0.5 + 0.5 * math.sin(t * math.pi * 6 + s[3]));
      p.color = Colors.white.op(a);
      canvas.drawCircle(Offset(s[0] * size.width, s[1] * size.height), s[2], p);
    }
    // شهاب
    if (t < 0.18) {
      final k = t / 0.18;
      final start = Offset(size.width * 0.9, size.height * 0.08);
      final head = start + Offset(-260 * k, 150 * k);
      final tail = head + const Offset(60, -35);
      final o = (k < 0.2 ? k / 0.2 : 1 - (k - 0.2) / 0.8).clamp(0.0, 1.0);
      canvas.drawLine(
          head,
          tail,
          Paint()
            ..shader = LinearGradient(colors: [Colors.white.op(o), Colors.white.op(0)]).createShader(Rect.fromPoints(head, tail))
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) => old.t != t;
}

/// حلقة التقدم حول الغلاف الدائري.
class RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  RingPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 8;
    canvas.drawCircle(c, r, Paint()
      ..color = Colors.white.op(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    // RTL: التقدم عكس عقارب الساعة يبدأ من أعلى
    final sweep = -2 * math.pi * progress;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, sweep, false, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5);
    final a = -math.pi / 2 + sweep;
    final k = c + Offset(math.cos(a) * r, math.sin(a) * r);
    canvas.drawCircle(k, 14, Paint()..color = color.op(0.25));
    canvas.drawCircle(k, 8, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant RingPainter old) => old.progress != progress || old.color != color;
}

/// أعمدة صوت صغيرة متحركة تعني "يتحدث الآن".
class TalkingBars extends StatefulWidget {
  final Color color;
  final bool active;
  const TalkingBars({super.key, required this.color, required this.active});

  @override
  State<TalkingBars> createState() => _TalkingBarsState();
}

class _TalkingBarsState extends State<TalkingBars> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(4, (i) {
          final v = widget.active ? (0.35 + 0.65 * (0.5 + 0.5 * math.sin(_c.value * math.pi * 2 + i * 1.3))) : 0.3;
          return Container(
            width: 3,
            height: 14 * v,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(2)),
          );
        }),
      ),
    );
  }
}

String fmtDuration(Duration d) {
  const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  String ar(String s) => s.split('').map((c) => int.tryParse(c) == null ? c : digits[int.parse(c)]).join();
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return ar('${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}');
}

String arNum(num n) {
  const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return '$n'.split('').map((c) => int.tryParse(c) == null ? c : digits[int.parse(c)]).join();
}

/// انتقال صفحات سينمائي: تلاشي + تكبير خفيف.
Route<T> fadeRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 550),
      reverseTransitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, a, __, child) {
        final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: c,
          child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(c), child: child),
        );
      },
    );

/// انتقال من الأسفل (للمشغّل).
Route<T> sheetRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 500),
      reverseTransitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, a, __, child) {
        final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
        return SlideTransition(position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(c), child: child);
      },
    );

const midadBg = MidadColors.ink;
