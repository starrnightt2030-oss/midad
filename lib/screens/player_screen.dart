import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../ambient/ambient_scene_engine.dart';
import '../ambient/ambient_style.dart';
import '../data/repository.dart';
import '../design/atheer_design_system.dart';
import '../models.dart';
import '../state/library.dart';
import '../state/player.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/cover_art.dart';
import '../widgets/scene_layer.dart';
import '../widgets/spoken_phrase.dart';
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

  /// الشاشة تفضل منورة طول ما شاشة التشغيل مفتوحة والصوت شغال (علشان الكلام يفضل ظاهر).
  /// لو المستخدم قفل الشاشة بنفسه الصوت يكمّل عادي في الخلفية.
  bool? _awake;
  void _keepAwake(bool on) {
    if (_awake == on) return;
    _awake = on;
    WakelockPlus.toggle(enable: on).catchError((_) {});
  }

  @override
  void dispose() {
    _hide?.cancel();
    if (_awake == true) WakelockPlus.disable().catchError((_) {});
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
    _keepAwake(p.playing);
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
    final gold = AtheerColors.accent;
    const ivory = AtheerColors.softIvory;
    final ambientOn = p.ambience != null || p.music != null;

    return SafeArea(
      child: Column(children: [
        // الشريط العلوي.
        Padding(
          padding: const EdgeInsets.fromLTRB(AtheerSpacing.sm, AtheerSpacing.xs, AtheerSpacing.sm, 0),
          child: Row(children: [
            AtheerIconButton(icon: Icons.keyboard_arrow_down_rounded, tooltip: 'تصغير', onPressed: () => Navigator.pop(context)),
            Expanded(
              child: Column(children: [
                Text('تستمع الآن', style: AtheerType.labelSmall(color: AtheerColors.textTertiary)),
                const SizedBox(height: 2),
                Text(p.chapter?.title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: AtheerType.label()),
              ]),
            ),
            AtheerIconButton(icon: Icons.movie_filter_outlined, tooltip: 'الوضع السينمائي', onPressed: () => _setCinematic(true)),
            if (w.chapters.length > 1) AtheerIconButton(icon: Icons.format_list_bulleted_rounded, tooltip: 'الفصول', onPressed: () => _chapters(context, p)),
          ]),
        ),
        const Spacer(),
        // لوح التحكم الزجاجي (بدون تضبيب فوق المشهد المتحرك لتوفير الطاقة).
        Padding(
          padding: const EdgeInsets.fromLTRB(AtheerSpacing.md, 0, AtheerSpacing.md, AtheerSpacing.md),
          child: AtheerGlassCard(
            blur: false,
            tint: AtheerColors.midnight,
            fill: 0.42,
            radius: BorderRadius.circular(AtheerRadius.xl),
            padding: const EdgeInsets.fromLTRB(AtheerSpacing.lg, AtheerSpacing.xl, AtheerSpacing.lg, AtheerSpacing.sm),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: Hero(
                    tag: AtheerMiniPlayer.coverHeroTag,
                    child: ClipRRect(borderRadius: BorderRadius.circular(AtheerRadius.sm + 2), child: CoverArt(art: w.art, url: w.cover)),
                  ),
                ),
                const SizedBox(width: AtheerSpacing.md + 2),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(w.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AtheerType.h2(color: ivory)),
                    const SizedBox(height: 3),
                    Text(
                      [category, if (w.narrator.isNotEmpty) 'بصوت ${w.narrator}'].where((e) => e.isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AtheerType.bodySmall(color: gold),
                    ),
                  ]),
                ),
                AtheerIconButton(
                  icon: fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  tooltip: fav ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
                  style: AtheerIconButtonStyle.plain,
                  selected: fav,
                  onPressed: () => lib.toggleFav(w.id),
                ),
              ]),
              if (line != null) ...[
                const SizedBox(height: AtheerSpacing.md + 2),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(AtheerMotion.fadeThrough(const LiveReadScreen())),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: AtheerSpacing.lg, vertical: AtheerSpacing.sm + 2),
                    decoration: BoxDecoration(color: Colors.white.op(0.05), borderRadius: BorderRadius.circular(AtheerRadius.md)),
                    child: SpokenPhrase(maxLines: 2, highlight: gold, style: AtheerType.quoteMedium(color: ivory).copyWith(fontSize: 17, height: 1.7)),
                  ),
                ),
              ],
              const SizedBox(height: AtheerSpacing.md),
              SizedBox(height: 30, child: SoftWaves(playing: p.playing, color: gold)),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                ),
                child: Slider(
                  value: (_drag ?? p.progress).clamp(0.0, 1.0),
                  activeColor: gold,
                  inactiveColor: Colors.white.op(0.18),
                  semanticFormatterCallback: (v) => fmtDuration(Duration(milliseconds: (p.duration.inMilliseconds * v).round())),
                  onChanged: (v) => setState(() => _drag = v),
                  onChangeEnd: (v) {
                    p.seek(Duration(milliseconds: (p.duration.inMilliseconds * v).round()));
                    setState(() => _drag = null);
                    _arm();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AtheerSpacing.md),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(fmtDuration(_drag == null ? p.position : Duration(milliseconds: (p.duration.inMilliseconds * _drag!).round())),
                      style: AtheerType.labelSmall(color: AtheerColors.textSecondary)),
                  if (p.demo)
                    Flexible(
                      child: Text('عرض نصي — الصوت قريبًا', maxLines: 1, overflow: TextOverflow.ellipsis, style: AtheerType.bodySmall()),
                    ),
                  Text(fmtDuration(p.duration), style: AtheerType.labelSmall(color: AtheerColors.textSecondary)),
                ]),
              ),
              const SizedBox(height: AtheerSpacing.xs),
              // أدوات التشغيل.
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _ToolChip(label: '${arNum(p.speed)}×', tooltip: 'سرعة التشغيل', onTap: () => _speed(context, p)),
                Semantics(
                  button: true,
                  label: 'رجوع ١٥ ثانية',
                  excludeSemantics: true,
                  child: AtheerPressable(
                    onTap: () => p.skip(-15),
                    child: const SizedBox(width: 52, height: 52, child: Center(child: AtheerSkipIcon(forward: false, size: 32))),
                  ),
                ),
                Semantics(
                  button: true,
                  label: p.playing ? 'إيقاف مؤقت' : 'تشغيل',
                  excludeSemantics: true,
                  child: AtheerPressable(
                    onTap: p.toggle,
                    scale: 0.94,
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(gradient: AtheerGradients.gold, shape: BoxShape.circle, boxShadow: AtheerElevation.glow(gold)),
                      child: Stack(alignment: Alignment.center, children: [
                        AnimatedSwitcher(
                          duration: AtheerMotion.fast,
                          child: Icon(p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              key: ValueKey(p.playing), size: 40, color: AtheerColors.midnight),
                        ),
                        if (p.loadingChapter || p.buffering)
                          const SizedBox(width: 66, height: 66, child: CircularProgressIndicator(strokeWidth: 2, color: AtheerColors.midnight)),
                      ]),
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'تقديم ١٥ ثانية',
                  excludeSemantics: true,
                  child: AtheerPressable(
                    onTap: () => p.skip(15),
                    child: const SizedBox(width: 52, height: 52, child: Center(child: AtheerSkipIcon(forward: true, size: 32))),
                  ),
                ),
                _ToolChip(
                  icon: p.sleepAt != null ? Icons.bedtime_rounded : Icons.bedtime_outlined,
                  label: p.sleepAt == null ? null : _left(p.sleepAt!),
                  tooltip: 'مؤقت النوم',
                  active: p.sleepAt != null,
                  onTap: () => _sleep(context, p),
                ),
              ]),
              const SizedBox(height: AtheerSpacing.xs),
              Divider(color: Colors.white.op(AtheerOpacity.hairline), height: AtheerSpacing.lg),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                AtheerIconButton(
                  icon: Icons.landscape_rounded,
                  tooltip: 'المشهد والأصوات المحيطية',
                  style: AtheerIconButtonStyle.plain,
                  selected: ambientOn,
                  onPressed: () => _ambience(context, p, scene),
                ),
                AtheerIconButton(
                  icon: Icons.subtitles_outlined,
                  tooltip: 'قراءة حية',
                  style: AtheerIconButtonStyle.plain,
                  onPressed: () => Navigator.of(context).push(AtheerMotion.fadeThrough(const LiveReadScreen())),
                ),
                AtheerIconButton(
                  icon: Icons.menu_book_rounded,
                  tooltip: 'اقرأ',
                  style: AtheerIconButtonStyle.plain,
                  onPressed: () => Navigator.of(context).push(AtheerMotion.fadeThrough(const ReaderScreen())),
                ),
                AtheerIconButton(
                  icon: Icons.format_quote_rounded,
                  tooltip: 'اصنع خاطرة',
                  style: AtheerIconButtonStyle.plain,
                  onPressed: line == null ? null : () => Navigator.of(context).push(AtheerMotion.fadeThrough(QuoteScreen(text: line.text, work: w))),
                ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }

  /// الوقت المتبقي على مؤقت النوم بالدقائق.
  String _left(DateTime at) {
    final m = at.difference(DateTime.now()).inMinutes + 1;
    return '${arNum(m < 1 ? 1 : m)}د';
  }

  void _speed(BuildContext context, PlayerController p) {
    AtheerBottomSheet.show(
      context,
      title: 'سرعة التشغيل',
      builder: (_) => ChangeNotifierProvider.value(
        value: p,
        child: Consumer<PlayerController>(
          builder: (context, p, _) => Wrap(spacing: AtheerSpacing.sm, runSpacing: AtheerSpacing.sm, children: [
            for (final s in PlayerController.speeds)
              _Choice(
                label: '${arNum(s)}×',
                selected: (p.speed - s).abs() < 0.01,
                onTap: () {
                  p.setSpeed(s);
                  Navigator.pop(context);
                },
              ),
          ]),
        ),
      ),
    );
  }

  void _chapters(BuildContext context, PlayerController p) {
    final w = p.work!;
    AtheerBottomSheet.show(
      context,
      title: 'الفصول',
      builder: (_) => ListView(shrinkWrap: true, children: [
        for (var i = 0; i < w.chapters.length; i++)
          AtheerPressable(
            onTap: () {
              Navigator.pop(context);
              p.openChapter(i);
              context.read<LibraryStore>().touch(w.id, i);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AtheerSpacing.sm),
              child: Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: i == p.chapterIndex ? AtheerGradients.accent : null,
                    border: i == p.chapterIndex ? null : Border.all(color: Colors.white.op(AtheerOpacity.glassBorder)),
                  ),
                  child: Text(arNum(i + 1), style: AtheerType.label(color: i == p.chapterIndex ? AtheerColors.background : AtheerColors.accent)),
                ),
                const SizedBox(width: AtheerSpacing.md),
                Expanded(child: Text(w.chapters[i].title, style: AtheerType.label())),
              ]),
            ),
          ),
      ]),
    );
  }

  /// اختيار الأجواء: المشهد الحي، وضع الحركة، والصوت المحيطي (مستقل عن صوت الراوي).
  void _ambience(BuildContext context, PlayerController p, AmbientScene? current) {
    final list = context.read<ContentRepository>().catalog?.ambience ?? [];
    final music = list.where((a) => a.isMusic).toList();
    final effects = list.where((a) => !a.isMusic).toList();
    final suggested = AmbientAudioMixer.suggestion(current, effects);
    IconData ic(String n) => switch (n) {
          'rain' => Icons.water_drop_outlined,
          'sea' => Icons.waves_rounded,
          'night' => Icons.nightlight_round,
          'fire' => Icons.local_fire_department_outlined,
          'forest' => Icons.forest_outlined,
          'wind' => Icons.air_rounded,
          'stream' => Icons.water_rounded,
          'birds' => Icons.flutter_dash,
          'thunder' => Icons.thunderstorm_outlined,
          'softnoise' => Icons.graphic_eq_rounded,
          'lullaby' => Icons.bedtime_outlined,
          'oriental' => Icons.mosque_outlined,
          'strings' => Icons.favorite_border_rounded,
          'harp' => Icons.auto_awesome_outlined,
          'mystery' => Icons.travel_explore_rounded,
          'morning' => Icons.wb_sunny_outlined,
          'piano' => Icons.piano,
          _ => Icons.music_note_rounded,
        };
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AtheerColors.surface,
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
                    for (final q in AmbientQuality.values) ChoiceChip(label: Text(q.label), selected: sel.quality == q, onSelected: (_) => sel.setQuality(q)),
                  ]),
                  const SizedBox(height: 4),
                  Text(sel.quality.hint, style: MidadText.ui(size: 11, color: Colors.white54)),
                  const SizedBox(height: 18),
                  Text('موسيقى الخلفية', style: MidadText.ui(size: 13, color: Colors.white70)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    ChoiceChip(
                      avatar: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: Text(p.musicMode == 'auto' && p.music != null ? 'تلقائي: ${p.music!.name}' : 'تلقائي'),
                      selected: p.musicMode == 'auto',
                      onSelected: (_) => p.setMusicMode('auto'),
                    ),
                    ChoiceChip(label: const Text('بدون'), selected: p.musicMode == 'off', onSelected: (_) => p.setMusicMode('off')),
                    for (final a in music)
                      ChoiceChip(
                        avatar: Icon(ic(a.icon), size: 18),
                        label: Text(a.name),
                        selected: p.musicMode == a.id,
                        onSelected: (_) => p.setMusicMode(a.id),
                      ),
                  ]),
                  if (p.musicLoading) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator(minHeight: 2)),
                  _volume(p.musicVolume, p.setMusicVolume, enabled: p.musicMode != 'off'),
                  const SizedBox(height: 14),
                  Text('مؤثرات صوتية (تشتغل مع الموسيقى)', style: MidadText.ui(size: 13, color: Colors.white70)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    ChoiceChip(label: const Text('بدون'), selected: p.ambience == null, onSelected: (_) => AmbientAudioMixer.play(p, null)),
                    for (final a in effects)
                      ChoiceChip(
                        avatar: Icon(a.id == suggested?.id ? Icons.auto_awesome_rounded : ic(a.icon), size: 18),
                        label: Text(a.name),
                        selected: p.ambience?.id == a.id,
                        onSelected: (_) => AmbientAudioMixer.play(p, a),
                      ),
                  ]),
                  _volume(p.ambienceVolume, (v) => AmbientAudioMixer.volume(p, v), enabled: p.ambience != null),
                  Text('مستوى الموسيقى والمؤثرات مستقل عن صوت الراوي', style: MidadText.ui(size: 11, color: Colors.white54)),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _volume(double v, ValueChanged<double> onChanged, {bool enabled = true}) => Row(children: [
        const Icon(Icons.volume_down_rounded),
        Expanded(
          child: Slider(
            value: v.clamp(0.05, AmbientAudioMixer.maxVolume),
            min: 0.05,
            max: AmbientAudioMixer.maxVolume,
            onChanged: enabled ? (x) => onChanged(x.clamp(0.05, AmbientAudioMixer.maxVolume)) : null,
          ),
        ),
        const Icon(Icons.volume_up_rounded),
      ]);

  void _sleep(BuildContext context, PlayerController p) {
    AtheerBottomSheet.show(
      context,
      title: 'مؤقت النوم',
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('يخفت الصوت تدريجيًا في آخر عشرين ثانية ثم يتوقف.', style: AtheerType.bodyMedium()),
        const SizedBox(height: AtheerSpacing.lg),
        Wrap(spacing: AtheerSpacing.sm, runSpacing: AtheerSpacing.sm, children: [
          for (final m in [5, 10, 15, 20, 30, 45, 60, 90])
            _Choice(
              label: '${arNum(m)} دقيقة',
              selected: false,
              onTap: () {
                p.setSleep(m);
                Navigator.pop(context);
              },
            ),
          if (p.sleepAt != null)
            _Choice(
              label: 'إيقاف المؤقت',
              selected: true,
              onTap: () {
                p.setSleep(null);
                Navigator.pop(context);
              },
            ),
        ]),
        const SizedBox(height: AtheerSpacing.lg),
        Text('لشاشة سوداء تمامًا مع استمرار الصوت اختر حركة «النوم» من المشهد والأصوات.', style: AtheerType.bodySmall()),
      ]),
    );
  }
}

/// زر أداة صغير في المشغّل (السرعة، مؤقت النوم).
class _ToolChip extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;
  const _ToolChip({this.icon, this.label, required this.tooltip, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    final c = active ? AtheerColors.accent : AtheerColors.textPrimary;
    return Semantics(
      button: true,
      label: label == null ? tooltip : '$tooltip: $label',
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: AtheerPressable(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            alignment: Alignment.center,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) Icon(icon, size: AtheerIconSize.md, color: c),
              if (label != null) Text(label!, style: AtheerType.label(color: c)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// اختيار داخل الأوراق السفلية.
class _Choice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Choice({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: AtheerPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AtheerMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: AtheerSpacing.lg, vertical: AtheerSpacing.sm + 2),
          decoration: BoxDecoration(
            gradient: selected ? AtheerGradients.accent : null,
            color: selected ? null : Colors.white.op(AtheerOpacity.glassFill),
            borderRadius: BorderRadius.circular(AtheerRadius.pill),
            border: Border.all(color: selected ? Colors.transparent : Colors.white.op(AtheerOpacity.hairline)),
          ),
          child: Text(label, style: AtheerType.label(color: selected ? AtheerColors.background : AtheerColors.textPrimary)),
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
    final hasLine = context.select<PlayerController, bool>((p) => p.script?.lines.isNotEmpty ?? false);
    final title = context.select<PlayerController, String>((p) => p.work?.title ?? '');
    return GestureDetector(
      behavior: onExit == null ? HitTestBehavior.deferToChild : HitTestBehavior.opaque,
      onTap: onExit,
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 36),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (hasLine)
                // تظليل خفيف شفاف خلف الكلام (نفس لوحة المشغّل) وخط أكبر للقراءة المريحة.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: AmbientColors.panel(radius: 20, opacity: 0.35),
                  child: SpokenPhrase(
                    fade: const Duration(milliseconds: 500),
                    highlight: AmbientColors.warmGold,
                    style: MidadText.book(size: 24, color: AmbientColors.softIvory, height: 1.75)
                        .copyWith(shadows: const [Shadow(color: Colors.black54, blurRadius: 8)]),
                  ),
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
