import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../ambient/ambient_scene_engine.dart';
import '../ambient/ambient_style.dart';
import '../data/repository.dart';
import '../models.dart';
import '../state/library.dart';
import '../state/player.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/cover_art.dart';
import '../widgets/scene_layer.dart';
import 'ambient_gallery_screen.dart';
import 'live_read_screen.dart';
import 'quote_screen.dart';
import 'reader_screen.dart';

Color tone(Color c, double lightness) {
  final h = HSLColor.fromColor(c);
  return h.withLightness(lightness).withSaturation((h.saturation * 0.7).clamp(0.0, 0.6)).toColor();
}

/// شاشة التشغيل السينمائية: مشهد حي بملء الشاشة، تدرج داكن لوضوح النص،
/// وأدوات تحكم شفافة تختفي تدريجيًا بعد ٨ ثوانٍ وتعود بلمس الشاشة.
/// الصوت نفسه يبقى كما هو عبر PlayerController (لم يُستبدل محرك الصوت).
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  static const _idle = Duration(seconds: 8);
  double? _drag;
  bool _controls = true;
  bool _cinematic = false;
  int _wake = 0;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void dispose() {
    _hide?.cancel();
    if (_cinematic) SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  /// يعيد ضبط مؤقت الإخفاء (يُخفي الأدوات فقط أثناء التشغيل).
  void _arm() {
    _hide?.cancel();
    _hide = Timer(_idle, () {
      if (!mounted) return;
      final p = context.read<PlayerController>();
      if (p.playing && _drag == null) setState(() => _controls = false);
    });
  }

  void _poke() {
    if (_cinematic) return;
    if (!_controls) {
      setState(() {
        _controls = true;
        _wake++;
      });
    } else if (context.read<AmbientSceneSelector>().quality == AmbientQuality.sleep) {
      setState(() => _wake++);
    }
    _arm();
  }

  void _setCinematic(bool on) {
    setState(() {
      _cinematic = on;
      _controls = !on;
      _wake++;
    });
    SystemChrome.setEnabledSystemUIMode(on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
    if (!on) _arm();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerController>();
    final w = p.work;
    if (w == null) return const Scaffold();
    final sel = context.watch<AmbientSceneSelector>();
    final scene = sel.sceneFor(workId: w.id, mood: SceneLayer.resolve(w.scene, w.art));

    return Scaffold(
      backgroundColor: AmbientColors.midnightNavy,
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _poke(),
        child: Stack(fit: StackFit.expand, children: [
          // ١) المشهد الحي (يُعاد رسمه فقط، لا يُعاد بناؤه مع كل تحديث للصوت).
          if (scene != null)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 900),
              child: AmbientSceneView(key: ValueKey(scene.id), scene: scene, quality: sel.quality, wakeEpoch: _wake),
            )
          else
            Positioned.fill(child: SceneLayer(scene: SceneLayer.resolve(w.scene, w.art), tint: MidadColors.accent)),
          // ٢) تدرج داكن لضمان وضوح النصوص.
          IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 900),
              opacity: _cinematic ? 0.55 : (_controls ? 1 : 0.6),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x99080F1E), Color(0x00080F1E), Color(0x33080F1E), Color(0xF2080F1E)],
                    stops: [0, 0.2, 0.45, 1],
                  ),
                ),
              ),
            ),
          ),
          // ٣) الوضع السينمائي: سطر الحكي فقط.
          if (_cinematic) _CinematicLayer(onExit: () => _setCinematic(false)),
          // كلمات القصة تبقى ظاهرة فوق الخلفية بعد اختفاء أدوات التحكم (اللمس يعيد الأدوات).
          if (!_cinematic)
            IgnorePointer(
              child: AnimatedOpacity(
                duration: Duration(milliseconds: _controls ? 250 : 1200),
                opacity: _controls ? 0 : 1,
                child: const _CinematicLayer(),
              ),
            ),
          // ٤) أدوات التحكم.
          IgnorePointer(
            ignoring: !_controls,
            child: AnimatedOpacity(
              duration: Duration(milliseconds: _controls ? 350 : 1400),
              curve: Curves.easeOut,
              opacity: _controls ? 1 : 0,
              child: _controlsLayer(context, p, w, scene),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _controlsLayer(BuildContext context, PlayerController p, Work w, AmbientScene? scene) {
    final lib = context.watch<LibraryStore>();
    final repo = context.read<ContentRepository>();
    final category = repo.catalog?.worldOf(w)?.name ?? w.kind;
    final line = (p.script != null && p.script!.lines.isNotEmpty) ? p.script!.lines[p.lineIndex] : null;
    final fav = lib.isFav(w.id);
    const gold = AmbientColors.warmGold;
    const ivory = AmbientColors.softIvory;

    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
          child: Row(children: [
            IconButton(
                tooltip: 'تصغير', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32)),
            Expanded(
              child: Column(children: [
                Text('تستمع الآن', style: MidadText.ui(size: 11, color: Colors.white70)),
                Text(p.chapter?.title ?? '',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: MidadText.ui(size: 13, weight: FontWeight.w700)),
              ]),
            ),
            IconButton(tooltip: 'الوضع السينمائي', onPressed: () => _setCinematic(true), icon: const Icon(Icons.movie_filter_outlined)),
            IconButton(tooltip: 'الفصول', onPressed: () => _chapters(context, p), icon: const Icon(Icons.format_list_bulleted_rounded)),
          ]),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(children: [
            SizedBox(
              width: 58,
              height: 58,
              child: ClipRRect(borderRadius: BorderRadius.circular(14), child: CoverArt(art: w.art, url: w.cover)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(w.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: MidadText.title(size: 24, color: ivory)),
                const SizedBox(height: 2),
                Text(
                  [category, if (w.narrator.isNotEmpty) 'بصوت ${w.narrator}'].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MidadText.ui(size: 12, color: gold),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        if (line != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(fadeRoute(const LiveReadScreen())),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: AmbientColors.panel(radius: 18, opacity: 0.35),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Text(line.text,
                      key: ValueKey(p.lineIndex),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: MidadText.book(size: 16, color: ivory, height: 1.7)),
                ),
              ),
            ),
          ),
        const SizedBox(height: 10),
        SizedBox(height: 34, child: SoftWaves(playing: p.playing, color: gold)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
          child: Column(children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7)),
              child: Slider(
                value: (_drag ?? p.progress).clamp(0.0, 1.0),
                activeColor: ivory,
                inactiveColor: Colors.white24,
                onChanged: (v) => setState(() => _drag = v),
                onChangeEnd: (v) {
                  p.seek(Duration(milliseconds: (p.duration.inMilliseconds * v).round()));
                  setState(() => _drag = null);
                  _arm();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(fmtDuration(p.position), style: MidadText.ui(size: 11, color: Colors.white70)),
                if (p.demo) Text('عرض نصي — الصوت قريبًا', style: MidadText.ui(size: 10, color: Colors.white54)),
                Text(fmtDuration(p.duration), style: MidadText.ui(size: 11, color: Colors.white70)),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            TextButton(
              onPressed: p.cycleSpeed,
              child: Text('${arNum(p.speed)}×', style: MidadText.ui(weight: FontWeight.w700, color: ivory)),
            ),
            IconButton(tooltip: 'رجوع ١٠ ثوانٍ', iconSize: 32, onPressed: () => p.skip(-10), icon: const Icon(Icons.replay_10_rounded)),
            GestureDetector(
              onTap: p.toggle,
              child: Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(color: ivory, shape: BoxShape.circle, boxShadow: [
                  BoxShadow(color: Colors.black.op(0.35), blurRadius: 24, offset: const Offset(0, 10)),
                ]),
                child: Stack(alignment: Alignment.center, children: [
                  Icon(p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 40, color: AmbientColors.midnightNavy, semanticLabel: p.playing ? 'إيقاف مؤقت' : 'تشغيل'),
                  if (p.loadingChapter || p.buffering)
                    const SizedBox(
                        width: 66, height: 66, child: CircularProgressIndicator(strokeWidth: 2, color: AmbientColors.naturalTeal)),
                ]),
              ),
            ),
            IconButton(tooltip: 'تقديم ١٠ ثوانٍ', iconSize: 32, onPressed: () => p.skip(10), icon: const Icon(Icons.forward_10_rounded)),
            IconButton(
              tooltip: 'المفضلة',
              onPressed: () => lib.toggleFav(w.id),
              icon: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: fav ? gold : null),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 0, 26, 14),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(
              tooltip: 'اختيار الأجواء',
              onPressed: () => _ambience(context, p, scene),
              icon: Icon(Icons.landscape_rounded, color: p.ambience != null ? gold : null),
            ),
            IconButton(
                tooltip: 'قراءة حية',
                onPressed: () => Navigator.of(context).push(fadeRoute(const LiveReadScreen())),
                icon: const Icon(Icons.subtitles_outlined)),
            IconButton(
                tooltip: 'اقرأ',
                onPressed: () => Navigator.of(context).push(fadeRoute(const ReaderScreen())),
                icon: const Icon(Icons.menu_book_rounded)),
            IconButton(
              tooltip: 'اصنع خاطرة',
              onPressed: line == null ? null : () => Navigator.of(context).push(fadeRoute(QuoteScreen(text: line.text, work: w))),
              icon: const Icon(Icons.format_quote_rounded),
            ),
            IconButton(
              tooltip: 'مؤقت النوم',
              onPressed: () => _sleep(context, p),
              icon: Icon(p.sleepAt != null ? Icons.bedtime_rounded : Icons.bedtime_outlined, color: p.sleepAt != null ? gold : null),
            ),
          ]),
        ),
      ]),
    );
  }

  void _chapters(BuildContext context, PlayerController p) {
    final w = p.work!;
    showModalBottomSheet(
      context: context,
      backgroundColor: AmbientColors.calmBlue,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 16), children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text('الفصول', style: MidadText.title(size: 18))),
          for (var i = 0; i < w.chapters.length; i++)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: i == p.chapterIndex ? AmbientColors.warmGold : Colors.white10,
                child: Text(arNum(i + 1), style: MidadText.ui(color: i == p.chapterIndex ? AmbientColors.midnightNavy : Colors.white)),
              ),
              title: Text(w.chapters[i].title, style: MidadText.ui(weight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                p.openChapter(i);
                context.read<LibraryStore>().touch(w.id, i);
              },
            ),
        ]),
      ),
    );
  }

  /// اختيار الأجواء: المشهد الحي، وضع الحركة، والصوت المحيطي (مستقل عن صوت الراوي).
  void _ambience(BuildContext context, PlayerController p, AmbientScene? current) {
    final list = context.read<ContentRepository>().catalog?.ambience ?? [];
    final suggested = AmbientAudioMixer.suggestion(current, list);
    IconData ic(String n) => switch (n) {
          'rain' => Icons.water_drop_outlined,
          'sea' => Icons.waves_rounded,
          'night' => Icons.nightlight_round,
          'fire' => Icons.local_fire_department_outlined,
          'forest' => Icons.forest_outlined,
          'wind' => Icons.air_rounded,
          'stream' => Icons.water_rounded,
          _ => Icons.music_note_rounded,
        };
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AmbientColors.calmBlue,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => ChangeNotifierProvider.value(
        value: p,
        child: Consumer2<PlayerController, AmbientSceneSelector>(
          builder: (context, p, sel, _) {
            final scenes = [
              ...sel.registry.scenes.where((s) => sel.isFav(s.id)),
              ...sel.registry.scenes.where((s) => !sel.isFav(s.id) && !s.categories.contains('fantasy')),
            ];
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('المشهد الحي', style: MidadText.title(size: 18))),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(fadeRoute(const AmbientGalleryScreen()));
                      },
                      child: Text('أجواء أثير', style: MidadText.ui(weight: FontWeight.w700, color: AmbientColors.warmGold)),
                    ),
                  ]),
                  Wrap(spacing: 8, children: [
                    ChoiceChip(label: const Text('تلقائي حسب القصة'), selected: !sel.manual, onSelected: (_) => sel.setAuto()),
                    ChoiceChip(
                      label: const Text('اختياري'),
                      selected: sel.manual,
                      onSelected: (_) {
                        if (current != null) sel.choose(current.id);
                      },
                    ),
                  ]),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: scenes.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        final s = scenes[i];
                        final on = current?.id == s.id;
                        return GestureDetector(
                          onTap: () => sel.choose(s.id),
                          child: Container(
                            width: 72,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: on ? AmbientColors.warmGold : Colors.white12, width: on ? 2 : 1),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(fit: StackFit.expand, children: [
                              Image.asset(s.thumb, fit: BoxFit.cover, cacheWidth: 160),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  width: double.infinity,
                                  color: const Color(0xAA080F1E),
                                  padding: const EdgeInsets.all(3),
                                  child: Text(s.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: MidadText.ui(size: 9, color: AmbientColors.softIvory)),
                                ),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('حركة الخلفية', style: MidadText.ui(size: 13, color: Colors.white70)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final q in AmbientQuality.values)
                      ChoiceChip(label: Text(q.label), selected: sel.quality == q, onSelected: (_) => sel.setQuality(q)),
                  ]),
                  const SizedBox(height: 4),
                  Text(sel.quality.hint, style: MidadText.ui(size: 11, color: Colors.white54)),
                  const SizedBox(height: 18),
                  Text('صوت محيطي (اختياري)', style: MidadText.ui(size: 13, color: Colors.white70)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    ChoiceChip(label: const Text('بدون'), selected: p.ambience == null, onSelected: (_) => AmbientAudioMixer.play(p, null)),
                    for (final a in list)
                      ChoiceChip(
                        avatar: Icon(a.id == suggested?.id ? Icons.auto_awesome_rounded : ic(a.icon), size: 18),
                        label: Text(a.name),
                        selected: p.ambience?.id == a.id,
                        onSelected: (_) => AmbientAudioMixer.play(p, a),
                      ),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.volume_down_rounded),
                    Expanded(
                      child: Slider(
                        value: p.ambienceVolume.clamp(0.05, AmbientAudioMixer.maxVolume),
                        min: 0.05,
                        max: AmbientAudioMixer.maxVolume,
                        onChanged: (v) => AmbientAudioMixer.volume(p, v),
                      ),
                    ),
                    const Icon(Icons.volume_up_rounded),
                  ]),
                  Text('مستوى الصوت المحيطي مستقل عن صوت الراوي', style: MidadText.ui(size: 11, color: Colors.white54)),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }

  void _sleep(BuildContext context, PlayerController p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AmbientColors.calmBlue,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('مؤقت النوم', style: MidadText.title(size: 18)),
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final m in [10, 20, 30, 45, 60])
                ActionChip(
                  label: Text('${arNum(m)} دقيقة'),
                  onPressed: () {
                    p.setSleep(m);
                    Navigator.pop(context);
                  },
                ),
              ActionChip(
                label: const Text('إيقاف المؤقت'),
                onPressed: () {
                  p.setSleep(null);
                  Navigator.pop(context);
                },
              ),
            ]),
            const SizedBox(height: 14),
            Text('لتعتيم الشاشة تدريجيًا حتى السواد مع استمرار الصوت اختر وضع «النوم» من الأجواء.',
                style: MidadText.ui(size: 12, color: Colors.white60)),
          ]),
        ),
      ),
    );
  }
}

/// سطر الحكي الحالي بخط هادئ فوق المشهد: في الوضع السينمائي، وبعد اختفاء أدوات التحكم.
/// لو [onExit] موجود فاللمس يخرج من الوضع السينمائي.
class _CinematicLayer extends StatelessWidget {
  final VoidCallback? onExit;
  const _CinematicLayer({this.onExit});

  @override
  Widget build(BuildContext context) {
    final line = context.select<PlayerController, String?>((p) {
      final s = p.script;
      return (s != null && s.lines.isNotEmpty) ? s.lines[p.lineIndex].text : null;
    });
    final title = context.select<PlayerController, String>((p) => p.work?.title ?? '');
    return GestureDetector(
      behavior: onExit == null ? HitTestBehavior.deferToChild : HitTestBehavior.opaque,
      onTap: onExit,
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (line != null)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 700),
                  child: Text(line,
                      key: ValueKey(line),
                      textAlign: TextAlign.center,
                      style: MidadText.book(size: 19, color: AmbientColors.softIvory, height: 1.8)
                          .copyWith(shadows: const [Shadow(color: Colors.black87, blurRadius: 12)])),
                ),
              const SizedBox(height: 10),
              Text(title, style: MidadText.ui(size: 11, color: AmbientColors.warmGold.withValues(alpha: 0.8))),
            ]),
          ),
        ),
      ),
    );
  }
}

/// موجات صوتية ناعمة (زخرفية): تتحرك بهدوء أثناء التشغيل وتهدأ عند الإيقاف.
/// ليست تحليلًا حقيقيًا لطيف الصوت.
class SoftWaves extends StatefulWidget {
  final bool playing;
  final Color color;
  const SoftWaves({super.key, required this.playing, required this.color});

  @override
  State<SoftWaves> createState() => _SoftWavesState();
}

class _SoftWavesState extends State<SoftWaves> with TickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(seconds: 12));
  late final AnimationController _level = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant SoftWaves old) {
    super.didUpdateWidget(old);
    if (old.playing != widget.playing) _sync();
  }

  void _sync() {
    final still = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (widget.playing && !still) {
      _t.repeat();
      _level.forward();
    } else {
      _level.reverse().whenComplete(() {
        if (!widget.playing && mounted) _t.stop();
      });
    }
  }

  @override
  void dispose() {
    _t.dispose();
    _level.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(painter: _WavesPainter(_t, _level, widget.color), size: Size.infinite),
      );
}

class _WavesPainter extends CustomPainter {
  final Animation<double> t;
  final Animation<double> level;
  final Color color;
  _WavesPainter(this.t, this.level, this.color) : super(repaint: Listenable.merge([t, level]));

  final Paint _p = Paint()..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    const n = 34;
    final gap = size.width * 0.6 / (2 * n);
    final time = t.value * 12;
    final lv = 0.15 + 0.85 * level.value;
    _p.strokeWidth = math.max(2, gap * 0.45);
    for (var i = 0; i < n; i++) {
      final k = i / (n - 1);
      final env = math.sin(math.pi * k); // أطراف أهدأ من المنتصف
      final v = 0.5 + 0.25 * math.sin(time * 1.3 + i * 0.55) + 0.25 * math.sin(time * 0.7 - i * 0.31);
      final h = math.max(2.0, size.height * 0.9 * env * v * lv);
      _p.color = color.withValues(alpha: 0.35 + 0.45 * env);
      final x = size.width * 0.2 + gap * (2 * i + 1);
      canvas.drawLine(Offset(x, size.height / 2 - h / 2), Offset(x, size.height / 2 + h / 2), _p);
    }
  }

  @override
  bool shouldRepaint(covariant _WavesPainter old) => old.color != color;
}
