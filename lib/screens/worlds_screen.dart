import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';

import '../data/repository.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/world_art.dart';
import 'search.dart';
import 'world_screen.dart';

/// «عوالم أثير»: الأقسام في شبكة Bento سينمائية ببطاقات متنوعة الأحجام.
class WorldsScreen extends StatelessWidget {
  const WorldsScreen({super.key});

  static const _gutter = 18.0;

  /// نمط الشبكة (٤ أعمدة): بطاقة عريضة، ثم طويلة بجانب مربعة ونحيفة، ثم مربعتان.
  /// النمط يتكرر معكوسًا، فلا يتشابه صفّان متتاليان.
  static const _pattern = [
    QuiltedGridTile(2, 4),
    QuiltedGridTile(3, 2),
    QuiltedGridTile(2, 2),
    QuiltedGridTile(1, 2),
    QuiltedGridTile(2, 2),
    QuiltedGridTile(2, 2),
  ];

  @override
  Widget build(BuildContext context) {
    final cat = context.watch<ContentRepository>().catalog!;
    final worlds = cat.worlds.where((w) => worldShown(cat, w)).toList();
    final width = MediaQuery.sizeOf(context).width;
    // على الشاشات العريضة (تابلت) نوسّع الشبكة لـ٦ أعمدة بنفس النمط.
    final wideScreen = width >= 700;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverSafeArea(bottom: false, sliver: SliverToBoxAdapter(child: _Header(onSearch: () => openSearch(context)))),
        if (worlds.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('العوالم في الطريق...', style: MidadText.ui(color: Colors.white60))),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(_gutter, 8, _gutter, 28),
            sliver: SliverGrid(
              gridDelegate: SliverQuiltedGridDelegate(
                crossAxisCount: wideScreen ? 6 : 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                repeatPattern: QuiltedGridRepeatPattern.inverted,
                pattern: wideScreen
                    ? const [
                        QuiltedGridTile(2, 4),
                        QuiltedGridTile(2, 2),
                        QuiltedGridTile(2, 2),
                        QuiltedGridTile(1, 2),
                        QuiltedGridTile(1, 2),
                      ]
                    : _pattern,
              ),
              delegate: SliverChildBuilderDelegate(
                childCount: worlds.length,
                (context, i) {
                  final w = worlds[i];
                  return RepaintBoundary(
                    child: _WorldCard(
                      world: w,
                      index: cat.worlds.indexOf(w) + 1,
                      count: cat.worksOf(w.id).length,
                    ),
                  )
                      .animate(delay: (80 + 55 * (i < 10 ? i : 10)).ms)
                      .fadeIn(duration: 520.ms, curve: Curves.easeOutCubic)
                      .moveY(begin: 18, end: 0, duration: 620.ms, curve: Curves.easeOutCubic);
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onSearch;
  const _Header({required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final p = MidadColors.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(WorldsScreen._gutter, 14, WorldsScreen._gutter, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('عوالم أثير', style: MidadText.callig(size: 38))
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .moveY(begin: 10, end: 0, duration: 700.ms, curve: Curves.easeOutCubic),
              const SizedBox(height: 2),
              Text('لكل شعور حكاية... ولكل حكاية أثر', style: MidadText.book(size: 17, color: Colors.white70, height: 1.6))
                  .animate(delay: 150.ms)
                  .fadeIn(duration: 700.ms),
            ]),
          ),
          GlassIconButton(icon: Icons.search_rounded, onTap: onSearch, tooltip: 'بحث'),
        ]),
        const SizedBox(height: 14),
        Container(
          height: 1,
          width: 72,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: AlignmentDirectional.centerStart, end: AlignmentDirectional.centerEnd, colors: [p.accent, p.accent.op(0)]),
          ),
        )
            .animate(delay: 300.ms)
            .scaleX(begin: 0, end: 1, alignment: AlignmentDirectional.centerStart.resolve(TextDirection.rtl), duration: 700.ms),
      ]),
    );
  }
}

enum _Shape { wide, tall, square, slim }

/// بطاقة عالم: صورة القسم، تدرّج بلونه، رقمه، اسمه وعبارته.
class _WorldCard extends StatefulWidget {
  final World world;
  final int index;
  final int count;
  const _WorldCard({required this.world, required this.index, required this.count});

  @override
  State<_WorldCard> createState() => _WorldCardState();
}

class _WorldCardState extends State<_WorldCard> {
  bool pressed = false;

  /// شكل البطاقة من مقاسها الفعلي في الشبكة.
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final r = box.maxWidth / box.maxHeight;
        final shape = r > 1.6 ? (box.maxHeight < 120 ? _Shape.slim : _Shape.wide) : (r < 0.8 ? _Shape.tall : _Shape.square);
        return _build(context, shape);
      });

  Widget _build(BuildContext context, _Shape shape) {
    final w = widget.world;
    final slim = shape == _Shape.slim;
    final big = shape == _Shape.wide || shape == _Shape.tall;
    final radius = BorderRadius.circular(slim ? 18 : 24);

    return Semantics(
      button: true,
      label: '${w.name}. ${w.tagline}',
      child: GestureDetector(
        onTapDown: (_) => setState(() => pressed = true),
        onTapCancel: () => setState(() => pressed = false),
        onTapUp: (_) => setState(() => pressed = false),
        onTap: () => Navigator.of(context).push(fadeRoute(WorldScreen(worldId: w.id))),
        child: AnimatedScale(
          scale: pressed ? 0.97 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(color: w.color2.op(0.45), blurRadius: 22, offset: const Offset(0, 10)),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(fit: StackFit.expand, children: [
                Hero(tag: 'world-art-${w.id}', child: WorldArt(world: w, decodeWidth: big ? 900 : 520)),
                // تدرّج يضمن وضوح النص، بلون هوية القسم.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: slim
                        ? LinearGradient(
                            begin: AlignmentDirectional.centerStart,
                            end: AlignmentDirectional.centerEnd,
                            colors: [Colors.black.op(0.78), w.color2.op(0.35), Colors.transparent],
                            stops: const [0, 0.6, 1],
                          )
                        : LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black.op(0.10), Colors.transparent, w.color2.op(0.55), Colors.black.op(0.88)],
                            stops: const [0, 0.32, 0.68, 1],
                          ),
                  ),
                ),
                // إطار رفيع بلون القسم.
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(color: w.color.op(0.28)),
                  ),
                ),
                if (!slim)
                  PositionedDirectional(
                    top: 12,
                    start: 14,
                    child: Text(
                      arNum(widget.index),
                      style: MidadText.ui(size: 12, weight: FontWeight.w700, color: Colors.white.op(0.85)).copyWith(letterSpacing: 2),
                    ),
                  ),
                if (!slim) PositionedDirectional(top: 10, end: 10, child: _Badge(world: w, count: widget.count)),
                LayoutBuilder(builder: (context, box) {
                  // على الشاشات الصغيرة جدًا نخفف النص بدل ما يزيد عن البطاقة.
                  final roomy = box.maxHeight >= (big ? 170 : 130);
                  final pad = slim ? 14.0 : (box.maxHeight < 120 ? 12.0 : 16.0);
                  return Padding(
                    padding: EdgeInsets.all(pad),
                    child: Align(
                      alignment: slim ? AlignmentDirectional.centerStart : AlignmentDirectional.bottomStart,
                      child: Padding(
                        // في البطاقة النحيفة نسيب مكان للشارة.
                        padding: EdgeInsetsDirectional.only(end: slim ? 8 : 0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              w.name,
                              maxLines: slim || !roomy ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: MidadText.title(size: big ? 24 : (slim ? 16 : 18), height: 1.25)
                                  .copyWith(shadows: [Shadow(color: Colors.black.op(0.6), blurRadius: 12)]),
                            ),
                            if (slim)
                              Text(widget.count == 0 ? 'قريبًا' : clipsLabel(widget.count),
                                  style: MidadText.ui(size: 11, weight: FontWeight.w600, color: w.color.op(0.95), height: 1.3)),
                            if (!slim && roomy && w.tagline.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                w.tagline,
                                maxLines: big ? 2 : 1,
                                overflow: TextOverflow.ellipsis,
                                style: MidadText.book(size: big ? 15 : 13, color: Colors.white.op(0.82), height: 1.5),
                              ),
                            ],
                            if (!slim) ...[
                              const SizedBox(height: 8),
                              Container(
                                  height: 2, width: 28, decoration: BoxDecoration(color: w.color, borderRadius: BorderRadius.circular(2))),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// شارة صغيرة: عدد المقاطع أو «قريبًا».
class _Badge extends StatelessWidget {
  final World world;
  final int count;
  const _Badge({required this.world, required this.count});

  @override
  Widget build(BuildContext context) {
    final soon = count == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.op(0.42),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: world.color.op(0.45)),
      ),
      child: Text(
        soon ? 'قريبًا' : clipsLabel(count),
        style: MidadText.ui(size: 10.5, weight: FontWeight.w700, color: soon ? world.color : Colors.white),
      ),
    );
  }
}

/// «مقطع واحد»، «مقطعان»، «٣ مقاطع»، «١٥ مقطعًا».
String clipsLabel(int n) => switch (n) {
      1 => 'مقطع واحد',
      2 => 'مقطعان',
      _ => '${arNum(n)} ${n % 100 >= 3 && n % 100 <= 10 ? 'مقاطع' : 'مقطعًا'}',
    };
