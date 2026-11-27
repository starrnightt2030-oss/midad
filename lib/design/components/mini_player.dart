import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../screens/player_screen.dart';
import '../../state/player.dart';
import '../../theme.dart';
import '../../widgets/cover_art.dart';
import '../motion.dart';
import '../tokens.dart';
import 'buttons.dart';
import 'cards.dart';

/// المشغّل المصغّر العائم فوق شريط التنقّل.
/// الضغط عليه يفتح المشغّل الكامل بنفس الجلسة (الصوت لا يُعاد تشغيله).
class AtheerMiniPlayer extends StatelessWidget {
  const AtheerMiniPlayer({super.key});

  /// وسم Hero المشترك بين غلاف المشغّل المصغّر والمشغّل الكامل.
  static const coverHeroTag = 'atheer-now-playing-cover';

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerController>();
    final w = p.work;
    return AnimatedSwitcher(
      duration: AtheerMotion.of(context, AtheerMotion.slow),
      switchInCurve: AtheerMotion.emphasized,
      transitionBuilder: (c, a) => SizeTransition(sizeFactor: a, axisAlignment: 1, child: FadeTransition(opacity: a, child: c)),
      child: w == null
          ? const SizedBox.shrink()
          : Padding(
              key: const ValueKey('mini'),
              padding: const EdgeInsets.fromLTRB(AtheerSpacing.lg, 0, AtheerSpacing.lg, AtheerSpacing.sm),
              child: Semantics(
                button: true,
                label: 'فتح المشغّل: ${w.title}',
                child: AtheerPressable(
                  onTap: () => Navigator.of(context).push(AtheerMotion.rise(const PlayerScreen())),
                  scale: 0.985,
                  child: Container(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(AtheerRadius.lg), boxShadow: AtheerElevation.mid),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AtheerRadius.lg),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AtheerColors.surfaceHigh.op(0.78),
                            borderRadius: BorderRadius.circular(AtheerRadius.lg),
                            border: Border.all(color: Colors.white.op(AtheerOpacity.glassBorder), width: 0.8),
                          ),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 4, 6),
                              child: Row(children: [
                                SizedBox(
                                  width: 46,
                                  height: 46,
                                  child: CoverArt(art: w.art, url: w.cover, radius: BorderRadius.circular(AtheerRadius.sm)),
                                ),
                                const SizedBox(width: AtheerSpacing.md),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                                    Text(w.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AtheerType.label()),
                                    if (w.narrator.isNotEmpty || p.chapter != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        (w.chapters.length > 1 && p.chapter != null) ? p.chapter!.title : w.narrator,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AtheerType.bodySmall(),
                                      ),
                                    ],
                                  ]),
                                ),
                                AtheerIconButton(
                                  icon: Icons.replay_10_rounded,
                                  tooltip: 'رجوع ١٠ ثوانٍ',
                                  style: AtheerIconButtonStyle.plain,
                                  size: 40,
                                  onPressed: () => p.skip(-10),
                                ),
                                AtheerIconButton(
                                  icon: p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  tooltip: p.playing ? 'إيقاف مؤقت' : 'تشغيل',
                                  style: AtheerIconButtonStyle.accent,
                                  size: 42,
                                  onPressed: p.toggle,
                                ),
                              ]),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                              child: AtheerProgressLine(value: p.progress, height: 2.5),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
