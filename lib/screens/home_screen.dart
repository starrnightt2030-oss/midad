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

/// الرئيسية: تحية، قصة مميّزة، أكمل الاستماع، ثم صف لكل قسم.
class HomeScreen extends StatelessWidget {
  final void Function(String worldId) onOpenWorld;
  const HomeScreen({super.key, required this.onOpenWorld});

  static String greeting(DateTime now) {
    final h = now.hour;
    if (h >= 5 && h < 12) return 'صباح النور';
    if (h >= 12 && h < 17) return 'نهارك هادئ';
    if (h >= 17 && h < 21) return 'مساء الهدوء';
    return 'ليلة هادئة';
  }

  @override
  Widget build(BuildContext context) {
    final cat = context.watch<ContentRepository>().catalog!;
    final lib = context.watch<LibraryStore>();
    final recent = lib.recent.map(cat.workById).whereType<Work>().toList();
    final featured = recent.isNotEmpty ? null : (cat.works.isEmpty ? null : cat.works.first);

    return CustomScrollView(slivers: [
      SliverSafeArea(
        bottom: false,
        sliver: SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/brand/logo.png', width: 34, height: 34)),
              const SizedBox(width: 10),
              Expanded(child: Text(AppConfig.appName, style: MidadText.title(size: 20))),
              _RoundIcon(icon: Icons.search_rounded, tooltip: 'بحث', onTap: () => openSearch(context)),
            ]),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(greeting(DateTime.now()), style: MidadText.title(size: 28)),
            const SizedBox(height: 6),
            Text('استرخِ، واترك الحكاية تأخذك إلى النوم', style: MidadText.ui(size: 14, color: Colors.white70)),
          ]),
        ),
      ),
      if (featured != null || recent.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: _Hero(work: recent.isNotEmpty ? recent.first : featured!, resume: recent.isNotEmpty),
          ),
        ),
      if (recent.length > 1) ...[
        const SliverToBoxAdapter(child: SectionHeader(title: 'أكمل الاستماع')),
        SliverToBoxAdapter(child: _Row(works: recent.skip(1).toList())),
      ],
      for (final w in cat.worlds)
        if (cat.worksOf(w.id).isNotEmpty) ...[
          SliverToBoxAdapter(child: SectionHeader(title: w.name, onSeeAll: () => onOpenWorld(w.id))),
          SliverToBoxAdapter(child: _Row(works: cat.worksOf(w.id))),
        ],
      if (cat.works.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Text('قريبًا تصل أول الحكايات', style: MidadText.ui(color: Colors.white60))),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ]);
  }
}

class _Row extends StatelessWidget {
  final List<Work> works;
  const _Row({required this.works});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: works.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) => StoryCard(work: works[i], width: 156, height: 180),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final Work work;
  final bool resume;
  const _Hero({required this.work, required this.resume});

  @override
  Widget build(BuildContext context) {
    final lib = context.read<LibraryStore>();
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: MidadColors.glow.op(0.35), blurRadius: 30, offset: const Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(fit: StackFit.expand, children: [
          CoverArt(art: work.art, url: work.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.centerEnd,
                end: AlignmentDirectional.centerStart,
                colors: [Colors.transparent, MidadColors.ink.op(0.85)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: MidadColors.accent.op(0.25), borderRadius: BorderRadius.circular(20)),
                child: Text(resume ? 'أكمل من حيث توقفت' : 'مختارة لك الليلة',
                    style: MidadText.ui(size: 11, weight: FontWeight.w600, color: MidadColors.accent)),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 210,
                child: Text(work.title, maxLines: 2, style: MidadText.title(size: 22, height: 1.3)),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 210,
                child: Text(work.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: MidadText.ui(size: 12, color: Colors.white70)),
              ),
              const Spacer(),
              Row(children: [
                AccentButton(
                  label: resume ? 'أكمل' : 'استمع الآن',
                  icon: Icons.play_arrow_rounded,
                  height: 42,
                  onTap: () => listenTo(context, work, chapter: lib.lastChapter[work.id] ?? 0),
                ),
                const SizedBox(width: 10),
                if (work.minutes > 0) Text('${arNum(work.minutes)} دقيقة', style: MidadText.ui(size: 12, color: Colors.white70)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _RoundIcon({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(shape: BoxShape.circle, color: MidadColors.surfaceHigh.op(0.8), border: Border.all(color: Colors.white.op(0.08))),
          child: Icon(icon, size: 22),
        ),
      ),
    );
  }
}
