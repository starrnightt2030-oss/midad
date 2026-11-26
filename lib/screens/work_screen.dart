import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/account.dart';
import '../state/downloads.dart';
import '../state/library.dart';
import '../state/player.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/cover_art.dart';
import '../widgets/mini_player.dart';
import 'account_screen.dart';
import 'actions.dart';

class WorkScreen extends StatelessWidget {
  final Work work;
  const WorkScreen({super.key, required this.work});

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryStore>();
    final player = context.watch<PlayerController>();
    final color = MidadColors.accent;
    final fav = lib.isFav(work.id);

    return Scaffold(
      backgroundColor: MidadColors.ink,
      body: Column(children: [
        Expanded(
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Stack(children: [
                Positioned.fill(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28, tileMode: TileMode.decal),
                    child: Opacity(opacity: 0.7, child: CoverArt(art: work.art, url: work.cover)),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [MidadColors.ink.op(0.2), MidadColors.ink.op(0.55), MidadColors.ink],
                        stops: const [0, 0.6, 1],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Row(children: [
                        GlassIconButton(icon: Icons.arrow_back_rounded, tooltip: 'رجوع', onTap: () => Navigator.pop(context)),
                        const Spacer(),
                        GlassIconButton(
                          icon: fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: fav ? color : null,
                          tooltip: fav ? 'إزالة من المفضلة' : 'أضف للمفضلة',
                          onTap: () => lib.toggleFav(work.id),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    Hero(
                      tag: 'cover-${work.id}',
                      child: Container(
                        width: 180,
                        height: 250,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), boxShadow: [
                          BoxShadow(color: Colors.black.op(0.6), blurRadius: 40, offset: const Offset(0, 20)),
                          BoxShadow(color: color.op(0.25), blurRadius: 50),
                        ]),
                        child: CoverArt(art: work.art, url: work.cover, radius: BorderRadius.circular(18)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(work.title, textAlign: TextAlign.center, style: MidadText.title(size: 28)),
                    const SizedBox(height: 4),
                    Text(
                      [work.kind, '${arNum(work.minutes)} دقيقة', if (work.narrator.isNotEmpty) 'بصوت ${work.narrator}'].join('  •  '),
                      style: MidadText.ui(size: 12, color: Colors.white70),
                    ),
                    const SizedBox(height: 14),
                  ]),
                ),
              ]),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(work.description, textAlign: TextAlign.center, style: MidadText.book(size: 17, color: Colors.white.op(0.88), height: 1.8)),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(
                      flex: 3,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: MidadColors.ink,
                          minimumSize: const Size(0, 54),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                        ),
                        onPressed: () => listenTo(context, work, chapter: lib.lastChapter[work.id] ?? 0),
                        icon: const Icon(Icons.headphones_rounded),
                        label: Text(lib.lastChapter.containsKey(work.id) ? 'أكمل الاستماع' : 'استمع',
                            style: MidadText.ui(weight: FontWeight.w700, color: MidadColors.ink)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _Round(icon: Icons.subtitles_outlined, label: 'قراءة حية', onTap: () => liveRead(context, work, chapter: lib.lastChapter[work.id] ?? 0)),
                    const SizedBox(width: 10),
                    _Round(icon: Icons.menu_book_rounded, label: 'اقرأ', onTap: () => readPage(context, work, chapter: lib.lastChapter[work.id] ?? 0)),
                  ]),
                  if (work.download) _DownloadRow(work: work),
                  const SizedBox(height: 26),
                  Text('الفصول', style: MidadText.ui(size: 16, weight: FontWeight.w700)),
                  const SizedBox(height: 6),
                ]),
              ),
            ),
            SliverList.builder(
              itemCount: work.chapters.length,
              itemBuilder: (context, i) {
                final ch = work.chapters[i];
                final active = player.work?.id == work.id && player.chapterIndex == i;
                return InkWell(
                  onTap: () => listenTo(context, work, chapter: i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active ? color : Colors.transparent,
                          border: Border.all(color: active ? color : Colors.white24),
                        ),
                        child: active
                            ? TalkingBars(color: MidadColors.ink, active: player.playing)
                            : Text(arNum(i + 1), style: MidadText.ui(color: color, weight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Text(ch.title, style: MidadText.ui(size: 15, weight: FontWeight.w600))),
                      if (ch.audio == null)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 6),
                          child: Text('نص', style: MidadText.ui(size: 11, color: Colors.white54)),
                        ),
                      Icon(Icons.play_arrow_rounded, color: Colors.white.op(0.7)),
                    ]),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ]),
        ),
        const SafeArea(top: false, child: MiniPlayer()),
      ]),
    );
  }
}

class _Round extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Round({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: onTap,
          child: Glass(radius: 27, opacity: 0.1, child: SizedBox(width: 54, height: 54, child: Icon(icon))),
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
      padding: const EdgeInsets.only(top: 14),
      child: Glass(
        radius: 18,
        opacity: 0.08,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Icon(done ? Icons.download_done_rounded : Icons.download_rounded, color: done ? MidadColors.accent : null),
          const SizedBox(width: 10),
          Expanded(
            child: progress != null
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('جارٍ التحميل ${arNum((progress * 100).round())}٪', style: MidadText.ui(size: 13)),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: progress, minHeight: 3, color: MidadColors.accent, backgroundColor: Colors.white12),
                  ])
                : Text(done ? 'محمّلة، تعمل بدون إنترنت' : 'حمّلها للاستماع بدون إنترنت', style: MidadText.ui(size: 13)),
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
              child: Text(done ? 'حذف' : 'تحميل'),
            ),
        ]),
      ),
    );
  }
}
