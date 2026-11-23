import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repository.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/cover_art.dart';
import '../widgets/mini_player.dart';
import 'actions.dart';
import 'work_screen.dart';

/// داخل العالم: رف ثلاثي الأبعاد للأعمال + قائمة كاملة.
class WorldScreen extends StatefulWidget {
  final World world;
  const WorldScreen({super.key, required this.world});

  @override
  State<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends State<WorldScreen> {
  final PageController _pc = PageController(viewportFraction: 0.56);
  double _page = 0;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _pc.addListener(() => setState(() => _page = _pc.page ?? 0));
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cat = context.watch<ContentRepository>().catalog!;
    final w = widget.world;
    final works = cat.worksOf(w.id);
    final cur = works.isEmpty ? null : works[_current.clamp(0, works.length - 1)];

    return Scaffold(
      backgroundColor: MidadColors.ink,
      body: Stack(children: [
        AmbientGlow(color: w.color, alignment: const Alignment(0.6, -0.5), size: 420, opacity: 0.4),
        AmbientGlow(color: w.color.darken(0.2), alignment: const Alignment(-0.8, 0.7), size: 360, opacity: 0.25),
        SafeArea(
          child: Column(children: [
            Expanded(
              child: CustomScrollView(slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Row(children: [
                      GlassIconButton(icon: Icons.arrow_back_rounded, tooltip: 'رجوع', onTap: () => Navigator.pop(context)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(w.name, style: MidadText.callig(size: 30, color: w.color)),
                          Text(w.tagline, style: MidadText.ui(size: 12, color: Colors.white70)),
                        ]),
                      ),
                    ]),
                  ),
                ),
                if (works.isEmpty)
                  SliverFillRemaining(child: Center(child: Text('قريبًا…', style: MidadText.ui(color: Colors.white70))))
                else ...[
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 360,
                      child: PageView.builder(
                        controller: _pc,
                        itemCount: works.length,
                        onPageChanged: (i) => setState(() => _current = i),
                        itemBuilder: (context, i) {
                          final d = (i - _page).clamp(-2.0, 2.0);
                          final ad = d.abs();
                          final m = Matrix4.identity()
                            ..setEntry(3, 2, 0.0012)
                            ..rotateY(d.clamp(-1.0, 1.0) * 0.55);
                          return Center(
                            child: Transform(
                              alignment: Alignment.center,
                              transform: m,
                              child: Transform.scale(
                                scale: 1 - 0.14 * ad,
                                child: Opacity(
                                  opacity: (1 - 0.35 * ad).clamp(0.0, 1.0),
                                  child: GestureDetector(
                                    onTap: () {
                                      if (i == _current) {
                                        Navigator.of(context).push(fadeRoute(WorkScreen(work: works[i])));
                                      } else {
                                        _pc.animateToPage(i, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
                                      }
                                    },
                                    child: _CoverCard(work: works[i], focused: ad < 0.5),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 450),
                      transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
                      child: Padding(
                        key: ValueKey(cur!.id),
                        padding: const EdgeInsets.fromLTRB(28, 6, 28, 0),
                        child: Column(children: [
                          Text(cur.description, textAlign: TextAlign.center, style: MidadText.book(size: 17, color: Colors.white.op(0.9), height: 1.8)),
                          const SizedBox(height: 14),
                          Row(children: [
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: MidadColors.ink,
                                  minimumSize: const Size(0, 52),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                                ),
                                onPressed: () => listenTo(context, cur),
                                icon: const Icon(Icons.headphones_rounded),
                                label: Text('استمع', style: MidadText.ui(weight: FontWeight.w700, color: MidadColors.ink)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 52),
                                  side: BorderSide(color: Colors.white.op(0.3)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                                ),
                                onPressed: () => liveRead(context, cur),
                                icon: const Icon(Icons.subtitles_outlined),
                                label: Text('قراءة حية', style: MidadText.ui(weight: FontWeight.w700)),
                              ),
                            ),
                          ]),
                        ]),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
                      child: Text('كل ما في هذا العالم', style: MidadText.ui(size: 16, weight: FontWeight.w700)),
                    ),
                  ),
                  SliverList.builder(
                    itemCount: works.length,
                    itemBuilder: (context, i) {
                      final x = works[i];
                      return InkWell(
                        onTap: () => Navigator.of(context).push(fadeRoute(WorkScreen(work: x))),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Row(children: [
                            SizedBox(width: 54, height: 72, child: CoverArt(art: x.art, url: x.cover, radius: BorderRadius.circular(10))),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(x.title, style: MidadText.ui(size: 15, weight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text('${x.kind} · ${arNum(x.minutes)} دقيقة · ${arNum(x.chapters.length)} ${x.chapters.length > 2 ? 'فصول' : 'فصل'}',
                                    style: MidadText.ui(size: 12, color: Colors.white70)),
                              ]),
                            ),
                            IconButton(
                              tooltip: 'استمع',
                              onPressed: () => listenTo(context, x),
                              icon: Icon(Icons.play_circle_fill_rounded, color: w.color, size: 36),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              ]),
            ),
            const MiniPlayer(),
          ]),
        ),
      ]),
    );
  }
}

class _CoverCard extends StatelessWidget {
  final Work work;
  final bool focused;
  const _CoverCard({required this.work, required this.focused});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Glass(
        radius: 26,
        opacity: focused ? 0.16 : 0.08,
        padding: const EdgeInsets.all(8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AspectRatio(
            aspectRatio: 0.8,
            child: Hero(
              tag: 'cover-${work.id}',
              child: Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(19), boxShadow: [
                  BoxShadow(color: Colors.black.op(0.45), blurRadius: 24, offset: const Offset(0, 12)),
                ]),
                child: CoverArt(art: work.art, url: work.cover, radius: BorderRadius.circular(19)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 4),
            child: Column(children: [
              Text(work.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: MidadText.title(size: 16)),
              Text('${work.kind} · ${arNum(work.minutes)} دقيقة', style: MidadText.ui(size: 11, color: Colors.white70)),
            ]),
          ),
        ]),
      ),
    );
  }
}
