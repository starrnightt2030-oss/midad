import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repository.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/story_card.dart';

/// يفتح البحث في عناوين القصص وأوصافها والأقسام.
void openSearch(BuildContext context) {
  final cat = context.read<ContentRepository>().catalog;
  if (cat == null) return;
  showSearch(context: context, delegate: _StorySearch(cat));
}

class _StorySearch extends SearchDelegate<void> {
  final Catalog cat;
  _StorySearch(this.cat) : super(searchFieldLabel: 'ابحث عن قصة أو قسم');

  @override
  ThemeData appBarTheme(BuildContext context) {
    final t = Theme.of(context);
    return t.copyWith(
      appBarTheme: AppBarTheme(backgroundColor: MidadColors.ink, elevation: 0),
      scaffoldBackgroundColor: MidadColors.ink,
      inputDecorationTheme: InputDecorationTheme(border: InputBorder.none, hintStyle: MidadText.ui(color: Colors.white54)),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) =>
      [if (query.isNotEmpty) IconButton(tooltip: 'مسح', icon: const Icon(Icons.close_rounded), onPressed: () => query = '')];

  @override
  Widget? buildLeading(BuildContext context) =>
      IconButton(tooltip: 'رجوع', icon: const Icon(Icons.arrow_back_rounded), onPressed: () => close(context, null));

  List<Work> _match() {
    final q = query.trim();
    if (q.isEmpty) return cat.works;
    return cat.works.where((w) {
      final world = cat.worldOf(w)?.name ?? '';
      return w.title.contains(q) || w.description.contains(q) || world.contains(q) || w.kind.contains(q);
    }).toList();
  }

  Widget _grid(BuildContext context) {
    final list = _match();
    if (list.isEmpty) {
      return Center(child: Text('لا توجد نتائج', style: MidadText.ui(color: Colors.white60)));
    }
    return Container(
      color: MidadColors.ink,
      child: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.86, crossAxisSpacing: 14, mainAxisSpacing: 14),
        itemCount: list.length,
        itemBuilder: (_, i) => StoryCard(work: list[i], width: double.infinity, height: double.infinity),
      ),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _grid(context);

  @override
  Widget buildSuggestions(BuildContext context) => _grid(context);
}
