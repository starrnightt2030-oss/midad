import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../data/repository.dart';
import '../design/atheer_design_system.dart';
import '../models.dart';
import '../state/account.dart';
import '../state/downloads.dart';
import '../state/library.dart';
import '../state/player.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/cover_art.dart';
import 'account_screen.dart';
import 'actions.dart';

/// تفاصيل القصة بأسلوب أغلفة الكتب والمجلات الفاخرة:
/// غلاف كبير فوق خلفية مضبّبة من نفس الغلاف، عنوان تحريري، زر تشغيل واضح،
/// ثم الوصف بخط أميري، والفصول، والمزيد من نفس العالم.
class WorkScreen extends StatelessWidget {
  final Work work;
  const WorkScreen({super.key, required this.work});

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryStore>();
    final player = context.watch<PlayerController>();
    final cat = context.watch<ContentRepository>().catalog;
    final world = cat?.worldOf(work);
    final tint = world?.color ?? AtheerColors.accent;
    final fav = lib.isFav(work.id);
    final resume = lib.lastChapter.containsKey(work.id);
    final chapter = lib.lastChapter[work.id] ?? 0;
    final more = cat == null ? <Work>[] : cat.worksOf(work.worldId).where((w) => w.id != work.id).take(10).toList();
    final size = MediaQuery.sizeOf(context);
    final coverW = (size.width * 0.52).clamp(160.0, 260.0);

    final meta = <(IconData, String)>[
      if (work.kind.isNotEmpty) (Icons.auto_stories_outlined, work.kind),
      if (work.minutes > 0) (Icons.schedule_rounded, '${arNum(work.minutes)} دقيقة'),
      if (work.chapters.length > 1) (Icons.format_list_numbered_rtl_rounded, '${arNum(work.chapters.length)} فصول'),
      if (work.narrator.isNotEmpty) (Icons.mic_none_rounded, 'بصوت ${work.narrator}'),
    ];

    return Scaffold(
      backgroundColor: AtheerColors.background,
      body: Column(children: [
        Expanded(
          child: CustomScrollView(slivers: [
            // الغلاف: خلفية مضبّبة + غلاف كتاب بظل وعمق.
            SliverToBoxAdapter(
              child: Stack(children: [
                Positioned.fill(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 36, sigmaY: 36, tileMode: TileMode.decal),
                    child: Opacity(opacity: 0.75, child: CoverArt(art: work.art, url: work.cover)),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AtheerColors.background.op(0.15), tint.darken(0.2).op(0.25), AtheerColors.background],
                        stops: const [0, 0.55, 1],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AtheerSpacing.md, AtheerSpacing.sm, AtheerSpacing.md, 0),
                      child: Row(children: [
                        AtheerIconButton(icon: Icons.arrow_back_rounded, tooltip: 'رجوع', onPressed: () => Navigator.pop(context)),
                        const Spacer(),
                        AtheerIconButton(
                          icon: Icons.ios_share_rounded,
                          tooltip: 'مشاركة',
                          onPressed: () => Share.share('استمع إلى «${work.title}» على تطبيق ${AppConfig.appName}'),
                        ),
                        AtheerIconButton(
                          icon: fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          tooltip: fav ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
                          selected: fav,
                          onPressed: () => lib.toggleFav(work.id),
                        ),
                      ]),
                    ),
                    const SizedBox(height: AtheerSpacing.lg),
                    Hero(tag: 'cover-${work.id}', child: _BookCover(work: work, width: coverW, tint: tint)),
                    const SizedBox(height: AtheerSpacing.xxl),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AtheerSpacing.gutter),
                      child: Column(children: [
                        if (world != null) ...[
                          Text(world.name, style: AtheerType.overline()),
                          const SizedBox(height: AtheerSpacing.sm),
                        ],
                        Text(work.title, textAlign: TextAlign.center, style: AtheerType.h1()),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: AtheerSpacing.md),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: AtheerSpacing.lg,
                            runSpacing: AtheerSpacing.xs,
                            children: [
                              for (final m in meta)
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(m.$1, size: AtheerIconSize.xs, color: AtheerColors.textTertiary),
                                  const SizedBox(width: 4),
                                  Text(m.$2, style: AtheerType.bodySmall(color: AtheerColors.textSecondary)),
                                ]),
                            ],
                          ),
                        ],
                        if (work.premium) ...[
                          const SizedBox(height: AtheerSpacing.md),
                          const AtheerBadge(icon: Icons.lock_rounded, label: 'ضمن الاشتراك'),
                        ],
                      ]),
                    ),
                    const SizedBox(height: AtheerSpacing.xl),
                  ]),
                ),
              ]),
            ),
            // التشغيل.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AtheerSpacing.gutter),
                child: Row(children: [
                  Expanded(
                    child: AtheerPrimaryButton(
                      label: resume ? 'أكمل الاستماع' : 'استمع الآن',
                      icon: Icons.play_arrow_rounded,
                      expanded: true,
                      onPressed: () => listenTo(context, work, chapter: chapter),
                    ),
                  ),
                  const SizedBox(width: AtheerSpacing.sm),
                  AtheerIconButton(
                    icon: Icons.subtitles_outlined,
                    tooltip: 'قراءة حية',
                    size: 52,
                    onPressed: () => liveRead(context, work, chapter: chapter),
                  ),
                  AtheerIconButton(
                    icon: Icons.menu_book_rounded,
                    tooltip: 'اقرأ',
                    size: 52,
                    onPressed: () => readPage(context, work, chapter: chapter),
                  ),
                ]),
              ),
            ),
            if (work.download) SliverToBoxAdapter(child: _DownloadRow(work: work)),
            if (work.description.trim().isNotEmpty) ...[
              const SliverToBoxAdapter(child: AtheerSectionHeader(title: 'عن الحكاية')),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AtheerSpacing.gutter),
                  child: Text(work.description, style: AtheerType.quoteMedium(color: AtheerColors.softIvory.op(0.9))),
                ),
              ),
            ],
            if (work.chapters.length > 1) ...[
              SliverToBoxAdapter(child: AtheerSectionHeader(title: 'الفصول', subtitle: '${arNum(work.chapters.length)} فصول')),
              SliverList.builder(
                itemCount: work.chapters.length,
                itemBuilder: (context, i) => _ChapterTile(
                  index: i,
                  chapter: work.chapters[i],
                  active: player.work?.id == work.id && player.chapterIndex == i,
                  playing: player.playing,
                  last: resume && chapter == i,
                  onTap: () => listenTo(context, work, chapter: i),
                ),
              ),
            ],
            if (more.isNotEmpty) ...[
              SliverToBoxAdapter(child: AtheerSectionHeader(title: 'من نفس العالم', subtitle: world?.name)),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 262,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AtheerSpacing.gutter),
                    itemCount: more.length,
                    separatorBuilder: (_, __) => const SizedBox(width: AtheerSpacing.md + 2),
                    itemBuilder: (_, i) => AtheerStoryCard(
                      work: more[i],
                      onTap: () => Navigator.of(context).pushReplacement(AtheerMotion.fadeThrough(WorkScreen(work: more[i]))),
                    ),
                  ),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: AtheerSpacing.xxxl)),
          ]),
        ),
        const SafeArea(top: false, child: AtheerMiniPlayer()),
      ]),
    );
  }
}

/// غلاف كتاب: زوايا ناعمة، كعب كتاب خفيف على اليمين، وظل وتوهّج بلون العالم.
class _BookCover extends StatelessWidget {
  final Work work;
  final double width;
  final Color tint;
  const _BookCover({required this.work, required this.width, required this.tint});

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(AtheerRadius.md);
    return Container(
      width: width,
      height: width * 4 / 3,
      decoration: BoxDecoration(borderRadius: r, boxShadow: [
        BoxShadow(color: Colors.black.op(0.55), blurRadius: 40, offset: const Offset(0, 22)),
        BoxShadow(color: tint.op(0.22), blurRadius: 60),
      ]),
      child: ClipRRect(
        borderRadius: r,
        child: Stack(fit: StackFit.expand, children: [
          CoverArt(art: work.art, url: work.cover),
          // كعب الكتاب.
          PositionedDirectional(
            top: 0,
            bottom: 0,
            start: 0,
            width: 14,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  colors: [Colors.black.op(0.35), Colors.white.op(0.08), Colors.transparent],
                ),
              ),
            ),
          ),
          // لمعة علوية.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [Colors.white.op(0.10), Colors.transparent],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  final int index;
  final ChapterRef chapter;
  final bool active;
  final bool playing;
  final bool last;
  final VoidCallback onTap;
  const _ChapterTile({
    required this.index,
    required this.chapter,
    required this.active,
    required this.playing,
    required this.last,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AtheerColors.accent;
    return Semantics(
      button: true,
      label: 'الفصل ${index + 1}: ${chapter.title}',
      excludeSemantics: true,
      child: AtheerPressable(
        onTap: onTap,
        scale: 0.99,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AtheerSpacing.gutter, vertical: AtheerSpacing.sm),
          child: Row(children: [
            AnimatedContainer(
              duration: AtheerMotion.normal,
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: active ? AtheerGradients.accent : null,
                border: active ? null : Border.all(color: Colors.white.op(AtheerOpacity.glassBorder)),
              ),
              child: active
                  ? TalkingBars(color: AtheerColors.background, active: playing)
                  : Text(arNum(index + 1), style: AtheerType.label(color: accent)),
            ),
            const SizedBox(width: AtheerSpacing.md + 2),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(chapter.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AtheerType.label()),
                if (last && !active) ...[
                  const SizedBox(height: 2),
                  Text('توقفت هنا', style: AtheerType.labelSmall(color: accent)),
                ],
              ]),
            ),
            if (chapter.audio == null)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: AtheerSpacing.sm),
                child: Text('نص', style: AtheerType.bodySmall()),
              ),
            Icon(Icons.play_arrow_rounded, color: AtheerColors.textSecondary),
          ]),
        ),
      ),
    );
  }
}

/// تحميل القصة للاستماع بدون إنترنت (لو سمحت اللوحة بذلك).
class _DownloadRow extends StatelessWidget {
  final Work work;
  const _DownloadRow({required this.work});

  @override
  Widget build(BuildContext context) {
    final dl = context.watch<DownloadStore>();
    final acc = context.watch<AccountStore>();
    final progress = dl.active[work.id];
    final done = dl.isDone(work.id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AtheerSpacing.gutter, AtheerSpacing.md, AtheerSpacing.gutter, 0),
      child: AtheerGlassCard(
        blur: false,
        radius: BorderRadius.circular(AtheerRadius.md),
        padding: const EdgeInsets.symmetric(horizontal: AtheerSpacing.lg, vertical: AtheerSpacing.sm + 2),
        child: Row(children: [
          Icon(done ? Icons.download_done_rounded : Icons.download_rounded, color: done ? AtheerColors.accent : AtheerColors.textSecondary),
          const SizedBox(width: AtheerSpacing.md),
          Expanded(
            child: progress != null
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('جارٍ التحميل ${arNum((progress * 100).round())}٪', style: AtheerType.label()),
                    const SizedBox(height: 6),
                    AtheerProgressLine(value: progress),
                  ])
                : Text(done ? 'محمّلة، تعمل بدون إنترنت' : 'حمّلها للاستماع بدون إنترنت', style: AtheerType.bodyMedium()),
          ),
          if (progress == null)
            TextButton(
              onPressed: () async {
                if (done) return dl.remove(work);
                if (work.premium && !acc.premium) return showPaywall(context);
                final messenger = ScaffoldMessenger.of(context);
                final err = await dl.download(work);
                if (err != null) messenger.showSnackBar(SnackBar(content: Text(err, style: MidadText.ui())));
              },
              child: Text(done ? 'حذف' : 'تحميل', style: AtheerType.label(color: AtheerColors.accent)),
            ),
        ]),
      ),
    );
  }
}
