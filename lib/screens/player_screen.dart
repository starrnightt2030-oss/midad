import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repository.dart';
import '../state/library.dart';
import '../state/player.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/cover_art.dart';
import 'live_read_screen.dart';
import 'quote_screen.dart';
import 'reader_screen.dart';

Color tone(Color c, double lightness) {
  final h = HSLColor.fromColor(c);
  return h.withLightness(lightness).withSaturation((h.saturation * 0.7).clamp(0.0, 0.6)).toColor();
}

/// المشغّل الدائري: الغلاف يدور، وحلقة التقدم حوله، والخلفية بلون العالم.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 40));
  double? _drag;

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerController>();
    final lib = context.watch<LibraryStore>();
    final cat = context.watch<ContentRepository>().catalog;
    final w = p.work;
    if (w == null) return const Scaffold();
    final color = cat?.worldOf(w)?.color ?? MidadColors.saffron;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (p.playing && !_spin.isAnimating) {
        _spin.repeat();
      } else if (!p.playing && _spin.isAnimating) {
        _spin.stop();
      }
    });
    final line = (p.script != null && p.script!.lines.isNotEmpty) ? p.script!.lines[p.lineIndex] : null;
    final fav = lib.isFav(w.id);

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [tone(color, 0.36), tone(color, 0.2), tone(color, 0.09)],
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(children: [
                IconButton(tooltip: 'تصغير', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32)),
                Expanded(
                  child: Column(children: [
                    Text('تستمع الآن', style: MidadText.ui(size: 11, color: Colors.white70)),
                    Text(p.chapter?.title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: MidadText.ui(size: 13, weight: FontWeight.w700)),
                  ]),
                ),
                IconButton(tooltip: 'الفصول', onPressed: () => _chapters(context, p, color), icon: const Icon(Icons.format_list_bulleted_rounded)),
              ]),
            ),
            const SizedBox(height: 10),
            Text(w.title, textAlign: TextAlign.center, style: MidadText.title(size: 26)),
            Text(w.narrator.isEmpty ? w.kind : 'بصوت ${w.narrator}', style: MidadText.ui(size: 12, color: Colors.white70)),
            Expanded(
              child: Center(
                child: LayoutBuilder(builder: (context, c) {
                  final s = (c.maxHeight < c.maxWidth ? c.maxHeight : c.maxWidth).clamp(180.0, 310.0);
                  return SizedBox(
                    width: s,
                    height: s,
                    child: Stack(alignment: Alignment.center, children: [
                      CustomPaint(size: Size(s, s), painter: RingPainter(_drag ?? p.progress, Color.lerp(color, Colors.white, 0.35)!)),
                      Container(
                        width: s - 64,
                        height: s - 64,
                        decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                          BoxShadow(color: Colors.black.op(0.4), blurRadius: 40, offset: const Offset(0, 20)),
                        ]),
                        child: RotationTransition(turns: _spin, child: CoverArt(art: w.art, url: w.cover, shape: BoxShape.circle)),
                      ),
                      if (p.loadingChapter || p.buffering) const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 2)),
                    ]),
                  );
                }),
              ),
            ),
            if (line != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(fadeRoute(const LiveReadScreen())),
                  child: Glass(
                    radius: 18,
                    opacity: 0.08,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: Text(line.text,
                          key: ValueKey(p.lineIndex),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: MidadText.book(size: 16, color: Colors.white, height: 1.7)),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(children: [
                Slider(
                  value: (_drag ?? p.progress).clamp(0.0, 1.0),
                  activeColor: Colors.white,
                  inactiveColor: Colors.white24,
                  onChanged: (v) => setState(() => _drag = v),
                  onChangeEnd: (v) {
                    p.seek(Duration(milliseconds: (p.duration.inMilliseconds * v).round()));
                    setState(() => _drag = null);
                  },
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
                  child: Text('${arNum(p.speed)}×', style: MidadText.ui(weight: FontWeight.w700)),
                ),
                IconButton(tooltip: 'رجوع ١٠ ثوانٍ', iconSize: 32, onPressed: () => p.skip(-10), icon: const Icon(Icons.replay_10_rounded)),
                GestureDetector(
                  onTap: p.toggle,
                  child: Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [
                      BoxShadow(color: Colors.black.op(0.3), blurRadius: 24, offset: const Offset(0, 10)),
                    ]),
                    child: Icon(p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 40, color: MidadColors.ink, semanticLabel: p.playing ? 'إيقاف مؤقت' : 'تشغيل'),
                  ),
                ),
                IconButton(tooltip: 'تقديم ١٠ ثوانٍ', iconSize: 32, onPressed: () => p.skip(10), icon: const Icon(Icons.forward_10_rounded)),
                IconButton(
                  tooltip: 'المفضلة',
                  onPressed: () => lib.toggleFav(w.id),
                  icon: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: fav ? Color.lerp(color, Colors.white, 0.3) : null),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 0, 26, 14),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                IconButton(
                  tooltip: 'أجواء الاستماع',
                  onPressed: () => _ambience(context, p),
                  icon: Icon(Icons.graphic_eq_rounded, color: p.ambience != null ? Color.lerp(color, Colors.white, 0.3) : null),
                ),
                IconButton(tooltip: 'قراءة حية', onPressed: () => Navigator.of(context).push(fadeRoute(const LiveReadScreen())), icon: const Icon(Icons.subtitles_outlined)),
                IconButton(tooltip: 'اقرأ', onPressed: () => Navigator.of(context).push(fadeRoute(const ReaderScreen())), icon: const Icon(Icons.menu_book_rounded)),
                IconButton(
                  tooltip: 'اصنع خاطرة',
                  onPressed: line == null ? null : () => Navigator.of(context).push(fadeRoute(QuoteScreen(text: line.text, work: w))),
                  icon: const Icon(Icons.format_quote_rounded),
                ),
                IconButton(
                  tooltip: 'مؤقت النوم',
                  onPressed: () => _sleep(context, p),
                  icon: Icon(p.sleepAt != null ? Icons.bedtime_rounded : Icons.bedtime_outlined, color: p.sleepAt != null ? Color.lerp(color, Colors.white, 0.3) : null),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  void _chapters(BuildContext context, PlayerController p, Color color) {
    final w = p.work!;
    showModalBottomSheet(
      context: context,
      backgroundColor: MidadColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 16), children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text('الفصول', style: MidadText.title(size: 18))),
          for (var i = 0; i < w.chapters.length; i++)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: i == p.chapterIndex ? color : Colors.white10,
                child: Text(arNum(i + 1), style: MidadText.ui(color: i == p.chapterIndex ? MidadColors.ink : Colors.white)),
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

  void _ambience(BuildContext context, PlayerController p) {
    final list = context.read<ContentRepository>().catalog?.ambience ?? [];
    IconData ic(String n) => switch (n) {
          'rain' => Icons.water_drop_outlined,
          'sea' => Icons.waves_rounded,
          'night' => Icons.nightlight_round,
          'fire' => Icons.local_fire_department_outlined,
          _ => Icons.music_note_rounded,
        };
    showModalBottomSheet(
      context: context,
      backgroundColor: MidadColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => ChangeNotifierProvider.value(
        value: p,
        child: Consumer<PlayerController>(
          builder: (context, p, _) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('أجواء الاستماع', style: MidadText.title(size: 18)),
                const SizedBox(height: 4),
                Text('صوت خفيف يرافق الراوي', style: MidadText.ui(size: 12, color: Colors.white60)),
                const SizedBox(height: 16),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  ChoiceChip(label: const Text('بدون'), selected: p.ambience == null, onSelected: (_) => p.setAmbience(null)),
                  for (final a in list)
                    ChoiceChip(
                      avatar: Icon(ic(a.icon), size: 18),
                      label: Text(a.name),
                      selected: p.ambience?.id == a.id,
                      onSelected: (_) => p.setAmbience(a),
                    ),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  const Icon(Icons.volume_down_rounded),
                  Expanded(child: Slider(value: p.ambienceVolume, min: 0.05, max: 0.6, onChanged: p.setAmbienceVolume)),
                  const Icon(Icons.volume_up_rounded),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  void _sleep(BuildContext context, PlayerController p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MidadColors.surface,
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
          ]),
        ),
      ),
    );
  }
}
