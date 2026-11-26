import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../data/repository.dart';
import '../models.dart';
import '../state/library.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/cover_art.dart';
import '../widgets/story_card.dart';
import 'actions.dart';
import 'search.dart';
import 'work_screen.dart';

/// الرئيسية: ترويسة هادئة، حكاية مختارة لليوم، أكمل الاستماع، ثم رف لكل عالم.
class HomeScreen extends StatelessWidget {
  final void Function(String worldId) onOpenWorld;
  const HomeScreen({super.key, required this.onOpenWorld});

  static const _gutter = 22.0;

  static String greeting(DateTime now) {
    final h = now.hour;
    if (h >= 5 && h < 12) return 'صباح النور';
    if (h >= 12 && h < 17) return 'نهارك هادئ';
    if (h >= 17 && h < 21) return 'مساء الهدوء';
    return 'ليلة هادئة';
  }

  static bool isNight(DateTime now) => now.hour >= 17 || now.hour < 5;

  /// حكاية اليوم: تتغيّر مرة كل يوم، وثابتة طوال اليوم.
  static Work? pickOfTheDay(List<Work> works, DateTime now) {
    if (works.isEmpty) return null;
    final day = DateTime(now.year, now.month, now.day).difference(DateTime(now.year)).inDays;
    return works[day % works.length];
  }

  @override
  Widget build(BuildContext context) {
    final cat = context.watch<ContentRepository>().catalog!;
    final lib = context.watch<LibraryStore>();
    final now = DateTime.now();
    final recent = lib.recent.map(cat.workById).whereType<Work>().toList();
    final featured = pickOfTheDay(cat.works, now);
    final night = isNight(now);

    return CustomScrollView(slivers: [
      SliverSafeArea(
        bottom: false,
        sliver: SliverToBoxAdapter(child: _TopBar(onSearch: () => openSearch(context))),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(_gutter, 26, _gutter, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(night ? Icons.nightlight_round : Icons.wb_twilight_rounded, size: 15, color: MidadColors.accent),
              const SizedBox(width: 6),
              Text(greeting(now), style: MidadText.ui(size: 13, weight: FontWeight.w600, color: MidadColors.accent)),
            ]),
            const SizedBox(height: 8),
            Text(night ? 'ماذا تودّ أن تسمع الليلة؟' : 'ماذا تودّ أن تسمع اليوم؟', style: MidadText.title(size: 26, height: 1.35)),
          ]),
        ),
      ),
      if (featured != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(_gutter, 22, _gutter, 0),
            child: _Featured(work: featured, night: night, world: cat.worldOf(featured)),
          ),
        ),
      if (recent.isNotEmpty) ...[
        const SliverToBoxAdapter(child: _Header(title: 'أكمل الاستماع')),
        SliverToBoxAdapter(child: _ContinueRow(works: recent)),
      ],
      for (final w in cat.worlds)
        if (cat.worksOf(w.id).isNotEmpty) ...[
          SliverToBoxAdapter(child: _Header(title: w.name, subtitle: w.tagline, onSeeAll: () => onOpenWorld(w.id))),
          SliverToBoxAdapter(child: _Shelf(works: cat.worksOf(w.id))),
        ],
      if (cat.works.isEmpty) const SliverFillRemaining(hasScrollBody: false, child: _Empty()),
      const SliverToBoxAdapter(child: SizedBox(height: 28)),
    ]);
  }
}

/// الشريط العلوي: الشعار والاسم، وزر البحث.
class _TopBar extends StatelessWidget {
  final VoidCallback onSearch;
  const _TopBar({required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(HomeScreen._gutter, 12, HomeScreen._gutter, 0),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: MidadColors.accent.op(0.45))),
          child: ClipOval(child: Image.asset('assets/brand/logo.png', width: 32, height: 32, fit: BoxFit.cover)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(AppConfig.appName, style: MidadText.title(size: 19))),
        Semantics(
          button: true,
          label: 'بحث',
          child: InkResponse(
            onTap: onSearch,
            radius: 24,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.op(0.06),
                border: Border.all(color: Colors.white.op(0.10)),
              ),
              child: const Icon(Icons.search_rounded, size: 21, color: Colors.white),
            ),
          ),
        ),
      ]),
    );
  }
}

/// عنوان رف: اسم العالم ووصفه القصير، و«عرض الكل».
class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onSeeAll;
  const _Header({required this.title, this.subtitle = '', this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(HomeScreen._gutter, 34, HomeScreen._gutter, 14),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: MidadText.title(size: 18)),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: MidadText.ui(size: 12.5, color: Colors.white.op(0.55))),
            ],
          ]),
        ),
        if (onSeeAll != null)
          InkWell(
            onTap: onSeeAll,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('عرض الكل', style: MidadText.ui(size: 12.5, weight: FontWeight.w600, color: MidadColors.accent)),
                const SizedBox(width: 2),
                Icon(Icons.chevron_left_rounded, size: 18, color: MidadColors.accent),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// الحكاية المختارة: غلاف كبير والعنوان والتشغيل في أسفله.
class _Featured extends StatelessWidget {
  final Work work;
  final World? world;
  final bool night;
  const _Featured({required this.work, required this.night, this.world});

  @override
  Widget build(BuildContext context) {
    final lib = context.read<LibraryStore>();
    final meta = [
      if (work.kind.isNotEmpty) work.kind,
      if (work.minutes > 0) '${arNum(work.minutes)} دقيقة',
      if (work.chapters.length > 1) '${arNum(work.chapters.length)} فصول',
    ].join('  ·  ');

    return GestureDetector(
      onTap: () => Navigator.of(context).push(fadeRoute(WorkScreen(work: work))),
      child: AspectRatio(
        aspectRatio: 1.18,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: Colors.black.op(0.40), blurRadius: 30, offset: const Offset(0, 14))],
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.op(0.08)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(fit: StackFit.expand, children: [
              CoverArt(art: work.art, url: work.cover),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, MidadColors.ink.op(0.55), MidadColors.ink.op(0.94)],
                    stops: const [0.30, 0.62, 1],
                  ),
                ),
              ),
              PositionedDirectional(
                top: 16,
                start: 16,
                child: _Eyebrow(text: night ? 'مختارة لك الليلة' : 'مختارة لك اليوم'),
              ),
              if (work.premium) const PositionedDirectional(top: 16, end: 16, child: _PremiumBadge()),
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (world != null) ...[
                    Text(world!.name, style: MidadText.ui(size: 12, weight: FontWeight.w600, color: MidadColors.accent)),
                    const SizedBox(height: 4),
                  ],
                  Text(work.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: MidadText.title(size: 25, height: 1.3)),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(meta, style: MidadText.ui(size: 12.5, color: Colors.white.op(0.70))),
                  ],
                  const SizedBox(height: 16),
                  Row(children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: AccentButton(
                          label: 'استمع الآن',
                          icon: Icons.play_arrow_rounded,
                          height: 46,
                          onTap: () => listenTo(context, work, chapter: lib.lastChapter[work.id] ?? 0),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Spacer(),
                    HeartButton(workId: work.id, size: 44),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  final String text;
  const _Eyebrow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: MidadColors.ink.op(0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MidadColors.accent.op(0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.auto_awesome_rounded, size: 12, color: MidadColors.accent),
        const SizedBox(width: 5),
        Text(text, style: MidadText.ui(size: 11, weight: FontWeight.w600, color: Colors.white.op(0.92))),
      ]),
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.black.op(0.50), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.lock_rounded, size: 11, color: MidadColors.accent),
        const SizedBox(width: 4),
        Text('اشتراك', style: MidadText.ui(size: 10, weight: FontWeight.w700)),
      ]),
    );
  }
}

/// أكمل الاستماع: بطاقات أفقية صغيرة فيها الفصل الحالي وتقدّم الحكاية.
class _ContinueRow extends StatelessWidget {
  final List<Work> works;
  const _ContinueRow({required this.works});

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryStore>();
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: HomeScreen._gutter),
        itemCount: works.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final w = works[i];
          final ch = (lib.lastChapter[w.id] ?? 0).clamp(0, w.chapters.isEmpty ? 0 : w.chapters.length - 1);
          final total = w.chapters.length;
          final progress = total == 0 ? 0.0 : (ch + 1) / total;
          final sub = total > 1 ? 'الفصل ${arNum(ch + 1)} من ${arNum(total)}' : (w.minutes > 0 ? '${arNum(w.minutes)} دقيقة' : w.kind);
          return _ContinueTile(work: w, subtitle: sub, progress: progress, onPlay: () => listenTo(context, w, chapter: ch));
        },
      ),
    );
  }
}

class _ContinueTile extends StatelessWidget {
  final Work work;
  final String subtitle;
  final double progress;
  final VoidCallback onPlay;
  const _ContinueTile({required this.work, required this.subtitle, required this.progress, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    final p = MidadColors.palette;
    return GestureDetector(
      onTap: onPlay,
      child: Container(
        width: 268,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: p.surface.op(0.72),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.op(0.07)),
        ),
        child: Row(children: [
          SizedBox(width: 64, height: 64, child: CoverArt(art: work.art, url: work.cover, radius: BorderRadius.circular(14))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(work.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: MidadText.ui(size: 14, weight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: MidadText.ui(size: 11.5, color: Colors.white.op(0.6))),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: Colors.white.op(0.10),
                  valueColor: AlwaysStoppedAnimation(p.accent),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 10),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: p.button),
            child: Icon(Icons.play_arrow_rounded, size: 22, color: p.bg),
          ),
        ]),
      ),
    );
  }
}

/// رف حكايات عالم واحد: غلاف طولي والعنوان والمدة تحته.
class _Shelf extends StatelessWidget {
  final List<Work> works;
  const _Shelf({required this.works});

  static const _w = 146.0, _cover = 194.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _cover + 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: HomeScreen._gutter),
        itemCount: works.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) => _PosterCard(work: works[i]),
      ),
    );
  }
}

class _PosterCard extends StatelessWidget {
  final Work work;
  const _PosterCard({required this.work});

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (work.minutes > 0) '${arNum(work.minutes)} دقيقة',
      if (work.chapters.length > 1) '${arNum(work.chapters.length)} فصول',
    ].join(' · ');
    return GestureDetector(
      onTap: () => Navigator.of(context).push(fadeRoute(WorkScreen(work: work))),
      child: SizedBox(
        width: _Shelf._w,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: _Shelf._cover,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.op(0.32), blurRadius: 16, offset: const Offset(0, 8))],
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.op(0.07)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(fit: StackFit.expand, children: [
                CoverArt(art: work.art, url: work.cover),
                PositionedDirectional(top: 8, end: 8, child: HeartButton(workId: work.id, size: 28)),
                if (work.premium) const PositionedDirectional(top: 9, start: 9, child: _PremiumBadge()),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Text(work.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: MidadText.ui(size: 14, weight: FontWeight.w600)),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: MidadText.ui(size: 11.5, color: Colors.white.op(0.55))),
          ],
        ]),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: MidadColors.accent.op(0.10),
            border: Border.all(color: MidadColors.accent.op(0.30)),
          ),
          child: Icon(Icons.nightlight_round, size: 32, color: MidadColors.accent),
        ),
        const SizedBox(height: 18),
        Text('قريبًا تصل أول الحكايات', textAlign: TextAlign.center, style: MidadText.title(size: 18)),
        const SizedBox(height: 6),
        Text('نُعدّ لك حكايات هادئة تُروى بصوت دافئ. عُد إلينا بعد قليل.',
            textAlign: TextAlign.center, style: MidadText.ui(size: 13, color: Colors.white.op(0.6), height: 1.6)),
      ]),
    );
  }
}
