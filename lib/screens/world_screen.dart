import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../design/atheer_design_system.dart';
import '../data/repository.dart';
import '../models.dart';
import '../state/library.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/cover_art.dart';
import '../widgets/story_card.dart';
import '../widgets/world_art.dart';
import 'actions.dart';
import 'work_screen.dart';
import 'worlds_screen.dart' show clipsLabel;

enum _Filter { all, free, premium, short, favorites }

enum _Sort { order, newest, popular }

/// صفحة القسم السينمائية: غلاف بهوية القسم، وصفه، عدد مقاطعه، أحدث الإضافات،
/// الأكثر استماعًا، بحث وتصفية، وعرض شبكة أو قائمة.
class WorldScreen extends StatefulWidget {
  final String worldId;
  const WorldScreen({super.key, required this.worldId});

  @override
  State<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends State<WorldScreen> {
  /// اختيار المستخدم للعرض (شبكة/قائمة) يفضل طول ما التطبيق مفتوح.
  static bool _listView = false;

  final _query = TextEditingController();
  _Filter filter = _Filter.all;
  _Sort sort = _Sort.order;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<Work> _apply(List<Work> all, LibraryStore lib) {
    final q = _query.text.trim();
    var out = all.where((w) {
      if (q.isNotEmpty && !(w.title.contains(q) || w.description.contains(q) || w.narrator.contains(q) || w.kind.contains(q))) {
        return false;
      }
      return switch (filter) {
        _Filter.all => true,
        _Filter.free => !w.premium,
        _Filter.premium => w.premium,
        _Filter.short => w.minutes > 0 && w.minutes <= 5,
        _Filter.favorites => lib.isFav(w.id),
      };
    }).toList();
    switch (sort) {
      case _Sort.order:
        break;
      case _Sort.newest:
        out.sort((a, b) => (b.added ?? DateTime(2000)).compareTo(a.added ?? DateTime(2000)));
      case _Sort.popular:
        out.sort((a, b) => b.plays.compareTo(a.plays));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final cat = context.watch<ContentRepository>().catalog!;
    final lib = context.watch<LibraryStore>();
    final world = cat.worldById(widget.worldId);
    if (world == null) {
      return Scaffold(
        backgroundColor: MidadColors.ink,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: Center(child: Text('القسم غير متاح حاليًا', style: AtheerType.bodyMedium())),
      );
    }
    final all = cat.worksOf(world.id);
    final filtering = _query.text.trim().isNotEmpty || filter != _Filter.all || sort != _Sort.order;
    final shown = _apply(all, lib);
    final newest = [...all]..sort((a, b) => (b.added ?? DateTime(2000)).compareTo(a.added ?? DateTime(2000)));
    final popular = all.where((w) => w.plays > 0).toList()..sort((a, b) => b.plays.compareTo(a.plays));
    final minutes = all.fold<int>(0, (s, w) => s + w.minutes);
    final dark = Color.lerp(world.color2, Colors.black, 0.55)!;

    return Scaffold(
      backgroundColor: dark,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(world.color2, Colors.black, 0.35)!, dark, MidadColors.ink],
            stops: const [0, 0.45, 1],
          ),
        ),
        child: Stack(children: [
          AmbientGlow(color: world.color, alignment: const Alignment(-0.9, 0.2), size: 320, opacity: 0.14),
          CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              _Cover(world: world),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (world.description.isNotEmpty)
                      Text(world.description,
                          style: AtheerType.quoteMedium(color: AtheerColors.softIvory.op(0.86)).copyWith(fontSize: 17, height: 1.8)),
                    const SizedBox(height: 14),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _Stat(icon: Icons.graphic_eq_rounded, text: all.isEmpty ? 'قريبًا' : clipsLabel(all.length), color: world.color),
                      if (minutes > 0) _Stat(icon: Icons.schedule_rounded, text: '${arNum(minutes)} دقيقة استماع', color: world.color),
                      if (world.premium) _Stat(icon: Icons.lock_rounded, text: 'للمشتركين', color: world.color),
                    ]),
                  ]).animate().fadeIn(duration: 500.ms, delay: 150.ms).moveY(begin: 12, end: 0, curve: Curves.easeOutCubic),
                ),
              ),
              if (all.isEmpty)
                SliverFillRemaining(hasScrollBody: false, child: _Soon(world: world))
              else ...[
                SliverToBoxAdapter(child: _searchBar(world)),
                if (!filtering && all.length >= 3) ...[
                  SliverToBoxAdapter(child: _RailHeader(title: 'أحدث الإضافات', color: world.color)),
                  SliverToBoxAdapter(child: _Rail(works: newest.take(10).toList())),
                ],
                if (!filtering && popular.isNotEmpty) ...[
                  SliverToBoxAdapter(child: _RailHeader(title: 'الأكثر استماعًا', color: world.color)),
                  SliverToBoxAdapter(child: _Rail(works: popular.take(10).toList(), ranked: true, color: world.color)),
                ],
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 12, 10),
                    child: Row(children: [
                      Expanded(
                        child: Text(filtering ? 'النتائج (${arNum(shown.length)})' : 'كل المقاطع', style: AtheerType.h2()),
                      ),
                      _SortMenu(value: sort, color: world.color, onChanged: (s) => setState(() => sort = s)),
                      IconButton(
                        tooltip: _listView ? 'عرض شبكة' : 'عرض قائمة',
                        onPressed: () => setState(() => _listView = !_listView),
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Icon(_listView ? Icons.grid_view_rounded : Icons.view_agenda_outlined,
                              key: ValueKey(_listView), color: world.color),
                        ),
                      ),
                    ]),
                  ),
                ),
                if (shown.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(child: Text('لا توجد نتائج', style: AtheerType.bodyMedium())),
                    ),
                  )
                else if (_listView)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    sliver: SliverList.separated(
                      itemCount: shown.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) =>
                          _WorkRow(work: shown[i], color: world.color).animate(delay: (40 * (i < 8 ? i : 8)).ms).fadeIn(duration: 380.ms),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    sliver: SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        childAspectRatio: 0.86,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                      itemCount: shown.length,
                      itemBuilder: (_, i) => StoryCard(work: shown[i], width: double.infinity, height: double.infinity)
                          .animate(delay: (40 * (i < 8 ? i : 8)).ms)
                          .fadeIn(duration: 380.ms),
                    ),
                  ),
              ],
            ],
          ),
        ]),
      ),
    );
  }

  Widget _searchBar(World world) {
    const labels = {
      _Filter.all: 'الكل',
      _Filter.free: 'مجاني',
      _Filter.premium: 'للمشتركين',
      _Filter.short: 'قصيرة',
      _Filter.favorites: 'المفضلة',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AtheerSearchBar(
            controller: _query,
            hint: 'ابحث في ${world.name}',
            onChanged: (_) => setState(() {}),
            trailing: _query.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'مسح',
                    icon: Icon(Icons.close_rounded, color: AtheerColors.textSecondary),
                    onPressed: () => setState(_query.clear),
                  ),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            children: [
              for (final f in _Filter.values) ...[
                _Chip(
                  label: labels[f]!,
                  selected: filter == f,
                  color: world.color,
                  onTap: () => setState(() => filter = f),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}

/// الغلاف: صورة القسم تتمدد مع السحب وتتلاشى عند التمرير، والاسم والعبارة فوقها.
class _Cover extends StatelessWidget {
  final World world;
  const _Cover({required this.world});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final h = (MediaQuery.sizeOf(context).height * 0.48).clamp(320.0, 460.0);
    return SliverAppBar(
      expandedHeight: h,
      pinned: true,
      stretch: true,
      backgroundColor: Color.lerp(world.color2, Colors.black, 0.45),
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      leading: Padding(
        padding: const EdgeInsets.all(6),
        child: GlassIconButton(icon: Icons.arrow_back_rounded, tooltip: 'رجوع', size: 40, onTap: () => Navigator.of(context).maybePop()),
      ),
      flexibleSpace: LayoutBuilder(builder: (context, box) {
        final collapsed = box.maxHeight <= kToolbarHeight + top + 8;
        final t = ((box.maxHeight - kToolbarHeight - top) / (h - kToolbarHeight)).clamp(0.0, 1.0);
        return Stack(fit: StackFit.expand, children: [
          FlexibleSpaceBar(
            stretchModes: const [StretchMode.zoomBackground],
            background: Stack(fit: StackFit.expand, children: [
              Hero(tag: 'world-${world.id}', child: WorldArt(world: world)),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.op(0.45),
                      Colors.transparent,
                      world.color2.op(0.55),
                      Color.lerp(world.color2, Colors.black, 0.35)!,
                    ],
                    stops: const [0, 0.3, 0.72, 1],
                  ),
                ),
              ),
            ]),
          ),
          // الاسم والعبارة (يتلاشيان مع التمرير).
          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child: Opacity(
              opacity: t,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Container(height: 2, width: 36, color: world.color),
                const SizedBox(height: 10),
                Text(world.name,
                    style: MidadText.callig(size: 40).copyWith(shadows: [Shadow(color: Colors.black.op(0.55), blurRadius: 18)])),
                if (world.tagline.isNotEmpty)
                  Text('«${world.tagline}»',
                      style: AtheerType.quoteMedium(color: AtheerColors.softIvory.op(0.9)).copyWith(fontSize: 18, height: 1.6)),
              ]).animate().fadeIn(duration: 600.ms, delay: 250.ms).moveY(begin: 14, end: 0, curve: Curves.easeOutCubic),
            ),
          ),
          // العنوان المصغّر في الشريط بعد الطي.
          PositionedDirectional(
            top: top,
            start: 64,
            end: 64,
            height: kToolbarHeight,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: collapsed ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Center(child: Text(world.name, style: AtheerType.h3())),
              ),
            ),
          ),
        ]);
      }),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _Stat({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.op(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.op(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(text, style: AtheerType.label().copyWith(fontSize: 12.5)),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: AtheerPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AtheerMotion.normal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? color.op(0.9) : Colors.white.op(0.06),
            borderRadius: BorderRadius.circular(AtheerRadius.pill),
            border: Border.all(color: selected ? color : AtheerColors.hairline),
          ),
          child: Text(label,
              style: AtheerType.label(
                color: selected
                    ? (color.computeLuminance() > 0.45 ? AtheerColors.midnight : AtheerColors.softIvory)
                    : AtheerColors.textSecondary,
              ).copyWith(fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
        ),
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  final _Sort value;
  final Color color;
  final ValueChanged<_Sort> onChanged;
  const _SortMenu({required this.value, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const labels = {_Sort.order: 'الترتيب الأصلي', _Sort.newest: 'الأحدث', _Sort.popular: 'الأكثر استماعًا'};
    return PopupMenuButton<_Sort>(
      tooltip: 'الترتيب',
      initialValue: value,
      color: AtheerColors.surfaceHigh,
      onSelected: onChanged,
      icon: Icon(Icons.sort_rounded, color: value == _Sort.order ? AtheerColors.textSecondary : color),
      itemBuilder: (_) => [
        for (final s in _Sort.values) PopupMenuItem(value: s, child: Text(labels[s]!, style: AtheerType.label())),
      ],
    );
  }
}

class _RailHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _RailHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
      child: Row(children: [
        Container(width: 3, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Expanded(child: Semantics(header: true, child: Text(title, style: AtheerType.h2()))),
      ]),
    );
  }
}

/// شريط أفقي من البطاقات؛ في «الأكثر استماعًا» يظهر ترتيب كل قصة.
class _Rail extends StatelessWidget {
  final List<Work> works;
  final bool ranked;
  final Color? color;
  const _Rail({required this.works, this.ranked = false, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: works.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final card = StoryCard(work: works[i], width: 150, height: 190);
          if (!ranked) return card;
          return Stack(clipBehavior: Clip.none, children: [
            card,
            PositionedDirectional(
              bottom: 44,
              start: 10,
              child: Text(arNum(i + 1),
                  style: AtheerType.hero().copyWith(
                    fontSize: 34,
                    shadows: [Shadow(color: (color ?? Colors.black).op(0.9), blurRadius: 14)],
                  )),
            ),
          ]);
        },
      ),
    );
  }
}

/// صف في عرض القائمة: غلاف صغير، عنوان، مدة، مفضلة، تشغيل.
class _WorkRow extends StatelessWidget {
  final Work work;
  final Color color;
  const _WorkRow({required this.work, required this.color});

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (work.kind.isNotEmpty) work.kind,
      if (work.minutes > 0) '${arNum(work.minutes)} د',
      if (work.narrator.isNotEmpty) work.narrator,
    ].join(' · ');
    return GestureDetector(
      onTap: () => Navigator.of(context).push(fadeRoute(WorkScreen(work: work))),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.op(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.op(0.08)),
        ),
        child: Row(children: [
          SizedBox(width: 64, height: 64, child: CoverArt(art: work.art, url: work.cover, radius: BorderRadius.circular(14))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(work.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AtheerType.label().copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                if (work.premium) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.lock_rounded, size: 13, color: color),
                ],
              ]),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: AtheerType.bodySmall()),
              ],
            ]),
          ),
          HeartButton(workId: work.id, size: 34),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'استمع إلى ${work.title}',
            child: GestureDetector(
              onTap: () => listenTo(context, work),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                child: Icon(Icons.play_arrow_rounded, color: color.computeLuminance() > 0.45 ? Colors.black : Colors.white),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// القسم الفاضي: «قريبًا».
class _Soon extends StatelessWidget {
  final World world;
  const _Soon({required this.world});

  @override
  Widget build(BuildContext context) => const AtheerEmptyState(
        icon: Icons.auto_stories_outlined,
        title: 'قريبًا',
        message: 'حكايات هذا العالم في الطريق إليك',
      );
}
