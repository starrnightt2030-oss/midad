import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import 'home.dart';
import 'work_editor.dart';

/// القصص: قائمة مع فلترة بالقسم، ومفاتيح سريعة للنشر والاشتراك والتحميل.
class WorksPage extends StatefulWidget {
  const WorksPage({super.key});

  @override
  State<WorksPage> createState() => _WorksPageState();
}

class _WorksPageState extends State<WorksPage> {
  List<Map<String, dynamic>> works = [];
  List<Map<String, dynamic>> worlds = [];
  String? filter;
  String query = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final w = await db.from('worlds').select('id,name').order('sort_order');
    final s = await db.from('works').select('*, chapters(id, audio, audio_path)').order('sort_order').order('created_at');
    if (!mounted) return;
    setState(() {
      worlds = List<Map<String, dynamic>>.from(w);
      works = List<Map<String, dynamic>>.from(s);
      loading = false;
    });
  }

  Future<void> _toggle(Map<String, dynamic> w, String field, bool v) async {
    setState(() => w[field] = v);
    try {
      await db.from('works').update({field: v}).eq('id', w['id']);
    } catch (e) {
      if (mounted) toast(context, 'تعذّر الحفظ: $e');
      _load();
    }
  }

  Future<void> _open([Map<String, dynamic>? w]) async {
    if (worlds.isEmpty) return toast(context, 'أضف قسمًا أولًا من صفحة الأقسام');
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkEditor(workId: w?['id'] as String?, worlds: worlds)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final names = {for (final w in worlds) w['id']: w['name']};
    final list = works.where((w) {
      if (filter != null && w['world_id'] != filter) return false;
      if (query.isNotEmpty && !(w['title'] as String).contains(query)) return false;
      return true;
    }).toList();

    return Column(children: [
      PageHeader(
        title: 'القصص',
        subtitle: '${works.length} قصة • ${works.where((w) => w['published'] == true).length} منشورة',
        action: FilledButton.icon(onPressed: () => _open(), icon: const Icon(Icons.add_rounded), label: const Text('قصة جديدة')),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 260,
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'بحث بالعنوان', isDense: true),
              onChanged: (v) => setState(() => query = v.trim()),
            ),
          ),
          DropdownButton<String?>(
            value: filter,
            hint: const Text('كل الأقسام'),
            items: [
              const DropdownMenuItem(value: null, child: Text('كل الأقسام')),
              for (final w in worlds) DropdownMenuItem(value: w['id'] as String, child: Text(w['name'] as String)),
            ],
            onChanged: (v) => setState(() => filter = v),
          ),
        ]),
      ),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : list.isEmpty
                ? const Center(child: Text('لا توجد قصص هنا بعد'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final w = list[i];
                      final chapters = (w['chapters'] as List?) ?? const [];
                      final voiced = chapters.where((c) => (c['audio'] ?? '') != '' || (c['audio_path'] ?? '') != '').length;
                      final cover = w['cover'] as String? ?? '';
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _open(w),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 64,
                                  height: 64,
                                  child: cover.isEmpty ? const ColoredBox(color: kSurfaceHigh, child: Icon(Icons.image_outlined)) : Image.network(cover, fit: BoxFit.cover),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(w['title'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                  const SizedBox(height: 2),
                                  Text('${names[w['world_id']] ?? '—'} • ${chapters.length} فصل • الصوت $voiced/${chapters.length}',
                                      style: const TextStyle(color: Colors.white60, fontSize: 13)),
                                  Wrap(children: [
                                    _QuickSwitch(label: 'منشورة', value: w['published'] == true, onChanged: (v) => _toggle(w, 'published', v)),
                                    _QuickSwitch(label: 'اشتراك', value: w['is_premium'] == true, onChanged: (v) => _toggle(w, 'is_premium', v)),
                                    _QuickSwitch(label: 'تحميل', value: w['allow_download'] == true, onChanged: (v) => _toggle(w, 'allow_download', v)),
                                  ]),
                                ]),
                              ),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    ]);
  }
}

class _QuickSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _QuickSwitch({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Transform.scale(scale: 0.8, child: Switch(value: value, onChanged: onChanged)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(width: 8),
        ]),
      );
}
