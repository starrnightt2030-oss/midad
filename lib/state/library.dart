import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedQuote {
  final String text;
  final String workId;
  final String workTitle;
  final DateTime at;
  SavedQuote({required this.text, required this.workId, required this.workTitle, required this.at});

  Map<String, dynamic> toJson() => {'t': text, 'w': workId, 'wt': workTitle, 'at': at.toIso8601String()};
  factory SavedQuote.fromJson(Map<String, dynamic> j) => SavedQuote(
      text: j['t'] as String, workId: j['w'] as String, workTitle: j['wt'] as String, at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now());
}

/// المفضلة، آخر ما استمع له المستخدم، والخواطر المحفوظة — محفوظة على الجهاز.
class LibraryStore extends ChangeNotifier {
  final Set<String> favorites = {};
  final List<SavedQuote> quotes = [];
  final Map<String, int> lastChapter = {};
  final List<String> recent = [];
  double fontScale = 1.0;
  bool introSound = true;

  /// شاشة الترحيب تظهر مرة واحدة.
  bool onboarded = false;

  /// هدف المستخدم: sleep | relax | reflect
  String goal = 'sleep';

  /// اكتمل تحميل الإعدادات من الجهاز.
  bool loaded = false;

  // ── رحلتي: إحصائيات حقيقية من الاستماع على هذا الجهاز فقط ──
  /// ثواني الاستماع لكل يوم (yyyy-mm-dd).
  final Map<String, int> dailySeconds = {};

  /// ثواني الاستماع لكل عالم.
  final Map<String, int> worldSeconds = {};

  /// القصص المكتملة ووقت اكتمالها.
  final Map<String, DateTime> completed = {};

  /// سجل الاستماع (الأحدث أولًا): القصة ووقت آخر استماع.
  final List<({String id, DateTime at})> history = [];

  /// قوائم الاستماع الشخصية: الاسم ← معرّفات القصص.
  final Map<String, List<String>> playlists = {};

  // ── تفضيلات العرض ──
  bool reduceMotion = false;
  bool batterySaver = false;

  /// تعتيم ليلي تلقائي للواجهة بعد العاشرة مساءً.
  bool nightDim = false;

  /// خفوت الصوت تدريجيًا قبل توقف مؤقت النوم.
  bool sleepFade = true;

  /// مدة مؤقت النوم المفضلة في «سكينة».
  int sleepMinutes = 30;

  int get totalSeconds => dailySeconds.values.fold(0, (a, b) => a + b);

  SharedPreferences? _p;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    favorites.addAll(_p!.getStringList('fav') ?? []);
    recent.addAll(_p!.getStringList('recent') ?? []);
    fontScale = _p!.getDouble('fontScale') ?? 1.0;
    introSound = _p!.getBool('introSound') ?? true;
    onboarded = _p!.getBool('onboarded') ?? false;
    goal = _p!.getString('goal') ?? 'sleep';
    final q = _p!.getString('quotes');
    if (q != null) {
      try {
        quotes.addAll((jsonDecode(q) as List).map((e) => SavedQuote.fromJson(e as Map<String, dynamic>)));
      } catch (_) {}
    }
    final lc = _p!.getString('lastChapter');
    if (lc != null) {
      try {
        (jsonDecode(lc) as Map).forEach((k, v) => lastChapter['$k'] = v as int);
      } catch (_) {}
    }
    reduceMotion = _p!.getBool('reduceMotion') ?? false;
    batterySaver = _p!.getBool('batterySaver') ?? false;
    nightDim = _p!.getBool('nightDim') ?? false;
    sleepFade = _p!.getBool('sleepFade') ?? true;
    sleepMinutes = _p!.getInt('sleepMinutes') ?? 30;
    _readMap('dailySeconds', (k, v) => dailySeconds[k] = (v as num).toInt());
    _readMap('worldSeconds', (k, v) => worldSeconds[k] = (v as num).toInt());
    _readMap('completed', (k, v) {
      final d = DateTime.tryParse('$v');
      if (d != null) completed[k] = d;
    });
    _readMap('playlists', (k, v) => playlists[k] = (v as List).map((e) => '$e').toList());
    final h = _p!.getString('history');
    if (h != null) {
      try {
        for (final e in jsonDecode(h) as List) {
          final d = DateTime.tryParse('${e['at']}');
          if (d != null) history.add((id: '${e['id']}', at: d));
        }
      } catch (_) {}
    }
    loaded = true;
    notifyListeners();
  }

  void _readMap(String key, void Function(String, dynamic) put) {
    final raw = _p!.getString(key);
    if (raw == null) return;
    try {
      (jsonDecode(raw) as Map).forEach((k, v) => put('$k', v));
    } catch (_) {}
  }

  static String dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// يُستدعى أثناء التشغيل الفعلي فقط (كل بضع ثوانٍ) لتجميع وقت الاستماع.
  void addListening({required String workId, required List<String> worlds, required int seconds}) {
    if (seconds <= 0) return;
    final now = DateTime.now();
    final k = dayKey(now);
    dailySeconds[k] = (dailySeconds[k] ?? 0) + seconds;
    // نحتفظ بآخر ٣٦٥ يومًا فقط.
    if (dailySeconds.length > 365) {
      final keys = dailySeconds.keys.toList()..sort();
      for (final old in keys.take(dailySeconds.length - 365)) {
        dailySeconds.remove(old);
      }
    }
    for (final w in worlds) {
      worldSeconds[w] = (worldSeconds[w] ?? 0) + seconds;
    }
    history.removeWhere((e) => e.id == workId);
    history.insert(0, (id: workId, at: now));
    if (history.length > 100) history.removeLast();
    _p?.setString('dailySeconds', jsonEncode(dailySeconds));
    _p?.setString('worldSeconds', jsonEncode(worldSeconds));
    _p?.setString(
        'history',
        jsonEncode([
          for (final e in history) {'id': e.id, 'at': e.at.toIso8601String()}
        ]));
    notifyListeners();
  }

  bool isCompleted(String id) => completed.containsKey(id);

  void markCompleted(String id) {
    if (completed.containsKey(id)) return;
    completed[id] = DateTime.now();
    _p?.setString('completed', jsonEncode(completed.map((k, v) => MapEntry(k, v.toIso8601String()))));
    notifyListeners();
  }

  void clearHistory() {
    history.clear();
    _p?.remove('history');
    notifyListeners();
  }

  // ── قوائم الاستماع ──
  void _savePlaylists() => _p?.setString('playlists', jsonEncode(playlists));

  bool createPlaylist(String name) {
    final n = name.trim();
    if (n.isEmpty || playlists.containsKey(n)) return false;
    playlists[n] = [];
    _savePlaylists();
    notifyListeners();
    return true;
  }

  void deletePlaylist(String name) {
    playlists.remove(name);
    _savePlaylists();
    notifyListeners();
  }

  void togglePlaylistItem(String name, String workId) {
    final l = playlists[name];
    if (l == null) return;
    l.contains(workId) ? l.remove(workId) : l.add(workId);
    _savePlaylists();
    notifyListeners();
  }

  // ── التفضيلات ──
  void setReduceMotion(bool v) {
    reduceMotion = v;
    _p?.setBool('reduceMotion', v);
    notifyListeners();
  }

  void setBatterySaver(bool v) {
    batterySaver = v;
    _p?.setBool('batterySaver', v);
    notifyListeners();
  }

  void setNightDim(bool v) {
    nightDim = v;
    _p?.setBool('nightDim', v);
    notifyListeners();
  }

  void setSleepFade(bool v) {
    sleepFade = v;
    _p?.setBool('sleepFade', v);
    notifyListeners();
  }

  void setSleepMinutes(int v) {
    sleepMinutes = v;
    _p?.setInt('sleepMinutes', v);
    notifyListeners();
  }

  bool isFav(String id) => favorites.contains(id);

  void toggleFav(String id) {
    favorites.contains(id) ? favorites.remove(id) : favorites.add(id);
    _p?.setStringList('fav', favorites.toList());
    notifyListeners();
  }

  void touch(String workId, int chapter) {
    recent.remove(workId);
    recent.insert(0, workId);
    if (recent.length > 12) recent.removeLast();
    lastChapter[workId] = chapter;
    _p?.setStringList('recent', recent);
    _p?.setString('lastChapter', jsonEncode(lastChapter));
    notifyListeners();
  }

  void addQuote(SavedQuote q) {
    quotes.insert(0, q);
    _p?.setString('quotes', jsonEncode(quotes.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  void removeQuote(SavedQuote q) {
    quotes.remove(q);
    _p?.setString('quotes', jsonEncode(quotes.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  void finishOnboarding(String g) {
    goal = g;
    onboarded = true;
    _p?.setString('goal', g);
    _p?.setBool('onboarded', true);
    notifyListeners();
  }

  void setIntroSound(bool v) {
    introSound = v;
    _p?.setBool('introSound', v);
    notifyListeners();
  }

  void setFontScale(double v) {
    fontScale = v.clamp(0.8, 1.5);
    _p?.setDouble('fontScale', fontScale);
    notifyListeners();
  }
}
