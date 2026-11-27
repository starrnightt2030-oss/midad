import 'dart:async';

import '../design/motion.dart';
import 'library.dart';
import 'player.dart';

/// يربط المشغّل بـ«رحلتي»: يجمع وقت الاستماع الفعلي، ويعلّم القصة مكتملة عند نهايتها،
/// ويطبّق تفضيلات الحركة والنوم من الإعدادات. كل البيانات على الجهاز فقط.
class ListeningTracker {
  static const tick = Duration(seconds: 15);

  final PlayerController player;
  final LibraryStore library;
  Timer? _timer;

  ListeningTracker(this.player, this.library);

  void start() {
    library.addListener(_applyPrefs);
    player.addListener(_checkDone);
    _applyPrefs();
    _timer = Timer.periodic(tick, (_) => sample());
  }

  void _applyPrefs() {
    AtheerMotion.reduceMotion.value = library.reduceMotion || library.batterySaver;
    player.sleepFade = library.sleepFade;
  }

  /// يُستدعى كل [tick]. يحسب الوقت فقط أثناء تشغيل صوت حقيقي.
  void sample() {
    final w = player.work;
    if (w == null || !player.playing || player.demo) return;
    library.addListening(workId: w.id, worlds: w.worldIds, seconds: tick.inSeconds);
  }

  /// القصة تكتمل حين يصل الاستماع لآخر الفصل الأخير.
  void _checkDone() {
    final w = player.work;
    if (w == null || player.demo || library.isCompleted(w.id) || player.duration == Duration.zero) return;
    final lastChapter = w.chapters.isEmpty || player.chapterIndex >= w.chapters.length - 1;
    if (lastChapter && player.progress >= 0.97) library.markCompleted(w.id);
  }

  void dispose() {
    _timer?.cancel();
    library.removeListener(_applyPrefs);
    player.removeListener(_checkDone);
  }
}
