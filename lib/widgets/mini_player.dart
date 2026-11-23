import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repository.dart';
import '../screens/player_screen.dart';
import '../state/player.dart';
import '../theme.dart';
import 'common.dart';
import 'cover_art.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerController>();
    final w = p.work;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (c, a) => SizeTransition(sizeFactor: a, child: FadeTransition(opacity: a, child: c)),
      child: w == null
          ? const SizedBox.shrink()
          : Padding(
              key: const ValueKey('mini'),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(sheetRoute(const PlayerScreen())),
                child: Glass(
                  radius: 30,
                  opacity: 0.12,
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  child: Row(children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: CoverArt(art: w.art, url: w.cover, radius: BorderRadius.circular(12)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(w.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: MidadText.ui(size: 13, weight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: p.progress,
                            minHeight: 3,
                            backgroundColor: Colors.white.op(0.18),
                            color: _accent(context, p),
                          ),
                        ),
                      ]),
                    ),
                    IconButton(
                      tooltip: p.playing ? 'إيقاف مؤقت' : 'تشغيل',
                      onPressed: p.toggle,
                      icon: Icon(p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 30),
                    ),
                  ]),
                ),
              ),
            ),
    );
  }

  Color _accent(BuildContext context, PlayerController p) {
    final cat = context.read<ContentRepository>().catalog;
    final w = p.work;
    if (cat == null || w == null) return MidadColors.saffron;
    return cat.worldOf(w)?.color ?? MidadColors.saffron;
  }
}
