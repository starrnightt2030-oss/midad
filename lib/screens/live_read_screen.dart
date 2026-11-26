import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/library.dart';
import '../state/player.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/cover_art.dart';
import '../widgets/scene_layer.dart';
import 'quote_screen.dart';
import 'reader_screen.dart';

/// القراءة الحية: النص يظهر كلمة كلمة مع صوت الراوي.
class LiveReadScreen extends StatelessWidget {
  const LiveReadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerController>();
    final lib = context.watch<LibraryStore>();
    final w = p.work;
    final s = p.script;
    if (w == null) return const Scaffold();
    final color = MidadColors.accent;
    final hasLines = s != null && s.lines.isNotEmpty;
    final line = hasLines ? s!.lines[p.lineIndex.clamp(0, s.lines.length - 1)] : null;
    final spk = line == null ? color : s!.colorOf(line.speaker);

    return Scaffold(
      backgroundColor: MidadColors.ink,
      body: Stack(children: [
        Positioned.fill(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4, tileMode: TileMode.decal),
            child: SlowZoom(child: CoverArt(art: w.art, url: w.cover)),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [MidadColors.ink.op(0.4), MidadColors.ink.op(0.8), MidadColors.ink.op(0.94), MidadColors.ink],
                stops: const [0, 0.3, 0.7, 1],
              ),
            ),
          ),
        ),
        Positioned.fill(child: SceneLayer(scene: SceneLayer.resolve(w.scene, w.art), tint: color)),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Row(children: [
                GlassIconButton(icon: Icons.keyboard_arrow_down_rounded, tooltip: 'رجوع', onTap: () => Navigator.pop(context)),
                const Spacer(),
                Glass(
                  radius: 22,
                  opacity: 0.1,
                  padding: const EdgeInsets.all(4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                      child: Text('سينمائي', style: MidadText.ui(size: 12, weight: FontWeight.w700, color: MidadColors.ink)),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pushReplacement(fadeRoute(const ReaderScreen())),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text('صفحة', style: MidadText.ui(size: 12, weight: FontWeight.w600)),
                      ),
                    ),
                  ]),
                ),
                const Spacer(),
                GlassIconButton(
                  icon: Icons.text_fields_rounded,
                  tooltip: 'حجم الخط',
                  onTap: () => lib.setFontScale(lib.fontScale >= 1.3 ? 0.9 : lib.fontScale + 0.2),
                ),
              ]),
            ),
            const SizedBox(height: 18),
            Text('${w.title} · ${p.chapter?.title ?? ''}', textAlign: TextAlign.center, style: MidadText.ui(size: 12, color: Colors.white70)),
            const SizedBox(height: 14),
            if (line != null)
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.op(0.07),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: spk.op(0.8)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  TalkingBars(color: spk, active: p.playing),
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(line.speaker, key: ValueKey(line.speaker), style: MidadText.ui(size: 12, weight: FontWeight.w700, color: spk)),
                  ),
                ]),
              ),
            Expanded(
              child: !hasLines
                  ? Center(child: p.loadingChapter ? const CircularProgressIndicator() : Text('لا يوجد نص لهذا الفصل', style: MidadText.ui()))
                  : ShaderMask(
                      shaderCallback: (r) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                        stops: [0, 0.2, 0.8, 1],
                      ).createShader(r),
                      blendMode: BlendMode.dstIn,
                      child: _Lines(script: s!, current: p.lineIndex.clamp(0, s.lines.length - 1), word: p.wordIndex, scale: lib.fontScale, onTap: p.seekToLine),
                    ),
            ),
            if (line != null)
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(fadeRoute(QuoteScreen(text: line.text, work: w))),
                icon: const Icon(Icons.format_quote_rounded, size: 18),
                label: Text('اصنع خاطرة من هذا السطر', style: MidadText.ui(size: 12, weight: FontWeight.w600)),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(value: p.progress, minHeight: 3, color: color, backgroundColor: Colors.white.op(0.15)),
                ),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(hasLines ? 'السطر ${arNum(p.lineIndex + 1)} من ${arNum(s!.lines.length)}' : '', style: MidadText.ui(size: 11, color: Colors.white70)),
                  Text(p.ambience == null ? 'بدون موسيقى' : p.ambience!.name, style: MidadText.ui(size: 11, color: Colors.white70)),
                ]),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 6, 0, 16),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(tooltip: 'السطر السابق', iconSize: 34, onPressed: p.prevLine, icon: const Icon(Icons.skip_previous_rounded)),
                const SizedBox(width: 18),
                GestureDetector(
                  onTap: p.toggle,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [
                      BoxShadow(color: color.op(0.18), spreadRadius: 8),
                      BoxShadow(color: color.op(0.35), blurRadius: 30, offset: const Offset(0, 12)),
                    ]),
                    child: Icon(p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 38, color: MidadColors.ink, semanticLabel: p.playing ? 'إيقاف مؤقت' : 'تشغيل'),
                  ),
                ),
                const SizedBox(width: 18),
                IconButton(tooltip: 'السطر التالي', iconSize: 34, onPressed: p.nextLine, icon: const Icon(Icons.skip_next_rounded)),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Lines extends StatelessWidget {
  final ChapterScript script;
  final int current;
  final int word;
  final double scale;
  final void Function(int) onTap;

  const _Lines({required this.script, required this.current, required this.word, required this.scale, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final from = (current - 2).clamp(0, script.lines.length - 1);
    final to = (current + 2).clamp(0, script.lines.length - 1);
    final spacing = 118.0 * scale;
    return Stack(alignment: Alignment.center, children: [
      for (var i = from; i <= to; i++)
        TweenAnimationBuilder<double>(
          key: ValueKey(i),
          tween: Tween<double>(end: (i - current).toDouble()),
          duration: const Duration(milliseconds: 750),
          curve: Curves.easeOutCubic,
          builder: (context, v, child) {
            final a = v.abs();
            final o = a < 1 ? 1 - a * 0.62 : (0.38 * (2 - a)).clamp(0.0, 0.38);
            return Transform.translate(
              offset: Offset(0, v * spacing),
              child: Transform.scale(scale: 1 - a * 0.14, child: Opacity(opacity: o.clamp(0.0, 1.0), child: child)),
            );
          },
          child: GestureDetector(
            onTap: () => onTap(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: _lineText(i),
            ),
          ),
        ),
    ]);
  }

  Widget _lineText(int i) {
    final l = script.lines[i];
    final base = MidadText.book(size: 26 * scale, weight: FontWeight.w700, height: 1.75, color: Colors.white.op(0.85));
    if (i != current) return Text(l.text, textAlign: TextAlign.center, style: base);
    final c = script.colorOf(l.speaker);
    final toks = l.tokens;
    return RichText(
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
      text: TextSpan(style: base, children: [
        for (var k = 0; k < toks.length; k++)
          TextSpan(
            text: k == toks.length - 1 ? toks[k] : '${toks[k]} ',
            style: k < word
                ? base.copyWith(color: Colors.white)
                : k == word
                    ? base.copyWith(color: c, shadows: [Shadow(color: c, blurRadius: 18)])
                    : base.copyWith(color: Colors.white.op(0.32)),
          ),
      ]),
    );
  }
}
