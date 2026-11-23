import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../theme.dart';

/// شاشة بداية سينمائية: نجوم، غبار ذهبي، أشعة، ظهور اللوجو بلمعة، موجة صوت، ونغمة مميزة.
class CinematicSplash extends StatefulWidget {
  final VoidCallback onDone;
  const CinematicSplash({super.key, required this.onDone});

  @override
  State<CinematicSplash> createState() => _CinematicSplashState();
}

class _CinematicSplashState extends State<CinematicSplash> with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 4800));
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  AudioPlayer? _audio;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('introSound') ?? true) {
        final a = AudioPlayer();
        _audio = a;
        await a.setAsset('assets/sounds/intro.m4a');
        await a.setVolume(0.9);
        a.play();
      }
    } catch (_) {}
    if (!mounted) return;
    _c.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _loop.dispose();
    _audio?.dispose();
    super.dispose();
  }

  double _seg(double t, double a, double b, [Curve curve = Curves.easeOutCubic]) => curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    const gold = MidadColors.saffron;
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: Listenable.merge([_c, _loop]),
        builder: (context, _) {
          final t = _c.value;
          final sky = _seg(t, 0.0, 0.25);
          final glow = _seg(t, 0.08, 0.45);
          final rays = _seg(t, 0.2, 0.55);
          final logo = _seg(t, 0.18, 0.5, Curves.easeOutBack);
          final logoOp = _seg(t, 0.18, 0.4);
          final blur = 14 * (1 - _seg(t, 0.18, 0.48));
          final shine = _seg(t, 0.46, 0.74, Curves.easeInOut);
          final wave = _seg(t, 0.5, 0.66);
          final tag = _seg(t, 0.6, 0.8);
          final credit = _seg(t, 0.72, 0.9);
          return Stack(fit: StackFit.expand, children: [
            Opacity(
              opacity: sky,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(center: Alignment(0, -0.2), radius: 1.1, colors: [Color(0xFF16213F), MidadColors.ink, Colors.black], stops: [0, 0.55, 1]),
                ),
              ),
            ),
            CustomPaint(painter: _DustPainter(t: t, loop: _loop.value, opacity: sky)),
            Center(
              child: Transform.translate(
                offset: const Offset(0, -60),
                child: Stack(alignment: Alignment.center, children: [
                  Opacity(
                    opacity: rays * 0.55,
                    child: Transform.rotate(
                      angle: t * 0.6,
                      child: Container(
                        width: 520,
                        height: 520,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(colors: [
                            for (var i = 0; i < 12; i++) ...[gold.op(0), gold.op(0.18)],
                            gold.op(0),
                          ]),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 120 + 260 * glow,
                    height: 120 + 260 * glow,
                    decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                      BoxShadow(color: gold.op(0.35 * glow), blurRadius: 120 * glow + 1, spreadRadius: 10 * glow),
                    ]),
                  ),
                  Opacity(
                    opacity: logoOp,
                    child: Transform.scale(
                      scale: 0.8 + 0.2 * logo,
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: blur + 0.001, sigmaY: blur + 0.001),
                        child: ShaderMask(
                          blendMode: BlendMode.srcATop,
                          shaderCallback: (r) {
                            final x = -1.5 + 3.0 * shine;
                            return LinearGradient(
                              begin: Alignment(x - 0.4, -1),
                              end: Alignment(x + 0.4, 1),
                              colors: [Colors.white.op(0), Colors.white.op(shine > 0 && shine < 1 ? 0.55 : 0), Colors.white.op(0)],
                              stops: const [0.35, 0.5, 0.65],
                            ).createShader(r);
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(52),
                            child: Image.asset('assets/brand/logo.png', width: 230, height: 230),
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            Align(
              alignment: const Alignment(0, 0.42),
              child: Opacity(
                opacity: wave,
                child: SizedBox(
                  height: 34,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(23, (i) {
                      final d = (i - 11).abs() / 11;
                      final h = (6 + 26 * (1 - d) * (0.45 + 0.55 * (0.5 + 0.5 * math.sin(_loop.value * math.pi * 2 * 2 + i * 0.7)))) * wave;
                      return Container(
                        width: 3,
                        height: h.clamp(2.0, 34.0),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(color: gold.op(0.4 + 0.6 * (1 - d)), borderRadius: BorderRadius.circular(2)),
                      );
                    }),
                  ),
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0, 0.58),
              child: Opacity(
                opacity: tag,
                child: Transform.translate(
                  offset: Offset(0, 14 * (1 - tag)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(AppConfig.tagline, style: MidadText.ui(size: 16, weight: FontWeight.w600, color: const Color(0xFFF3E6C8))),
                    const SizedBox(height: 6),
                    Text('اقرأ بأذنك… واسمع بقلبك', style: MidadText.ui(size: 12, color: Colors.white54)),
                  ]),
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0, 0.93),
              child: Opacity(
                opacity: credit * 0.8,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('by ${AppConfig.developer}',
                      textDirection: TextDirection.ltr, style: MidadText.ui(size: 11, color: Colors.white54).copyWith(letterSpacing: 2)),
                  const SizedBox(height: 2),
                  Text('v${AppConfig.version}', textDirection: TextDirection.ltr, style: MidadText.ui(size: 10, color: Colors.white38)),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _DustPainter extends CustomPainter {
  final double t, loop, opacity;
  _DustPainter({required this.t, required this.loop, required this.opacity});

  static final _pts = List.generate(70, (i) {
    final r = math.Random(i * 31 + 7);
    return [r.nextDouble(), r.nextDouble(), 0.4 + r.nextDouble() * 1.6, r.nextDouble(), r.nextDouble()];
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (final s in _pts) {
      final star = s[4] > 0.45;
      if (star) {
        final a = (0.2 + 0.7 * (0.5 + 0.5 * math.sin(loop * math.pi * 2 + s[3] * 6))) * opacity;
        p.color = Colors.white.op(a);
        canvas.drawCircle(Offset(s[0] * size.width, s[1] * size.height * 0.7), s[2] * 0.8, p);
      } else {
        // غبار ذهبي يصعد ببطء
        final y = (s[1] - t * 0.25 - loop * 0.02 * s[3]) % 1.0;
        final a = (0.15 + 0.6 * s[3]) * opacity * (1 - (y - 0.5).abs());
        p.color = MidadColors.saffron.op(a.clamp(0.0, 1.0));
        canvas.drawCircle(Offset(s[0] * size.width + math.sin(t * 6 + s[3] * 9) * 8, y * size.height), s[2], p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DustPainter old) => true;
}
