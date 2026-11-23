import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../config.dart';
import '../data/repository.dart';
import '../models.dart';

/// يتحكم في صوت الراوي، الموسيقى الخلفية، والتزامن مع النص.
/// لو الفصل ليس له ملف صوت بعد، يعمل بـ"ساعة عرض" تقديرية حتى تظهر القراءة الحية.
class PlayerController extends ChangeNotifier {
  final ContentRepository repo;
  PlayerController(this.repo) {
    _subs.add(_voice.positionStream.listen((p) {
      if (!demo) {
        position = p;
        _tickText();
      }
    }));
    _subs.add(_voice.durationStream.listen((d) {
      if (d != null && !demo) {
        duration = d;
        script?.ensureTimings(targetSeconds: d.inMilliseconds / 1000);
        notifyListeners();
      }
    }));
    _subs.add(_voice.playerStateStream.listen((s) {
      if (demo) return;
      if (s.processingState == ProcessingState.completed) {
        _setPlaying(false);
        seek(Duration.zero);
      } else if (s.playing != playing) {
        _setPlaying(s.playing);
      }
      buffering = s.processingState == ProcessingState.loading || s.processingState == ProcessingState.buffering;
      notifyListeners();
    }));
  }

  final AudioPlayer _voice = AudioPlayer();
  final AudioPlayer _amb = AudioPlayer();
  final List<StreamSubscription> _subs = [];

  Work? work;
  int chapterIndex = 0;
  ChapterScript? script;
  bool demo = false;
  bool playing = false;
  bool buffering = false;
  bool loadingChapter = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  double speed = 1.0;
  Ambience? ambience;
  double ambienceVolume = 0.22;
  DateTime? sleepAt;

  int lineIndex = 0;
  int wordIndex = -1;

  Timer? _demoTimer;
  Timer? _sleepTimer;

  ChapterRef? get chapter => (work == null || work!.chapters.isEmpty) ? null : work!.chapters[chapterIndex];
  double get seconds => position.inMilliseconds / 1000;
  double get progress => duration.inMilliseconds == 0 ? 0 : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

  Future<void> open(Work w, {int chapter = 0, bool autoplay = true}) async {
    if (work?.id == w.id && chapterIndex == chapter && script != null) {
      if (autoplay && !playing) play();
      return;
    }
    await _stopAll();
    work = w;
    chapterIndex = chapter.clamp(0, w.chapters.isEmpty ? 0 : w.chapters.length - 1);
    position = Duration.zero;
    lineIndex = 0;
    wordIndex = -1;
    loadingChapter = true;
    notifyListeners();

    final ch = this.chapter;
    if (ch == null) {
      script = ChapterScript(lines: [], speakerColors: {});
      loadingChapter = false;
      notifyListeners();
      return;
    }
    script = await repo.loadScript(ch);
    script!.ensureTimings();

    demo = ch.audio == null;
    if (!demo) {
      try {
        final r = repo.resolve(ch.audio!);
        final d = r.remote ? await _voice.setUrl(r.path) : await _voice.setAsset(r.path);
        if (d != null) {
          duration = d;
          script!.ensureTimings(targetSeconds: d.inMilliseconds / 1000);
        }
      } catch (e) {
        debugPrint('audio failed, demo mode: $e');
        demo = true;
      }
    }
    if (demo) {
      duration = Duration(milliseconds: ((script!.totalSeconds + 1.2) * 1000).round());
    }
    loadingChapter = false;
    _tickText();
    notifyListeners();
    if (autoplay) play();
  }

  Future<void> openChapter(int i) async {
    final w = work;
    if (w == null) return;
    final keep = playing;
    script = null;
    await open(w, chapter: i, autoplay: keep);
  }

  void play() {
    if (work == null) return;
    _setPlaying(true);
    if (demo) {
      _demoTimer?.cancel();
      _demoTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        position += Duration(milliseconds: (100 * speed).round());
        if (position >= duration) {
          position = Duration.zero;
          pause();
        }
        _tickText();
      });
    } else {
      _voice.play();
    }
    if (ambience != null) _amb.play();
  }

  void pause() {
    _setPlaying(false);
    _demoTimer?.cancel();
    if (!demo) _voice.pause();
    _amb.pause();
  }

  void toggle() => playing ? pause() : play();

  void seek(Duration d) {
    if (d < Duration.zero) d = Duration.zero;
    if (duration > Duration.zero && d > duration) d = duration;
    position = d;
    if (!demo) _voice.seek(d);
    _tickText();
  }

  void skip(int secs) => seek(position + Duration(seconds: secs));

  void seekToLine(int i) {
    final s = script;
    if (s == null || s.lines.isEmpty) return;
    i = i.clamp(0, s.lines.length - 1);
    seek(Duration(milliseconds: (s.lines[i].start * 1000).round()));
  }

  void nextLine() => seekToLine(lineIndex + 1);
  void prevLine() {
    final s = script;
    if (s == null || s.lines.isEmpty) return;
    seekToLine(seconds > s.lines[lineIndex].start + 1.5 ? lineIndex : lineIndex - 1);
  }

  void cycleSpeed() {
    const speeds = [0.8, 1.0, 1.25, 1.5];
    final i = speeds.indexOf(speed);
    speed = speeds[(i + 1) % speeds.length];
    _voice.setSpeed(speed);
    notifyListeners();
  }

  Future<void> setAmbience(Ambience? a) async {
    ambience = a;
    notifyListeners();
    await _amb.stop();
    if (a == null) return;
    try {
      final r = repo.resolve(a.file);
      try {
        if (r.remote) {
          await _amb.setUrl(r.path);
        } else {
          await _amb.setAsset(r.path);
        }
      } catch (_) {
        await _amb.setAsset('${AppConfig.bundledContentBase}${a.file}');
      }
      await _amb.setLoopMode(LoopMode.one);
      await _amb.setVolume(ambienceVolume);
      if (playing) _amb.play();
    } catch (e) {
      debugPrint('ambience failed: $e');
    }
  }

  void setAmbienceVolume(double v) {
    ambienceVolume = v;
    _amb.setVolume(v);
    notifyListeners();
  }

  void setSleep(int? minutes) {
    _sleepTimer?.cancel();
    if (minutes == null) {
      sleepAt = null;
    } else {
      sleepAt = DateTime.now().add(Duration(minutes: minutes));
      _sleepTimer = Timer(Duration(minutes: minutes), () {
        pause();
        sleepAt = null;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void _setPlaying(bool v) {
    playing = v;
    notifyListeners();
  }

  void _tickText() {
    final s = script;
    if (s != null && s.lines.isNotEmpty) {
      final li = s.lineAt(seconds);
      final wi = s.wordAt(li, seconds);
      lineIndex = li;
      wordIndex = wi;
    }
    notifyListeners();
  }

  Future<void> _stopAll() async {
    _demoTimer?.cancel();
    playing = false;
    try {
      await _voice.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _demoTimer?.cancel();
    _sleepTimer?.cancel();
    _voice.dispose();
    _amb.dispose();
    super.dispose();
  }
}
