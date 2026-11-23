import 'package:flutter/material.dart';

import 'theme.dart';

class World {
  final String id;
  final String name;
  final String short;
  final String tagline;
  final Color color;
  final String art;

  World({required this.id, required this.name, required this.short, required this.tagline, required this.color, required this.art});

  factory World.fromJson(Map<String, dynamic> j) => World(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        short: (j['short'] ?? j['name'] ?? '') as String,
        tagline: (j['tagline'] ?? '') as String,
        color: parseHex(j['color'] as String?),
        art: (j['art'] ?? 'storm') as String,
      );
}

class ChapterRef {
  final String id;
  final String title;
  final String? audio;
  final String script;

  ChapterRef({required this.id, required this.title, required this.script, this.audio});

  factory ChapterRef.fromJson(Map<String, dynamic> j) => ChapterRef(
        id: j['id'] as String,
        title: (j['title'] ?? '') as String,
        script: j['script'] as String,
        audio: (j['audio'] as String?)?.trim().isEmpty == true ? null : j['audio'] as String?,
      );
}

class Work {
  final String id;
  final String worldId;
  final String title;
  final String kind;
  final String description;
  final String art;
  final String? cover;
  final String narrator;
  final int minutes;
  final List<ChapterRef> chapters;

  Work({
    required this.id,
    required this.worldId,
    required this.title,
    required this.kind,
    required this.description,
    required this.art,
    required this.narrator,
    required this.minutes,
    required this.chapters,
    this.cover,
  });

  factory Work.fromJson(Map<String, dynamic> j) => Work(
        id: j['id'] as String,
        worldId: j['world'] as String,
        title: (j['title'] ?? '') as String,
        kind: (j['kind'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        art: (j['art'] ?? 'storm') as String,
        cover: (j['cover'] as String?)?.trim().isEmpty == true ? null : j['cover'] as String?,
        narrator: (j['narrator'] ?? '') as String,
        minutes: (j['minutes'] ?? 0) as int,
        chapters: ((j['chapters'] ?? []) as List).map((c) => ChapterRef.fromJson(c as Map<String, dynamic>)).toList(),
      );
}

class Ambience {
  final String id;
  final String name;
  final String icon;
  final String file;

  Ambience({required this.id, required this.name, required this.icon, required this.file});

  factory Ambience.fromJson(Map<String, dynamic> j) =>
      Ambience(id: j['id'] as String, name: (j['name'] ?? '') as String, icon: (j['icon'] ?? 'music') as String, file: j['file'] as String);
}

class Catalog {
  final List<World> worlds;
  final List<Work> works;
  final List<Ambience> ambience;
  final String version;

  Catalog({required this.worlds, required this.works, required this.ambience, required this.version});

  factory Catalog.fromJson(Map<String, dynamic> j) => Catalog(
        version: '${j['version'] ?? ''}',
        worlds: ((j['worlds'] ?? []) as List).map((e) => World.fromJson(e as Map<String, dynamic>)).toList(),
        works: ((j['works'] ?? []) as List).map((e) => Work.fromJson(e as Map<String, dynamic>)).toList(),
        ambience: ((j['ambience'] ?? []) as List).map((e) => Ambience.fromJson(e as Map<String, dynamic>)).toList(),
      );

  List<Work> worksOf(String worldId) => works.where((w) => w.worldId == worldId).toList();

  World? worldOf(Work w) {
    for (final x in worlds) {
      if (x.id == w.worldId) return x;
    }
    return null;
  }

  Work? workById(String id) {
    for (final w in works) {
      if (w.id == id) return w;
    }
    return null;
  }
}

class WordTiming {
  final double start;
  final double end;
  WordTiming(this.start, this.end);
}

class ScriptLine {
  final String speaker;
  final String text;
  double start;
  double end;
  List<WordTiming> words;

  ScriptLine({required this.speaker, required this.text, this.start = -1, this.end = -1, List<WordTiming>? words}) : words = words ?? [];

  List<String> get tokens => text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

  bool get hasTiming => start >= 0 && end > start;
}

class ChapterScript {
  final List<ScriptLine> lines;
  final Map<String, Color> speakerColors;

  ChapterScript({required this.lines, required this.speakerColors});

  factory ChapterScript.fromJson(Map<String, dynamic> j) {
    final colors = <String, Color>{};
    final sp = j['speakers'];
    if (sp is Map) {
      sp.forEach((k, v) {
        if (v is String) {
          colors['$k'] = parseHex(v);
        } else if (v is Map) {
          colors['$k'] = parseHex(v['color'] as String?);
        }
      });
    }
    final lines = ((j['lines'] ?? []) as List).map((e) {
      final m = e as Map<String, dynamic>;
      final words = <WordTiming>[];
      if (m['words'] is List) {
        for (final w in (m['words'] as List)) {
          if (w is List && w.length >= 2) {
            words.add(WordTiming((w[0] as num).toDouble(), (w[1] as num).toDouble()));
          } else if (w is Map) {
            words.add(WordTiming((w['s'] as num).toDouble(), (w['e'] as num).toDouble()));
          }
        }
      }
      return ScriptLine(
        speaker: (m['speaker'] ?? 'الراوي') as String,
        text: (m['text'] ?? '') as String,
        start: (m['start'] as num?)?.toDouble() ?? -1,
        end: (m['end'] as num?)?.toDouble() ?? -1,
        words: words,
      );
    }).toList();
    return ChapterScript(lines: lines, speakerColors: colors);
  }

  Color colorOf(String speaker) => speakerColors[speaker] ?? MidadColors.saffron;

  double get totalSeconds => lines.isEmpty ? 0 : lines.last.end;

  /// يحسب توقيتات تقديرية للسطور والكلمات لو الملف ليس فيه توقيتات حقيقية.
  /// [targetSeconds] لو معروف (مدة الصوت) يتم ضبط التقدير عليه.
  void ensureTimings({double? targetSeconds}) {
    final allTimed = lines.isNotEmpty && lines.every((l) => l.hasTiming);
    if (!allTimed) {
      var t = 0.6;
      for (final l in lines) {
        final chars = l.text.replaceAll(' ', '').length;
        final dur = (chars * 0.085).clamp(1.6, 30.0);
        l.start = t;
        l.end = t + dur;
        l.words = [];
        t = l.end + 0.7;
      }
      if (targetSeconds != null && targetSeconds > 1 && lines.isNotEmpty) {
        final k = targetSeconds / (lines.last.end + 0.6);
        for (final l in lines) {
          l.start *= k;
          l.end *= k;
        }
      }
    }
    for (final l in lines) {
      final toks = l.tokens;
      if (l.words.length == toks.length) continue;
      final weights = toks.map((w) => w.length + 1.0).toList();
      final sum = weights.fold<double>(0, (a, b) => a + b);
      var t = l.start;
      final span = l.end - l.start;
      l.words = [];
      for (final w in weights) {
        final d = sum == 0 ? 0.0 : span * w / sum;
        l.words.add(WordTiming(t, t + d));
        t += d;
      }
    }
  }

  int lineAt(double sec) {
    if (lines.isEmpty) return 0;
    for (var i = lines.length - 1; i >= 0; i--) {
      if (sec >= lines[i].start - 0.05) return i;
    }
    return 0;
  }

  int wordAt(int line, double sec) {
    if (line < 0 || line >= lines.length) return -1;
    final l = lines[line];
    if (sec < l.start) return -1;
    if (sec >= l.end) return l.words.length;
    for (var i = 0; i < l.words.length; i++) {
      if (sec < l.words[i].end) return i;
    }
    return l.words.length;
  }
}
