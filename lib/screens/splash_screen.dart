import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../theme.dart';

/// شاشة البداية: صوت يقول «حين تهدأ الحياة... وتتحدث الكلمات» والجملة تنكتب
/// كلمة كلمة مع الصوت، وبعدها «أثير الكلمات» واسم المطوّر بإضاءة نيون.
///
/// ملف الصوت: ضع التسجيل في `assets/sounds/intro_voice.mp3` (أو `.m4a`).
/// لو الملف مش موجود، الشاشة تشتغل بتوقيت افتراضي ونغمة البداية القديمة.
/// التزامن مع الصوت يتم من موضع التشغيل الفعلي، فأي تأخير في بدء الصوت لا يفسده.
class CinematicSplash extends StatefulWidget {
  final VoidCallback onDone;
  const CinematicSplash({super.key, required this.onDone});

  @override
  State<CinematicSplash> createState() => _CinematicSplashState();
}

/// كلمات الجملة على سطرين.
const _line1 = ['حين', 'تهدأ', 'الحياة...'];
const _line2 = ['وتتحدث', 'الكلمات'];

/// توقيت بداية كل كلمة بالملّي ثانية داخل ملف الصوت (بنفس ترتيب الكلمات).
/// لو `null` تتوزع الكلمات تلقائيًا على مدة الصوت حسب طول كل كلمة.
/// تُضبط بدقة بعد وصول التسجيل الحقيقي.
const List<int>? _wordCuesMs = null;

/// مدة الجملة لو مفيش ملف صوت.
const _defaultPhraseMs = 3800;

class _CinematicSplashState extends State<CinematicSplash> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;
  AudioPlayer? _voice;
  AudioPlayer? _tone;
  bool _started = false;
  bool _done = false;

  /// مدة الجملة (مدة ملف الصوت لو موجود).
  int _phraseMs = _defaultPhraseMs;

  /// اللحظة (من بداية التايملاين) التي بدأ عندها الصوت فعليًا.
  int? _voiceOffsetMs;

  late List<int> _cues = _autoCues(_defaultPhraseMs);

  static const _leadInMs = 700; // ظهور الخلفية قبل أول كلمة
  static const _wordFadeMs = 650;
  static const _brandGapMs = 450; // بعد نهاية الجملة
  static const _brandFlickerMs = 1100;
  static const _devGapMs = 700;
  static const _holdMs = 1800;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) {
      if (!mounted) return;
      setState(() => _elapsed = e);
      if (_started && !_done && _nowMs >= _endMs) _finish();
    });
    _start();
  }

  Future<void> _start() async {
    var sound = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      sound = prefs.getBool('introSound') ?? true;
    } catch (_) {}

    if (sound) {
      for (final path in const ['assets/sounds/intro_voice.mp3', 'assets/sounds/intro_voice.m4a']) {
        try {
          final a = AudioPlayer();
          final d = await a.setAsset(path);
          _voice = a;
          if (d != null && d.inMilliseconds > 800) _phraseMs = d.inMilliseconds;
          break;
        } catch (_) {}
      }
      if (_voice == null) {
        // لا يوجد تسجيل بعد: النغمة القديمة كخلفية.
        try {
          final t = AudioPlayer();
          await t.setAsset('assets/sounds/intro.m4a');
          await t.setVolume(0.7);
          _tone = t;
        } catch (_) {}
      }
    }
    _cues = _wordCuesMs ?? _autoCues(_phraseMs);
    if (!mounted) return;
    _started = true;
    _ticker.start();
    _tone?.play();
    if (_voice != null) {
      Future.delayed(const Duration(milliseconds: _leadInMs), () {
        if (!mounted || _done) return;
        _voice!.play();
      });
    }
  }

  /// توزيع بدايات الكلمات على مدة الصوت حسب عدد حروف كل كلمة.
  static List<int> _autoCues(int total) {
    final words = [..._line1, ..._line2];
    final weights = words.map((w) => w.replaceAll('.', '').length + 2).toList();
    // فاصل أطول بين السطرين (مكان «...»)
    weights[_line1.length - 1] += 3;
    final sum = weights.fold<int>(0, (a, b) => a + b);
    final span = total * 0.82;
    final cues = <int>[];
    var acc = 0.0;
    for (final w in weights) {
      cues.add((total * 0.04 + acc).round());
      acc += span * w / sum;
    }
    return cues;
  }

  /// الوقت الحالي في التايملاين. أثناء تشغيل الصوت نأخذه من موضع الصوت نفسه.
  int get _nowMs {
    final e = _elapsed.inMilliseconds;
    final v = _voice;
    if (v != null && !_done) {
      final finished = v.processingState == ProcessingState.completed;
      if (v.playing && !finished) {
        final pos = v.position.inMilliseconds;
        if (pos > 0) {
          _voiceOffsetMs ??= e - pos;
          return _leadInMs + pos;
        }
      }
      // الصوت لسه ما بدأش فعليًا: نستنّاه بدل ما الكلمات تسبقه.
      if (_voiceOffsetMs == null && !finished && e < _leadInMs + 2500) return math.min(e, _leadInMs);
    }
    // بعد انتهاء الصوت (أو لو مفيش) نكمل من الساعة العادية مع تعويض أي تأخير في بدء الصوت.
    final lag = _voiceOffsetMs == null ? 0 : (_voiceOffsetMs! - _leadInMs).clamp(0, 5000);
    return e - lag;
  }

  int get _phraseEnd => _leadInMs + _phraseMs;
  int get _brandStart => _phraseEnd + _brandGapMs;
  int get _devStart => _brandStart + _devGapMs;
  int get _endMs => _devStart + _brandFlickerMs + _holdMs;

  void _finish() {
    if (_done) return;
    _done = true;
    _voice?.pause();
    widget.onDone();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _voice?.dispose();
    _tone?.dispose();
    super.dispose();
  }

  double _seg(int now, int from, int dur, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((now - from) / dur).clamp(0.0, 1.0));

  /// إضاءة نيون تتذبذب عند التشغيل ثم تثبت مع «طنين» خفيف.
  double _neon(int now, int from) {
    final t = now - from;
    if (t <= 0) return 0;
    if (t < _brandFlickerMs) {
      const steps = [0.0, 0.9, 0.1, 0.0, 1.0, 0.35, 1.0, 0.6, 1.0];
      final p = t / _brandFlickerMs * (steps.length - 1);
      final i = p.floor().clamp(0, steps.length - 2);
      final f = p - i;
      // انتقالات سريعة حادة مثل أنبوب نيون
      return f < 0.5 ? steps[i] : steps[i + 1];
    }
    return 0.94 + 0.06 * math.sin(t / 90.0) * math.sin(t / 37.0);
  }

  @override
  Widget build(BuildContext context) {
    final now = _started ? _nowMs : 0;
    final words = [..._line1, ..._line2];
    final bg = _seg(now, 0, _leadInMs + 300);
    final brand = _neon(now, _brandStart);
    final brandIn = _seg(now, _brandStart, 500);
    final dev = _neon(now, _devStart);
    final settle = _seg(now, _brandStart, 900, Curves.easeInOut);
    final out = _seg(now, _endMs - 450, 450, Curves.easeIn);

    Widget word(int i) {
      final start = _leadInMs + _cues[i];
      final p = _seg(now, start, _wordFadeMs);
      final flash = math.sin(p * math.pi); // توهج لحظي وقت ظهور الكلمة
      return Opacity(
        opacity: p,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - p)),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 8 * (1 - p) + 0.001, sigmaY: 8 * (1 - p) + 0.001),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text(
                words[i],
                style: MidadText.book(size: 30, color: const Color(0xFFF6EEDC), height: 1.5).copyWith(shadows: [
                  Shadow(color: const Color(0xFFFFE2A8).op(0.25 + 0.55 * flash), blurRadius: 6 + 18 * flash),
                ]),
              ),
            ),
          ),
        ),
      );
    }

    Widget line(int from, int count) => Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.rtl,
          children: [for (var i = from; i < from + count; i++) word(i)],
        );

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _started ? _finish : null, // لمسة للتخطي
        child: Opacity(
          opacity: 1 - out * 0.35,
          child: Stack(fit: StackFit.expand, children: [
            Opacity(
              opacity: bg,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.1),
                    radius: 1.15,
                    colors: [const Color(0xFF15142A), const Color(0xFF0A0A16), Colors.black],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              ),
            ),
            RepaintBoundary(child: CustomPaint(painter: _DustPainter(ms: _elapsed.inMilliseconds, opacity: bg))),
            // وهج خلفي يكبر مع ظهور النيون
            Center(
              child: Container(
                width: 160 + 260 * brandIn,
                height: 160 + 260 * brandIn,
                decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                  BoxShadow(color: _NeonText.pink.op(0.18 * brand), blurRadius: 140, spreadRadius: 10),
                ]),
              ),
            ),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      // الجملة: تصغر وتخفت قليلًا لما يظهر الاسم
                      Transform.translate(
                        offset: Offset(0, -18 * settle),
                        child: Transform.scale(
                          scale: 1 - 0.12 * settle,
                          child: Opacity(
                            opacity: 1 - 0.3 * settle,
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              line(0, _line1.length),
                              line(_line1.length, _line2.length),
                            ]),
                          ),
                        ),
                      ),
                      const SizedBox(height: 34),
                      _NeonText(
                        'أثير الكلمات',
                        intensity: brand,
                        color: _NeonText.pink,
                        style: MidadText.callig(size: 58),
                      ),
                      const SizedBox(height: 18),
                      Opacity(
                        opacity: brandIn,
                        child: Container(
                          width: 120 * brandIn,
                          height: 1.2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              _NeonText.cyan.op(0),
                              _NeonText.cyan.op(0.8),
                              _NeonText.cyan.op(0),
                            ]),
                            boxShadow: [BoxShadow(color: _NeonText.cyan.op(0.6), blurRadius: 8)],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _NeonText(
                        AppConfig.developer,
                        intensity: dev,
                        color: _NeonText.cyan,
                        textDirection: TextDirection.ltr,
                        style: MidadText.ui(size: 17, weight: FontWeight.w600).copyWith(letterSpacing: 4),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0, 0.95),
              child: Opacity(
                opacity: _seg(now, _devStart, 800) * 0.6,
                child: Text('v${AppConfig.version}',
                    textDirection: TextDirection.ltr, style: MidadText.ui(size: 10, color: Colors.white38)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// نص بإضاءة نيون: قلب فاتح وطبقات وهج ملوّنة حوله. [intensity] من 0 (مطفي) إلى 1.
class _NeonText extends StatelessWidget {
  static const pink = Color(0xFFFF4FA3);
  static const cyan = Color(0xFF3FE8FF);

  final String text;
  final double intensity;
  final Color color;
  final TextStyle style;
  final TextDirection? textDirection;
  const _NeonText(this.text, {required this.intensity, required this.color, required this.style, this.textDirection});

  @override
  Widget build(BuildContext context) {
    final i = intensity.clamp(0.0, 1.0);
    // الأنبوب المطفي يظل ظاهرًا بشكل خافت جدًا
    final core = Color.lerp(color.op(0.10), Color.lerp(Colors.white, color, 0.25)!, i)!;
    return Text(
      text,
      textDirection: textDirection,
      style: style.copyWith(color: core, shadows: [
        Shadow(color: Colors.white.op(0.7 * i), blurRadius: 2),
        Shadow(color: color.op(0.95 * i), blurRadius: 6),
        Shadow(color: color.op(0.8 * i), blurRadius: 16),
        Shadow(color: color.op(0.6 * i), blurRadius: 32),
        Shadow(color: color.op(0.45 * i), blurRadius: 60),
      ]),
    );
  }
}

class _DustPainter extends CustomPainter {
  final int ms;
  final double opacity;
  _DustPainter({required this.ms, required this.opacity});

  static final _pts = List.generate(70, (i) {
    final r = math.Random(i * 31 + 7);
    return [r.nextDouble(), r.nextDouble(), 0.4 + r.nextDouble() * 1.4, r.nextDouble(), r.nextDouble()];
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    final s0 = ms / 1000.0;
    for (final s in _pts) {
      if (s[4] > 0.4) {
        final a = (0.15 + 0.6 * (0.5 + 0.5 * math.sin(s0 * math.pi + s[3] * 6))) * opacity;
        p.color = Colors.white.op(a);
        canvas.drawCircle(Offset(s[0] * size.width, s[1] * size.height), s[2] * 0.7, p);
      } else {
        // غبار ضوئي يصعد ببطء
        final y = (s[1] - s0 * 0.03 * (0.5 + s[3])) % 1.0;
        final a = (0.1 + 0.4 * s[3]) * opacity * (1 - (y - 0.5).abs());
        p.color = Color.lerp(MidadColors.saffron, _NeonText.pink, s[3])!.op(a.clamp(0.0, 1.0));
        canvas.drawCircle(Offset(s[0] * size.width + math.sin(s0 + s[3] * 9) * 8, y * size.height), s[2], p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DustPainter old) => old.ms != ms || old.opacity != opacity;
}
