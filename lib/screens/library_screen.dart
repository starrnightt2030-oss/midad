import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../data/repository.dart';
import '../design/atheer_design_system.dart';
import '../models.dart';
import '../state/downloads.dart';
import '../state/library.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/cover_art.dart';
import 'work_screen.dart';

enum _Shelf { resume, favs, downloads, history, completed, playlists, quotes }

extension on _Shelf {
  String get label => switch (this) {
        _Shelf.resume => 'أكمل الاستماع',
        _Shelf.favs => 'المفضلة',
        _Shelf.downloads => 'التنزيلات',
        _Shelf.history => 'السجل',
        _Shelf.completed => 'المكتملة',
        _Shelf.playlists => 'قوائمي',
        _Shelf.quotes => 'خواطري',
      };
  IconData get icon => switch (this) {
        _Shelf.resume => Icons.play_circle_outline_rounded,
        _Shelf.favs => Icons.favorite_border_rounded,
        _Shelf.downloads => Icons.download_done_rounded,
        _Shelf.history => Icons.history_rounded,
        _Shelf.completed => Icons.task_alt_rounded,
        _Shelf.playlists => Icons.queue_music_rounded,
        _Shelf.quotes => Icons.format_quote_rounded,
      };
}

enum _Sort { recent, title, length }

/// مكتبتي: كل ما يخص المستمع على هذا الجهاز، مع البحث والترتيب.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  _Shelf shelf = _Shelf.resume;
  _Sort sort = _Sort.recent;
  String query = '';
  String? openList;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Work> _works(Catalog cat, LibraryStore lib, DownloadStore dl) {
    final ids = switch (shelf) {
      _Shelf.resume => lib.recent.where((id) => !lib.isCompleted(id)).toList(),
      _Shelf.favs => lib.favorites.toList().reversed.toList(),
      _Shelf.downloads => dl.done.toList(),
      _Shelf.history => lib.history.map((e) => e.id).toList(),
      _Shelf.completed => (lib.completed.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).map((e) => e.key).toList(),
      _Shelf.playlists => openList == null ? <String>[] : (lib.playlists[openList] ?? const []),
      _Shelf.quotes => <String>[],
    };
    var list = ids.map(cat.workById).whereType<Work>().toList();
    final q = query.trim();
    if (q.isNotEmpty) list = list.where((w) => w.title.contains(q) || w.narrator.contains(q)).toList();
    switch (sort) {
      case _Sort.recent:
        break;
      case _Sort.title:
        list.sort((a, b) => a.title.compareTo(b.title));
      case _Sort.length:
        list.sort((a, b) => a.minutes.compareTo(b.minutes));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryStore>();
    final dl = context.watch<DownloadStore>();
    final cat = context.watch<ContentRepository>().catalog!;
    final works = _works(cat, lib, dl);
    final showSearch = shelf != _Shelf.quotes && !(shelf == _Shelf.playlists && openList == null);

    return CustomScrollView(slivers: [
      SliverSafeArea(
        bottom: false,
        sliver: SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AtheerSpacing.gutter, AtheerSpacing.xl, AtheerSpacing.gutter, AtheerSpacing.lg),
            child: Text('مكتبتي', style: AtheerType.h1()),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AtheerSpacing.gutter),
            itemCount: _Shelf.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: AtheerSpacing.sm),
            itemBuilder: (_, i) {
              final s = _Shelf.values[i];
              return _Chip(
                icon: s.icon,
                label: s.label,
                selected: s == shelf,
                onTap: () => setState(() {
                  shelf = s;
                  openList = null;
                }),
              );
            },
          ),
        ),
      ),
      if (showSearch)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AtheerSpacing.gutter, AtheerSpacing.lg, AtheerSpacing.gutter, 0),
            child: Row(children: [
              Expanded(
                child: AtheerSearchBar(
                  hint: 'ابحث في ${shelf.label}',
                  controller: _search,
                  onChanged: (v) => setState(() => query = v),
                ),
              ),
              const SizedBox(width: AtheerSpacing.sm),
              PopupMenuButton<_Sort>(
                tooltip: 'ترتيب',
                initialValue: sort,
                color: AtheerColors.surfaceHigh,
                onSelected: (v) => setState(() => sort = v),
                itemBuilder: (_) => [
                  PopupMenuItem(value: _Sort.recent, child: Text('الأحدث', style: AtheerType.label())),
                  PopupMenuItem(value: _Sort.title, child: Text('الاسم', style: AtheerType.label())),
                  PopupMenuItem(value: _Sort.length, child: Text('الأقصر أولًا', style: AtheerType.label())),
                ],
                child: const AtheerIconButton(icon: Icons.sort_rounded, tooltip: 'ترتيب', onPressed: null, style: AtheerIconButtonStyle.glass),
              ),
            ]),
          ),
        ),
      if (shelf == _Shelf.playlists && openList != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AtheerSpacing.md, AtheerSpacing.md, AtheerSpacing.gutter, 0),
            child: Row(children: [
              AtheerIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'كل القوائم',
                style: AtheerIconButtonStyle.plain,
                onPressed: () => setState(() => openList = null),
              ),
              Expanded(child: Text(openList!, style: AtheerType.h3())),
            ]),
          ),
        ),
      ..._body(context, lib, works),
      const SliverToBoxAdapter(child: SizedBox(height: AtheerSpacing.xxxl)),
    ]);
  }

  List<Widget> _body(BuildContext context, LibraryStore lib, List<Work> works) {
    if (shelf == _Shelf.quotes) return [_quotes(lib)];
    if (shelf == _Shelf.playlists && openList == null) return [_playlists(context, lib)];
    if (shelf == _Shelf.history && works.isNotEmpty && query.isEmpty) return [_history(context, lib, works)];
    if (works.isEmpty) return [SliverToBoxAdapter(child: _empty())];
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(AtheerSpacing.gutter, AtheerSpacing.xl, AtheerSpacing.gutter, 0),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: AtheerBreakpoints.columns(context),
            childAspectRatio: 0.58,
            crossAxisSpacing: AtheerSpacing.lg,
            mainAxisSpacing: AtheerSpacing.lg,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, i) => AtheerStoryCard(
              work: works[i],
              width: double.infinity,
              subtitle: lib.isCompleted(works[i].id) ? 'مكتملة' : null,
              onTap: () => Navigator.of(context).push(AtheerMotion.fadeThrough(WorkScreen(work: works[i]))),
            ),
            childCount: works.length,
          ),
        ),
      ),
    ];
  }

  Widget _empty() {
    if (query.isNotEmpty) {
      return const AtheerEmptyState(icon: Icons.search_off_rounded, title: 'لا نتائج', message: 'جرّب كلمة أخرى.');
    }
    return switch (shelf) {
      _Shelf.resume =>
        const AtheerEmptyState(icon: Icons.play_circle_outline_rounded, title: 'لا شيء لتكمله', message: 'ابدأ أي حكاية وستجدها هنا لتكمل من حيث توقفت.'),
      _Shelf.favs => const AtheerEmptyState(icon: Icons.favorite_border_rounded, title: 'لا مفضلات بعد', message: 'اضغط القلب على أي قصة لتجدها هنا.'),
      _Shelf.downloads => const AtheerEmptyState(icon: Icons.download_rounded, title: 'لا تنزيلات', message: 'حمّل القصص المتاحة للاستماع بدون إنترنت.'),
      _Shelf.history => const AtheerEmptyState(icon: Icons.history_rounded, title: 'السجل فارغ', message: 'ما تسمعه يظهر هنا.'),
      _Shelf.completed => const AtheerEmptyState(icon: Icons.task_alt_rounded, title: 'لم تكتمل قصة بعد', message: 'القصص التي تسمعها حتى النهاية تُحفظ هنا.'),
      _Shelf.playlists => const AtheerEmptyState(icon: Icons.queue_music_rounded, title: 'القائمة فارغة', message: 'أضف قصصًا من صفحة أي قصة.'),
      _Shelf.quotes => const SizedBox(),
    };
  }

  Widget _history(BuildContext context, LibraryStore lib, List<Work> works) {
    final at = {for (final e in lib.history) e.id: e.at};
    return SliverPadding(
      padding: const EdgeInsets.only(top: AtheerSpacing.md),
      sliver: SliverList.builder(
        itemCount: works.length + 1,
        itemBuilder: (context, i) {
          if (i == works.length) {
            return Center(
              child: TextButton(
                onPressed: lib.clearHistory,
                child: Text('مسح السجل', style: AtheerType.label(color: AtheerColors.textTertiary)),
              ),
            );
          }
          final w = works[i];
          return _Row(work: w, trailing: _ago(at[w.id]));
        },
      ),
    );
  }

  static String _ago(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return 'منذ ${arNum(diff.inMinutes < 1 ? 1 : diff.inMinutes)} د';
    if (diff.inHours < 24) return 'منذ ${arNum(diff.inHours)} س';
    if (diff.inDays == 1) return 'أمس';
    return 'منذ ${arNum(diff.inDays)} يوم';
  }

  Widget _playlists(BuildContext context, LibraryStore lib) {
    final names = lib.playlists.keys.toList();
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(AtheerSpacing.gutter, AtheerSpacing.lg, AtheerSpacing.gutter, 0),
      sliver: SliverList.list(children: [
        AtheerSecondaryButton(label: 'قائمة جديدة', icon: Icons.add_rounded, onPressed: () => createPlaylistDialog(context)),
        const SizedBox(height: AtheerSpacing.lg),
        if (names.isEmpty)
          const AtheerEmptyState(
            icon: Icons.queue_music_rounded,
            title: 'لا قوائم بعد',
            message: 'اصنع قائمة لقصص النوم، أو لرحلة طويلة، وأضف لها من صفحة أي قصة.',
          ),
        for (final n in names)
          Padding(
            padding: const EdgeInsets.only(bottom: AtheerSpacing.sm),
            child: AtheerGlassCard(
              blur: false,
              onTap: () => setState(() => openList = n),
              padding: const EdgeInsets.fromLTRB(AtheerSpacing.lg, AtheerSpacing.sm, AtheerSpacing.xs, AtheerSpacing.sm),
              child: Row(children: [
                Icon(Icons.queue_music_rounded, color: AtheerColors.accent),
                const SizedBox(width: AtheerSpacing.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(n, style: AtheerType.label()),
                    Text('${arNum(lib.playlists[n]!.length)} قصة', style: AtheerType.bodySmall()),
                  ]),
                ),
                AtheerIconButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'حذف القائمة',
                  style: AtheerIconButtonStyle.plain,
                  onPressed: () => lib.deletePlaylist(n),
                ),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _quotes(LibraryStore lib) {
    if (lib.quotes.isEmpty) {
      return const SliverToBoxAdapter(
        child: AtheerEmptyState(icon: Icons.format_quote_rounded, title: 'لا خواطر بعد', message: 'اضغط مطوّلًا على أي سطر أثناء القراءة لتصنع خاطرة.'),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(AtheerSpacing.gutter, AtheerSpacing.lg, AtheerSpacing.gutter, 0),
      sliver: SliverList.separated(
        itemCount: lib.quotes.length,
        separatorBuilder: (_, __) => const SizedBox(height: AtheerSpacing.md),
        itemBuilder: (_, i) {
          final q = lib.quotes[i];
          return AtheerGlassCard(
            blur: false,
            padding: const EdgeInsets.fromLTRB(AtheerSpacing.xl, AtheerSpacing.lg, AtheerSpacing.sm, AtheerSpacing.xs),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('«${q.text}»', style: AtheerType.quoteMedium()),
              Row(children: [
                Expanded(child: Text('— ${q.workTitle}', style: AtheerType.bodySmall(color: AtheerColors.accent))),
                AtheerIconButton(
                  icon: Icons.ios_share_rounded,
                  tooltip: 'مشاركة',
                  style: AtheerIconButtonStyle.plain,
                  size: 40,
                  onPressed: () => Share.share('«${q.text}» — ${q.workTitle} على تطبيق ${AppConfig.appName}'),
                ),
                AtheerIconButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'حذف',
                  style: AtheerIconButtonStyle.plain,
                  size: 40,
                  onPressed: () => lib.removeQuote(q),
                ),
              ]),
            ]),
          );
        },
      ),
    );
  }
}

/// صف قصة في القوائم (السجل).
class _Row extends StatelessWidget {
  final Work work;
  final String trailing;
  const _Row({required this.work, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: work.title,
      child: AtheerPressable(
        onTap: () => Navigator.of(context).push(AtheerMotion.fadeThrough(WorkScreen(work: work))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AtheerSpacing.gutter, vertical: AtheerSpacing.sm),
          child: Row(children: [
            SizedBox(width: 56, height: 56, child: CoverArt(art: work.art, url: work.cover, radius: BorderRadius.circular(AtheerRadius.sm))),
            const SizedBox(width: AtheerSpacing.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(work.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AtheerType.label()),
                if (work.minutes > 0) Text('${arNum(work.minutes)} دقيقة', style: AtheerType.bodySmall()),
              ]),
            ),
            Text(trailing, style: AtheerType.bodySmall()),
          ]),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: AtheerPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AtheerMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: AtheerSpacing.md + 2),
          decoration: BoxDecoration(
            gradient: selected ? AtheerGradients.accent : null,
            color: selected ? null : Colors.white.op(AtheerOpacity.glassFill),
            borderRadius: BorderRadius.circular(AtheerRadius.pill),
            border: Border.all(color: selected ? Colors.transparent : Colors.white.op(AtheerOpacity.hairline)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: AtheerIconSize.sm, color: selected ? AtheerColors.background : AtheerColors.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: AtheerType.label(color: selected ? AtheerColors.background : AtheerColors.textPrimary)),
          ]),
        ),
      ),
    );
  }
}

/// نافذة إنشاء قائمة جديدة. ترجع اسم القائمة لو اتعملت.
Future<String?> createPlaylistDialog(BuildContext context) async {
  final c = TextEditingController();
  final lib = context.read<LibraryStore>();
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AtheerColors.surfaceHigh,
      title: Text('قائمة جديدة', style: AtheerType.h3()),
      content: TextField(
        controller: c,
        autofocus: true,
        style: AtheerType.bodyLarge(),
        cursorColor: AtheerColors.accent,
        decoration: InputDecoration(hintText: 'مثلًا: قصص قبل النوم', hintStyle: AtheerType.bodyMedium(color: AtheerColors.textTertiary)),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: AtheerType.label(color: AtheerColors.textSecondary))),
        TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text('إنشاء', style: AtheerType.label(color: AtheerColors.accent))),
      ],
    ),
  );
  c.dispose();
  if (name == null || !lib.createPlaylist(name)) return null;
  return name.trim();
}

/// ورقة «أضف إلى قائمة» من صفحة القصة.
void showAddToPlaylist(BuildContext context, Work work) {
  AtheerBottomSheet.show(
    context,
    title: 'أضف إلى قائمة',
    builder: (sheet) => Consumer<LibraryStore>(
      builder: (context, lib, _) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final n in lib.playlists.keys)
          CheckboxListTile(
            value: lib.playlists[n]!.contains(work.id),
            onChanged: (_) => lib.togglePlaylistItem(n, work.id),
            activeColor: AtheerColors.accent,
            checkColor: AtheerColors.background,
            contentPadding: EdgeInsets.zero,
            title: Text(n, style: AtheerType.label()),
          ),
        const SizedBox(height: AtheerSpacing.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AtheerSecondaryButton(
            label: 'قائمة جديدة',
            icon: Icons.add_rounded,
            onPressed: () async {
              final n = await createPlaylistDialog(context);
              if (n != null) lib.togglePlaylistItem(n, work.id);
            },
          ),
        ),
      ]),
    ),
  );
}
