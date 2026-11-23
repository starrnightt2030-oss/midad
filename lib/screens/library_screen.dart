import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../data/repository.dart';
import '../models.dart';
import '../state/library.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/cover_art.dart';
import '../widgets/mini_player.dart';
import 'work_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryStore>();
    final cat = context.watch<ContentRepository>().catalog!;
    final recent = lib.recent.map(cat.workById).whereType<Work>().toList();
    final favs = lib.favorites.map(cat.workById).whereType<Work>().toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: MidadColors.ink,
        appBar: AppBar(
          backgroundColor: MidadColors.ink,
          title: Text('مكتبتي', style: MidadText.title(size: 22)),
          bottom: TabBar(
            indicatorColor: MidadColors.saffron,
            labelColor: MidadColors.saffron,
            unselectedLabelColor: Colors.white70,
            labelStyle: MidadText.ui(weight: FontWeight.w700),
            tabs: const [Tab(text: 'أكمل'), Tab(text: 'المفضلة'), Tab(text: 'خواطري')],
          ),
        ),
        body: Column(children: [
          Expanded(
            child: TabBarView(children: [
              _works(context, recent, 'ابدأ أي حكاية وستجدها هنا'),
              _works(context, favs, 'اضغط القلب على أي عمل ليُحفظ هنا'),
              _quotes(context, lib),
            ]),
          ),
          const SafeArea(top: false, child: MiniPlayer()),
        ]),
      ),
    );
  }

  Widget _empty(String t) => Center(child: Text(t, style: MidadText.ui(color: Colors.white60)));

  Widget _works(BuildContext context, List<Work> list, String empty) {
    if (list.isEmpty) return _empty(empty);
    return GridView.builder(
      padding: const EdgeInsets.all(18),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.56, crossAxisSpacing: 14, mainAxisSpacing: 16),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final w = list[i];
        return GestureDetector(
          onTap: () => Navigator.of(context).push(fadeRoute(WorkScreen(work: w))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AspectRatio(aspectRatio: 0.75, child: CoverArt(art: w.art, url: w.cover, radius: BorderRadius.circular(14))),
            const SizedBox(height: 8),
            Text(w.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: MidadText.ui(size: 12, weight: FontWeight.w700)),
          ]),
        );
      },
    );
  }

  Widget _quotes(BuildContext context, LibraryStore lib) {
    if (lib.quotes.isEmpty) return _empty('اضغط مطوّلًا على أي سطر أثناء القراءة لتصنع خاطرة');
    return ListView.separated(
      padding: const EdgeInsets.all(18),
      itemCount: lib.quotes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final q = lib.quotes[i];
        return Glass(
          radius: 20,
          opacity: 0.06,
          padding: const EdgeInsets.fromLTRB(18, 16, 8, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('«${q.text}»', style: MidadText.book(size: 18, color: Colors.white, height: 1.8)),
            Row(children: [
              Expanded(child: Text('— ${q.workTitle}', style: MidadText.ui(size: 12, color: MidadColors.saffron))),
              IconButton(
                tooltip: 'مشاركة',
                onPressed: () => Share.share('«${q.text}» — ${q.workTitle} على تطبيق ${AppConfig.appName}'),
                icon: const Icon(Icons.ios_share_rounded, size: 20),
              ),
              IconButton(tooltip: 'حذف', onPressed: () => lib.removeQuote(q), icon: const Icon(Icons.delete_outline_rounded, size: 20)),
            ]),
          ]),
        );
      },
    );
  }
}
