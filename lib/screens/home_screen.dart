import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../data/repository.dart';
import '../design/atheer_design_system.dart';
import '../models.dart';
import '../state/library.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/cover_art.dart';
import '../widgets/world_art.dart';
import 'actions.dart';
import 'search.dart';
import 'work_screen.dart';

/// معرّفات الأقسام كما في قاعدة البيانات (عوالم أثير الـ16).
class _W {
  static const bedtime = 'bedtime_stories';
  static const tranquility = 'tranquility';
  static const hope = 'hope_after_hardship';
  static const meaningful = 'meaningful_words';
  static const lessons = 'life_lessons';
  static const nostalgic = 'nostalgic_tales';
  static const spiritual = 'spiritual_nourishment';
  static const self = 'self_discovery';
  static const hearts = 'between_hearts';
  static const heartfelt = 'heartfelt_messages';
  static const wisdom = 'wisdom_minutes';
  static const turning = 'turning_point';
}

/// مزاج «كيف تشعر الآن؟» وما يناسبه من العوالم.
class _Mood {
  final String label;
  final IconData icon;
  final List<String> worlds;
  const _Mood(this.label, this.icon, this.worlds);
}

const _moods = [
  _Mood('أريد أن أهدأ', Icons.spa_rounded, [_W.tranquility, _W.spiritual]),
  _Mood('أريد أن أنام', Icons.nightlight_round, [_W.bedtime, _W.tranquility]),
  _Mood('أحتاج أملًا', Icons.wb_sunny_rounded, [_W.hope, _W.turning]),
  _Mood('أبحث عن معنى', Icons.auto_awesome_rounded, [_W.meaningful, _W.wisdom, _W.lessons]),
  _Mood('أشتاق للماضي', Icons.history_edu_rounded, [_W.nostalgic]),
  _Mood('قلبي مثقل', Icons.favorite_rounded, [_W.heartfelt, _W.hearts]),
  _Mood('أريد أن أفهم نفسي', Icons.self_improvement_rounded, [_W.self, _W.lessons]),
];

/// الرئيسية: واجهة تحريرية سينمائية تتغيّر مع اليوم، وتعرض البيانات الحقيقية فقط.
/// أي قسم بلا محتوى لا يظهر.
class HomeScreen extends StatelessWidget {
  final void Function(String worldId) onOpenWorld;
  final VoidCallback? onOpenWorlds;
  const HomeScreen({super.key, required this.onOpenWorld, this.onOpenWorlds});

  static String greeting(DateTime now) {
    final h = now.hour;
    if (h >= 5 && h < 12) return 'صباح النور';
    if (h >= 12 && h < 17) return 'نهارك هادئ';
    if (h >= 17 && h < 21) return 'مساء الهدوء';
    return 'ليلة هادئة';
  }

  static bool isNight(DateTime now) => now.hour >= 20 || now.hour < 5;

  static int _dayIndex(DateTime now) => DateTime(now.year, now.month, now.day).difference(DateTime(2024)).inDays;

  /// اختيار أثير اليوم: يتغيّر مرة كل يوم، وثابت طوال اليوم.
  static Work? pickOfTheDay(List<Work> works, DateTime now) {
    if (works.isEmpty) return null;
    return works[_dayIndex(now) % works.length];
  }

  @override
  Widget build(BuildContext context) {
    final cat = context.watch<ContentRepository>().catalog!;
    final lib = context.watch<LibraryStore>();
    final now = DateTime.now();
    final night = isNight(now);
    final works = cat.works;

    final featured = pickOfTheDay(works, now);

    final recent = lib.recent.map(cat.workById).whereType<Work>().toList();

    // رسالة اليوم: وصف عمل من «دقائق من الحكمة» أو «كلمات لها معنى».
    final wisdomPool = [...cat.worksOf(_W.wisdom), ...cat.worksOf(_W.meaningful)].where((w) => w.description.trim().isNotEmpty).toList();
    final message = wisdomPool.isEmpty ? null : wisdomPool[_dayIndex(now) % wisdomPool.length];

    final worlds = cat.worlds.where((w) => worldShown(cat, w)).toList();
    final moods = _moods.where((m) => m.worlds.any((id) => cat.worksOf(id).isNotEmpty)).toList();

    final latest = works.where((w) => w.added != null).toList()..sort((a, b) => b.added!.compareTo(a.added!));
    final popular = works.where((w) => w.plays > 0).toList()..sort((a, b) => b.plays.compareTo(a.plays));

    // مختارات لك: من عوالم ما يحبه ويسمعه، ولم يسمعه بعد.
    final likedWorlds = <String>{
      for (final id in [...lib.favorites, ...lib.recent]) ...?cat.workById(id)?.worldIds,
    };
    final picks = works.where((w) => !lib.recent.contains(w.id) && w.worldIds.any(likedWorlds.contains)).toList();

    final bedtime = <Work>{...cat.worksOf(_W.bedtime), ...cat.worksOf(_W.tranquility)}.toList();
    final journeys = works.where((w) => w.chapters.length > 1).toList();

    final sections = <String, List<Widget>>{
      'continue': [
        if (recent.isNotEmpty) ...[
          const SliverToBoxAdapter(child: AtheerSectionHeader(title: 'أكمل الاستماع', overline: 'من حيث توقفت')),
          SliverToBoxAdapter(child: _ContinueRow(works: recent)),
        ],
      ],
      'mood': [
        if (moods.isNotEmpty) ...[
          const SliverToBoxAdapter(child: AtheerSectionHeader(title: 'كيف تشعر الآن؟', subtitle: 'اختر شعورك ونأخذك لما يناسبه')),
          SliverToBoxAdapter(child: _MoodRow(moods: moods, onOpenWorld: onOpenWorld, catalog: cat)),
        ],
      ],
      'message': [
        if (message != null) ...[
          const SliverToBoxAdapter(child: AtheerSectionHeader(title: 'رسالة اليوم')),
          SliverToBoxAdapter(child: _DailyMessage(work: message)),
        ],
      ],
      'worlds': [
        if (worlds.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: AtheerSectionHeader(
              title: 'عوالم أثير',
              subtitle: '${arNum(worlds.length)} عالمًا من الحكايات',
              onAction: onOpenWorlds,
            ),
          ),
          SliverToBoxAdapter(child: _WorldsRow(worlds: worlds, catalog: cat, onOpenWorld: onOpenWorld)),
        ],
      ],
      'bedtime': _shelf('قبل أن تنام', bedtime, subtitle: 'حكايات هادئة لآخر اليوم', onAction: () => onOpenWorld(_W.bedtime)),
      'latest': _shelf('أحدث الإضافات', latest.take(12).toList()),
      'popular': _shelf('الأكثر استماعًا', popular.take(12).toList()),
      'picks': _shelf('مختارات لك', picks.take(12).toList(), subtitle: 'من العوالم التي تحبها'),
      'journeys': _shelf('رحلات صوتية', journeys.take(12).toList(), subtitle: 'حكايات على فصول'),
    };

    // ترتيب مرن: في الليل يتقدّم «قبل أن تنام».
    final order = night
        ? ['continue', 'bedtime', 'mood', 'message', 'worlds', 'latest', 'picks', 'popular', 'journeys']
        : ['continue', 'mood', 'worlds', 'message', 'latest', 'popular', 'picks', 'journeys', 'bedtime'];

    return CustomScrollView(slivers: [
      SliverSafeArea(bottom: false, sliver: SliverToBoxAdapter(child: _TopBar(onSearch: () => openSearch(context)))),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AtheerSpacing.gutter, AtheerSpacing.xxl, AtheerSpacing.gutter, 0),
          child: AtheerReveal(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(night ? Icons.nightlight_round : Icons.wb_twilight_rounded, size: AtheerIconSize.xs, color: AtheerColors.accent),
                const SizedBox(width: 6),
                Text(greeting(now), style: AtheerType.overline()),
              ]),
              const SizedBox(height: AtheerSpacing.sm),
              Text(night ? 'ماذا تودّ أن تسمع الليلة؟' : 'ماذا تودّ أن تسمع اليوم؟', style: AtheerType.h1()),
            ]),
          ),
        ),
      ),
      if (featured != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AtheerSpacing.gutter, AtheerSpacing.xl, AtheerSpacing.gutter, 0),
            child: AtheerReveal(index: 1, child: _Featured(work: featured, world: cat.worldOf(featured))),
          ),
        ),
      for (final key in order) ...sections[key]!,
      if (works.isEmpty)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: AtheerEmptyState(
            icon: Icons.nightlight_round,
            title: 'قريبًا تصل أول الحكايات',
            message: 'نُعدّ لك حكايات هادئة تُروى بصوت دافئ. عُد إلينا بعد قليل.',
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: AtheerSpacing.xxxl)),
    ]);
  }

  /// رف أفقي. لا يظهر لو فاضي.
  List<Widget> _shelf(String title, List<Work> works, {String? subtitle, VoidCallback? onAction}) {
    if (works.isEmpty) return const [];
    return [
      SliverToBoxAdapter(child: AtheerSectionHeader(title: title, subtitle: subtitle, onAction: onAction)),
      SliverToBoxAdapter(child: _Shelf(works: works)),
    ];
  }
}

/// الشريط العلوي: الشعار والاسم، وزر البحث.
class _TopBar extends StatelessWidget {
  final VoidCallback onSearch;
  const _TopBar({required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AtheerSpacing.gutter, AtheerSpacing.md, AtheerSpacing.gutter - 4, 0),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AtheerColors.accent.op(0.45))),
          child: ClipOval(child: Image.asset('assets/brand/logo.png', width: 32, height: 32, fit: BoxFit.cover)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(AppConfig.appName, style: AtheerType.h3())),
        AtheerIconButton(icon: Icons.search_rounded, tooltip: 'بحث', onPressed: onSearch, size: 42),
      ]),
    );
  }
}

/// اختيار أثير اليوم: مشهد Hero كبير.
class _Featured extends StatelessWidget {
  final Work work;
  final World? world;
  const _Featured({required this.work, this.world});

  @override
  Widget build(BuildContext context) {
    final lib = context.read<LibraryStore>();
    final meta = [
      if (world != null) world!.name,
      if (work.minutes > 0) '${arNum(work.minutes)} دقيقة',
      if (work.chapters.length > 1) '${arNum(work.chapters.length)} فصول',
    ].join('  ·  ');
    final fav = context.watch<LibraryStore>().isFav(work.id);
    final w = MediaQuery.sizeOf(context).width;
    return AtheerHeroBanner(
      height: (w * 1.0).clamp(320.0, 440.0),
      overline: 'اختيار أثير اليوم',
      title: work.title,
      subtitle: meta,
      tint: world?.color,
      onTap: () => Navigator.of(context).push(AtheerMotion.fadeThrough(WorkScreen(work: work))),
      background: Stack(fit: StackFit.expand, children: [
        CoverArt(art: work.art, url: work.cover),
        if (work.premium) const PositionedDirectional(top: 16, end: 16, child: AtheerBadge(icon: Icons.lock_rounded, label: 'اشتراك')),
      ]),
      actions: [
        AtheerPrimaryButton(
          label: 'استمع الآن',
          icon: Icons.play_arrow_rounded,
          height: 48,
          onPressed: () => listenTo(context, work, chapter: lib.lastChapter[work.id] ?? 0),
        ),
        AtheerIconButton(
          icon: fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          tooltip: fav ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
          selected: fav,
          onPressed: () => lib.toggleFav(work.id),
        ),
      ],
    );
  }
}

/// أكمل الاستماع: بطاقات أفقية فيها الفصل الحالي وتقدّم الحكاية.
class _ContinueRow extends StatelessWidget {
  final List<Work> works;
  const _ContinueRow({required this.works});

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryStore>();
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AtheerSpacing.gutter),
        itemCount: works.length,
        separatorBuilder: (_, __) => const SizedBox(width: AtheerSpacing.md),
        itemBuilder: (_, i) {
          final w = works[i];
          final ch = (lib.lastChapter[w.id] ?? 0).clamp(0, w.chapters.isEmpty ? 0 : w.chapters.length - 1);
          final total = w.chapters.length;
          final progress = total > 1 ? (ch + 1) / total : null;
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
  final double? progress;
  final VoidCallback onPlay;
  const _ContinueTile({required this.work, required this.subtitle, required this.progress, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'أكمل ${work.title}',
      excludeSemantics: true,
      child: AtheerGlassCard(
        blur: false,
        onTap: onPlay,
        padding: const EdgeInsets.all(10),
        radius: BorderRadius.circular(AtheerRadius.lg - 2),
        child: SizedBox(
          width: 252,
          child: Row(children: [
            SizedBox(width: 66, height: 66, child: CoverArt(art: work.art, url: work.cover, radius: BorderRadius.circular(AtheerRadius.sm + 2))),
            const SizedBox(width: AtheerSpacing.md),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(work.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AtheerType.label()),
                const SizedBox(height: 3),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AtheerType.bodySmall()),
                if (progress != null) ...[
                  const SizedBox(height: AtheerSpacing.sm),
                  AtheerProgressLine(value: progress!),
                ],
              ]),
            ),
            const SizedBox(width: 10),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: AtheerGradients.accent),
              child: Icon(Icons.play_arrow_rounded, size: 22, color: AtheerColors.background),
            ),
          ]),
        ),
      ),
    );
  }
}

/// «كيف تشعر الآن؟»: شرائح مزاج تفتح العالم الأنسب الذي فيه محتوى.
class _MoodRow extends StatelessWidget {
  final List<_Mood> moods;
  final Catalog catalog;
  final void Function(String) onOpenWorld;
  const _MoodRow({required this.moods, required this.catalog, required this.onOpenWorld});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AtheerSpacing.gutter),
        itemCount: moods.length,
        separatorBuilder: (_, __) => const SizedBox(width: AtheerSpacing.sm),
        itemBuilder: (_, i) {
          final m = moods[i];
          final target = m.worlds.firstWhere((id) => catalog.worksOf(id).isNotEmpty);
          return Semantics(
            button: true,
            label: m.label,
            excludeSemantics: true,
            child: AtheerPressable(
              onTap: () => onOpenWorld(target),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AtheerSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.white.op(AtheerOpacity.glassFill),
                  borderRadius: BorderRadius.circular(AtheerRadius.pill),
                  border: Border.all(color: Colors.white.op(AtheerOpacity.hairline)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(m.icon, size: AtheerIconSize.sm, color: AtheerColors.accent),
                  const SizedBox(width: AtheerSpacing.sm),
                  Text(m.label, style: AtheerType.label()),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// رسالة اليوم: حكمة بخط أميري من وصف عمل حقيقي، تفتح العمل عند الضغط.
class _DailyMessage extends StatelessWidget {
  final Work work;
  const _DailyMessage({required this.work});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AtheerSpacing.gutter),
      child: AtheerGlassCard(
        blur: false,
        onTap: () => Navigator.of(context).push(AtheerMotion.fadeThrough(WorkScreen(work: work))),
        padding: const EdgeInsets.fromLTRB(AtheerSpacing.xxl, AtheerSpacing.xl, AtheerSpacing.xxl, AtheerSpacing.lg),
        child: Column(children: [
          Icon(Icons.format_quote_rounded, color: AtheerColors.accent.op(0.7), size: AtheerIconSize.lg),
          const SizedBox(height: AtheerSpacing.xs),
          Text(work.description, textAlign: TextAlign.center, maxLines: 5, overflow: TextOverflow.ellipsis, style: AtheerType.quoteMedium()),
          const SizedBox(height: AtheerSpacing.md),
          Text(work.title, style: AtheerType.bodySmall(color: AtheerColors.accent)),
        ]),
      ),
    );
  }
}

/// عوالم أثير: صف أفقي من بطاقات الأقسام بصورها الأصلية.
class _WorldsRow extends StatelessWidget {
  final List<World> worlds;
  final Catalog catalog;
  final void Function(String) onOpenWorld;
  const _WorldsRow({required this.worlds, required this.catalog, required this.onOpenWorld});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AtheerSpacing.gutter),
        itemCount: worlds.length,
        separatorBuilder: (_, __) => const SizedBox(width: AtheerSpacing.md),
        itemBuilder: (_, i) {
          final w = worlds[i];
          final n = catalog.worksOf(w.id).length;
          return SizedBox(
            width: 150,
            child: AtheerCategoryCard(
              title: w.name,
              count: n,
              color: w.color,
              art: WorldArt(world: w, decodeWidth: 400),
              onTap: () => onOpenWorld(w.id),
            ),
          );
        },
      ),
    );
  }
}

/// رف أفقي من بطاقات القصص.
class _Shelf extends StatelessWidget {
  final List<Work> works;
  const _Shelf({required this.works});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 262,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AtheerSpacing.gutter),
        itemCount: works.length,
        separatorBuilder: (_, __) => const SizedBox(width: AtheerSpacing.md + 2),
        itemBuilder: (_, i) => AtheerStoryCard(
          work: works[i],
          onTap: () => Navigator.of(context).push(AtheerMotion.fadeThrough(WorkScreen(work: works[i]))),
        ),
      ),
    );
  }
}
