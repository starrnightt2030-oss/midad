import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// ساعة المشهد: Ticker واحد يُحدّث الزمن بمعدل محدود (مثلًا ٣٠ إطارًا)
/// ويُبلغ الرسامين مباشرة (repaint) بدون إعادة بناء أي Widget.
///
/// الـ Ticker مأخوذ من TickerProvider الخاص بالشاشة، فيتوقف تلقائيًا
/// عندما تُغطّى الشاشة بأخرى (TickerMode)، ويُوقف يدويًا عند خروج التطبيق للخلفية.
class AmbientSceneController extends ChangeNotifier {
  AmbientSceneController(TickerProvider vsync) {
    _ticker = vsync.createTicker(_onTick);
  }

  late final Ticker _ticker;
  double _fps = 30;
  Duration _last = Duration.zero;
  Duration _base = Duration.zero;
  Duration _elapsed = Duration.zero;
  bool _wanted = false;
  bool _paused = false;

  /// الزمن الحالي للمشهد بالثواني.
  double time = 0;

  double get fps => _fps;
  bool get running => _ticker.isActive;

  set fps(double v) {
    if (v == _fps) return;
    _fps = v;
    _sync();
  }

  /// تشغيل الحركة (لو كان الإطار > 0).
  void start() {
    _wanted = true;
    _sync();
  }

  void stop() {
    _wanted = false;
    _sync();
  }

  /// إيقاف مؤقت لدورة حياة التطبيق (الخلفية) بدون نسيان رغبة التشغيل.
  set paused(bool v) {
    if (v == _paused) return;
    _paused = v;
    _sync();
  }

  void _sync() {
    final go = _wanted && !_paused && _fps > 0;
    if (go && !_ticker.isActive) {
      _base = _elapsed;
      _last = Duration.zero;
      _ticker.start();
    } else if (!go && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration d) {
    final frame = Duration(microseconds: (1e6 / _fps).round());
    // نسمح بهامش صغير حتى لا نفوّت إطارًا بسبب اختلاف توقيت الـ vsync.
    if (_last != Duration.zero && d - _last < frame - const Duration(milliseconds: 4)) return;
    _last = d;
    _elapsed = _base + d;
    time = _elapsed.inMicroseconds / 1e6;
    notifyListeners();
  }

  /// يبدأ الزمن من الصفر (عند تغيير المشهد).
  void resetTime() {
    _base = Duration.zero;
    _elapsed = Duration.zero;
    time = 0;
    if (_ticker.isActive) {
      _ticker.stop();
      _sync();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
