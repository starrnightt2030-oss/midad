import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../data/repository.dart';
import '../models.dart';
import '../state/library.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/story_card.dart';

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
      child: SafeArea(
        bottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Text('مكتبتي', style: MidadText.title(size: 26)),
          ),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(gradient: MidadColors.palette.button, borderRadius: BorderRadius.circular(24)),
            labelColor: MidadColors.ink,
            unselectedLabelColor: Colors.white70,
            labelStyle: MidadText.ui(weight: FontWeight.w700),
            splashBorderRadius: BorderRadius.circular(24),
            labelPadding: const EdgeInsets.symmetric(horizontal: 18),
            tabs: const [Tab(text: 'أكمل', height: 40), Tab(text: 'المفضلة', height: 40), Tab(text: 'خواطري', height: 40)],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: TabBarView(children: [
              _works(context, recent, 'ابدأ أي حكاية وستجدها هنا'),
              _works(context, favs, 'اضغط القلب على أي قصة لتُحفظ هنا'),
              _quotes(context, lib),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _empty(String t) => Center(child: Text(t, style: MidadText.ui(color: Colors.white60)));

  Widget _works(BuildContext context, List<Work> list, String empty) {
    if (list.isEmpty) return _empty(empty);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.86, crossAxisSpacing: 14, mainAxisSpacing: 14),
      itemCount: list.length,
      itemBuilder: (_, i) => StoryCard(work: list[i], width: double.infinity, height: double.infinity),
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
