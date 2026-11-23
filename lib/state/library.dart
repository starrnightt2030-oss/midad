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
  factory SavedQuote.fromJson(Map<String, dynamic> j) =>
      SavedQuote(text: j['t'] as String, workId: j['w'] as String, workTitle: j['wt'] as String, at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now());
}

/// المفضلة، آخر ما استمع له المستخدم، والخواطر المحفوظة — محفوظة على الجهاز.
class LibraryStore extends ChangeNotifier {
  final Set<String> favorites = {};
  final List<SavedQuote> quotes = [];
  final Map<String, int> lastChapter = {};
  final List<String> recent = [];
  double fontScale = 1.0;
  bool introSound = true;

  SharedPreferences? _p;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    favorites.addAll(_p!.getStringList('fav') ?? []);
    recent.addAll(_p!.getStringList('recent') ?? []);
    fontScale = _p!.getDouble('fontScale') ?? 1.0;
    introSound = _p!.getBool('introSound') ?? true;
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
