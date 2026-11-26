
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// أوضاع الجودة التي يختارها المستخدم.
enum AmbientQuality {
  cinematic('سينمائي', 'كل المؤثرات المناسبة لجهازك'),
  balanced('متوازن', 'مؤثرات هادئة مع توفير البطارية'),
  eco('اقتصادي', 'حركة خفيفة جدًا وأداء موفر'),
  still('ثابت', 'خلفية ثابتة بدون حركة'),
  sleep('النوم', 'تخفت الشاشة تدريجيًا حتى السواد والصوت مستمر');

  final String label;
  final String hint;
  const AmbientQuality(this.label, this.hint);

  static AmbientQuality parse(String? s) => AmbientQuality.values.firstWhere((q) => q.name == s, orElse: () => AmbientQuality.balanced);
}

/// ما يحتاجه الرسام فعلًا من وضع الجودة.
@immutable
class AmbientBudget {
  /// إطارات في الثانية (0 = بدون حركة).
  final double fps;

  /// شدة مؤثرات الشيدر (0 = بدون شيدر).
  final double shaderLevel;

  /// نسبة عدد الجسيمات.
  final double particles;

  const AmbientBudget(this.fps, this.shaderLevel, this.particles);

  static const off = AmbientBudget(0, 0, 0);
  bool get animated => fps > 0;
}

/// يدير وضع الجودة الفعلي: يحترم «تقليل الحركة» في النظام، ويخفض الجودة تلقائيًا
/// لو كان رسم الإطارات أبطأ من المطلوب، ثم يعود تدريجيًا لو تحسن الأداء.
class AmbientPerformanceManager extends ChangeNotifier {
  AmbientPerformanceManager._();
  static final AmbientPerformanceManager instance = AmbientPerformanceManager._();

  /// خفض تلقائي للجودة عند الحاجة.
  bool autoAdapt = true;

  /// عدد درجات الخفض الحالية (0 = كما اختار المستخدم).
  int _downgrade = 0;
  int get downgrade => _downgrade;

  static AmbientBudget budgetFor(AmbientQuality q) => switch (q) {
        AmbientQuality.cinematic => const AmbientBudget(30, 1, 1),
        AmbientQuality.balanced => const AmbientBudget(24, 0.8, 0.6),
        AmbientQuality.eco => const AmbientBudget(15, 0.55, 0.3),
        AmbientQuality.sleep => const AmbientBudget(15, 0.5, 0.25),
        AmbientQuality.still => AmbientBudget.off,
      };

  /// الوضع الفعلي بعد احترام إعدادات النظام والخفض التلقائي.
  AmbientQuality effective(AmbientQuality chosen, {required bool reduceMotion}) {
    if (reduceMotion && chosen != AmbientQuality.sleep) return AmbientQuality.still;
    if (chosen == AmbientQuality.still || chosen == AmbientQuality.sleep) return chosen;
    const order = [AmbientQuality.cinematic, AmbientQuality.balanced, AmbientQuality.eco];
    final i = (order.indexOf(chosen) + _downgrade).clamp(0, order.length - 1);
    return order[i];
  }

  int _watchers = 0;
  final List<double> _raster = [];
  int _goodWindows = 0;

  /// تبدأ المراقبة ما دام هناك مشهد ظاهر.
  void watch() {
    if (_watchers++ == 0) SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void unwatch() {
    if (--_watchers == 0) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      _raster.clear();
    }
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!autoAdapt) return;
    for (final t in timings) {
      _raster.add(t.rasterDuration.inMicroseconds / 1000.0 + t.buildDuration.inMicroseconds / 1000.0);
    }
    if (_raster.length < 90) return;
    _raster.sort();
    // المئين ٩٠: الإطارات البطيئة هي ما يلاحظه المستخدم.
    final p90 = _raster[(_raster.length * 0.9).floor()];
    _raster.clear();
    reportFrameCost(p90);
  }

  /// يُستدعى بزمن الإطار (مللي ثانية). منفصل لتسهيل الاختبار.
  @visibleForTesting
  void reportFrameCost(double ms) {
    if (ms > 26 && _downgrade < 2) {
      _downgrade++;
      _goodWindows = 0;
      notifyListeners();
    } else if (ms < 12 && _downgrade > 0) {
      if (++_goodWindows >= 4) {
        _downgrade--;
        _goodWindows = 0;
        notifyListeners();
      }
    }
  }

  /// يلغي الخفض التلقائي (عند تغيير المستخدم للوضع).
  void reset() {
    _downgrade = 0;
    _goodWindows = 0;
  }
}
