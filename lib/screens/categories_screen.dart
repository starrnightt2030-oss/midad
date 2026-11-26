import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repository.dart';
import '../theme.dart';
import '../widgets/story_card.dart';
import 'search.dart';

/// الأقسام: شرائح للأقسام فوق، وشبكة بطاقات تحتها.
class CategoriesScreen extends StatelessWidget {
  final String? worldId;
  final ValueChanged<String?> onSelect;
  const CategoriesScreen({super.key, required this.worldId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final cat = context.watch<ContentRepository>().catalog!;
    final selected = cat.worlds.any((w) => w.id == worldId) ? worldId : null;
    final works = selected == null ? cat.works : cat.worksOf(selected);
    final world = selected == null ? null : cat.worlds.firstWhere((w) => w.id == selected);

    return SafeArea(
      bottom: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(children: [
            Expanded(child: Text('الأقسام', style: MidadText.title(size: 26))),
            IconButton(
              tooltip: 'بحث',
              onPressed: () => openSearch(context),
              icon: const Icon(Icons.search_rounded),
            ),
          ]),
        ),
        SizedBox(
          height: 62,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            children: [
              ChoiceChipPill(label: 'الكل', selected: selected == null, onTap: () => onSelect(null)),
              for (final w in cat.worlds) ...[
                const SizedBox(width: 8),
                ChoiceChipPill(label: w.short, selected: selected == w.id, onTap: () => onSelect(w.id)),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: Text(world?.tagline.isNotEmpty == true ? world!.tagline : 'كل الحكايات', style: MidadText.ui(size: 13, color: Colors.white60)),
        ),
        Expanded(
          child: works.isEmpty
              ? Center(child: Text('لا توجد قصص في هذا القسم بعد', style: MidadText.ui(color: Colors.white60)))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, childAspectRatio: 0.86, crossAxisSpacing: 14, mainAxisSpacing: 14),
                  itemCount: works.length,
                  itemBuilder: (_, i) => StoryCard(work: works[i], width: double.infinity, height: double.infinity),
                ),
        ),
      ]),
    );
  }
}
