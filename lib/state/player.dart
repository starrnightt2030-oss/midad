import 'dart:async';

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../data/repository.dart';
import '../models.dart';
import 'audio_handler.dart';
import 'downloads.dart';

/// يتحكم في صوت الراوي، الموسيقى الخلفية، والتزامن مع النص.
/// لو الفصل ليس له ملف صوت بعد، يعمل بـ"ساعة عرض" تقديرية حتى تظهر القراءة الحية.
class PlayerController extends ChangeNotifier {
  final ContentRepository repo;

  /// التحميلات (لتشغيل الملفات المحفوظة بدون إنترنت).
  DownloadStore? downloads;
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
  final AudioPlayer _music = AudioPlayer();
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
  /// المؤثر الصوتي الحالي (مطر، بحر...). اختياري ومغلق افتراضيًا.
  Ambience? ambience;
  double ambienceVolume = 0.25;

  /// موسيقى الخلفية الحالية، وطريقة اختيارها: auto (حسب القصة) | off | معرّف مقطوعة.
  Ambience? music;
  String musicMode = 'auto';
  double musicVolume = 0.32;
  bool musicLoading = false;

  /// يختار الموسيقى المناسبة لقصة (يضبطه main حسب المشهد ونوع القصة).
  Ambience? Function(Work w)? autoMusic;

  static const _kMusicMode = 'atheer.music.mode';
  static const _kMusicVol = 'atheer.music.volume';
  static const _kFxVol = 'atheer.fx.volume';
  DateTime? sleepAt;

  int lineIndex = 0;
  int wordIndex = -1;

  Timer? _demoTimer;
  Timer? _sleepTimer;
  Timer? _fadeTimer;

  /// إشعار التشغيل وأزرار شاشة القفل (null لو الخدمة غير متاحة).
  AtheerAudioHandler? _media;

  void attachMedia(AtheerAudioHandler? h) {
    _media = h;
    if (h == null) return;
    h.onPlay = play;
    h.onPause = pause;
    h.onSeek = seek;
    h.onSkip = skip;
  }

  void _syncItem() {
    final m = _media, w = work, ch = chapter;
    if (m == null || w == null) return;
    Uri? art;
    final cover = w.cover;
    if (cover != null && cover.isNotEmpty) {
      final r = repo.resolve(cover);
      if (r.remote) art = Uri.tryParse(r.path);
    }
    m.showItem(
      id: '${w.id}/${ch?.id ?? ''}',
      title: ch == null || w.chapters.length < 2 ? w.title : '${w.title} · ${ch.title}',
      album: repo.catalog?.worldOf(w)?.name,
      artist: w.narrator.isEmpty ? AppConfig.appName : w.narrator,
      duration: duration > Duration.zero ? duration : null,
      artUri: art,
    );
  }

  void _syncState() =>
      _media?.showState(playing: playing, loading: loadingChapter || buffering, position: position, speed: speed);

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

    // الأولوية: ملف محمّل على الجهاز، ثم الرابط العام، ثم رابط مؤقت لصوت المشترك.
    final local = downloads?.localPath(w, ch);
    String? signed;
    if (local == null && ch.audio == null && w.premium) signed = await repo.signedAudio(ch);
    demo = local == null && ch.audio == null && signed == null;
    if (!demo) {
      try {
        final Duration? d;
        if (local != null) {
          d = await _voice.setFilePath(local);
        } else if (signed != null) {
          d = await _voice.setUrl(signed);
        } else {
          final r = repo.resolve(ch.audio!);
          d = r.remote ? await _voice.setUrl(r.path) : await _voice.setAsset(r.path);
        }
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
    _syncItem();
    _syncState();
    unawaited(_applyMusic());
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
    _layers(true);
  }

  /// الموسيقى والمؤثر يتبعان صوت الراوي (تشغيل/إيقاف من أي مكان، حتى من الإشعار).
  void _layers(bool on) {
    if (on) {
      if (ambience != null) _amb.play();
      if (music != null) _music.play();
    } else {
      _amb.pause();
      _music.pause();
    }
  }

  void pause() {
    _setPlaying(false);
    _demoTimer?.cancel();
    if (!demo) _voice.pause();
    _layers(false);
  }

  void toggle() => playing ? pause() : play();

  void seek(Duration d) {
    if (d < Duration.zero) d = Duration.zero;
    if (duration > Duration.zero && d > duration) d = duration;
    position = d;
    if (!demo) _voice.seek(d);
    _tickText();
    _syncState();
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

  /// سرعات التشغيل المتاحة.
  static const speeds = [0.75, 0.9, 1.0, 1.15, 1.25, 1.5, 1.75, 2.0];

  void setSpeed(double v) {
    speed = v;
    _voice.setSpeed(speed);
    notifyListeners();
    _syncState();
  }

  void cycleSpeed() {
    const speeds = [0.8, 1.0, 1.25, 1.5];
    final i = speeds.indexOf(speed);
    speed = speeds[(i + 1) % speeds.length];
    _voice.setSpeed(speed);
    notifyListeners();
    _syncState();
  }

  /// يجهّز ملف صوت خلفية: من داخل التطبيق، أو من الإنترنت مع حفظه على الجهاز
  /// (أول مرة يُبث مباشرة، وبعدها يعمل بدون إنترنت).
  Future<void> _load(AudioPlayer pl, Ambience a) async {
    final r = repo.resolve(a.file);
    if (!r.remote) {
      try {
        await pl.setAsset(r.path);
      } catch (_) {
        await pl.setAsset('${AppConfig.bundledContentBase}${a.file}');
      }
      return;
    }
    final f = await _cacheFile(a, r.path);
    if (f != null && f.existsSync() && f.lengthSync() > 1024) {
      await pl.setFilePath(f.path);
      return;
    }
    await pl.setUrl(r.path);
    if (f != null) unawaited(_download(r.path, f));
  }

  Future<File?> _cacheFile(Ambience a, String url) async {
    try {
      final dir = Directory('${(await getApplicationSupportDirectory()).path}/ambience');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      return File('${dir.path}/${a.id}-${url.hashCode.toUnsigned(32)}.m4a');
    } catch (_) {
      return null;
    }
  }

  Future<void> _download(String url, File f) async {
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(minutes: 2));
      if (res.statusCode != 200 || res.bodyBytes.length < 1024) return;
      final tmp = File('${f.path}.part');
      await tmp.writeAsBytes(res.bodyBytes, flush: true);
      await tmp.rename(f.path);
    } catch (e) {
      debugPrint('ambience cache failed: $e');
    }
  }

  /// المؤثر الصوتي (مطر، بحر...). null = بدون.
  Future<void> setEffect(Ambience? a) async {
    ambience = a;
    notifyListeners();
    await _amb.stop();
    if (a == null) return;
    try {
      await _load(_amb, a);
      await _amb.setLoopMode(LoopMode.one);
      await _amb.setVolume(ambienceVolume);
      if (playing && ambience?.id == a.id) _amb.play();
    } catch (e) {
      debugPrint('effect failed: $e');
      if (ambience?.id == a.id) {
        ambience = null;
        notifyListeners();
      }
    }
  }

  /// الاسم القديم (للتوافق).
  Future<void> setAmbience(Ambience? a) => setEffect(a);

  void setEffectVolume(double v) {
    ambienceVolume = v;
    _amb.setVolume(v);
    notifyListeners();
    _savePrefs();
  }

  void setAmbienceVolume(double v) => setEffectVolume(v);

  /// يختار طريقة الموسيقى: 'auto' حسب القصة، 'off' بدون، أو معرّف مقطوعة بعينها.
  Future<void> setMusicMode(String mode) async {
    musicMode = mode;
    _savePrefs();
    await _applyMusic();
  }

  /// الموسيقى المناسبة للقصة الحالية حسب الإعداد.
  Ambience? get musicTarget {
    final w = work;
    if (musicMode == 'off' || w == null) return null;
    final list = repo.catalog?.ambience ?? const <Ambience>[];
    if (musicMode != 'auto') {
      for (final a in list) {
        if (a.id == musicMode && a.isMusic) return a;
      }
    }
    return autoMusic?.call(w);
  }

  Future<void> _applyMusic() async {
    final a = musicTarget;
    if (a?.id == music?.id && (a == null || _music.audioSource != null)) {
      if (a != null && playing) _music.play();
      return;
    }
    music = a;
    musicLoading = a != null;
    notifyListeners();
    await _music.stop();
    if (a == null) return;
    try {
      await _load(_music, a);
      await _music.setLoopMode(LoopMode.one);
      await _music.setVolume(musicVolume);
      if (music?.id != a.id) return;
      if (playing) _music.play();
    } catch (e) {
      debugPrint('music failed: $e');
      // بدون إنترنت والمقطوعة لم تُحفظ بعد: نرجع للموسيقى المدمجة.
      final fallback = (repo.catalog?.ambience ?? const <Ambience>[])
          .where((x) => x.isMusic && !repo.isRemote(x.file))
          .firstOrNull;
      if (music?.id == a.id && fallback != null && fallback.id != a.id) {
        music = fallback;
        try {
          await _music.setAsset(repo.resolve(fallback.file).path);
          await _music.setLoopMode(LoopMode.one);
          await _music.setVolume(musicVolume);
          if (playing) _music.play();
        } catch (_) {
          music = null;
        }
      } else if (music?.id == a.id) {
        music = null;
      }
    } finally {
      musicLoading = false;
      notifyListeners();
    }
  }

  void setMusicVolume(double v) {
    musicVolume = v;
    _music.setVolume(v);
    notifyListeners();
    _savePrefs();
  }

  Future<void> loadPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      musicMode = p.getString(_kMusicMode) ?? 'auto';
      musicVolume = p.getDouble(_kMusicVol) ?? musicVolume;
      ambienceVolume = p.getDouble(_kFxVol) ?? ambienceVolume;
    } catch (_) {}
  }

  Future<void> _savePrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kMusicMode, musicMode);
      await p.setDouble(_kMusicVol, musicVolume);
      await p.setDouble(_kFxVol, ambienceVolume);
    } catch (_) {}
  }

  /// مدة الخفوت التدريجي قبل الإيقاف (حتى لا يوقظ التوقف المفاجئ النائم).
  static const _fadeSteps = 20;
  static const _fadeStep = Duration(seconds: 1);

  void setSleep(int? minutes) {
    _sleepTimer?.cancel();
    _cancelFade();
    if (minutes == null) {
      sleepAt = null;
    } else {
      sleepAt = DateTime.now().add(Duration(minutes: minutes));
      final total = Duration(minutes: minutes);
      final fadeAt = total - _fadeStep * _fadeSteps;
      _sleepTimer = Timer(fadeAt.isNegative ? Duration.zero : fadeAt, _fadeOutAndStop);
    }
    notifyListeners();
  }

  void _fadeOutAndStop() {
    var step = 0;
    _fadeTimer?.cancel();
    _fadeTimer = Timer.periodic(_fadeStep, (t) {
      step++;
      final k = (1 - step / _fadeSteps).clamp(0.0, 1.0);
      _voice.setVolume(k);
      _amb.setVolume(ambienceVolume * k);
      _music.setVolume(musicVolume * k);
      if (step >= _fadeSteps) {
        t.cancel();
        pause();
        _voice.setVolume(1);
        _amb.setVolume(ambienceVolume);
        _music.setVolume(musicVolume);
        sleepAt = null;
        notifyListeners();
      }
    });
  }

  void _cancelFade() {
    if (_fadeTimer == null) return;
    _fadeTimer!.cancel();
    _fadeTimer = null;
    _voice.setVolume(1);
    _amb.setVolume(ambienceVolume);
    _music.setVolume(musicVolume);
  }

  void _setPlaying(bool v) {
    if (v != playing) _layers(v);
    playing = v;
    notifyListeners();
    _syncState();
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
    _layers(false);
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
    _fadeTimer?.cancel();
    _voice.dispose();
    _amb.dispose();
    _music.dispose();
    super.dispose();
  }
}
