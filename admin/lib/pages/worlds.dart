import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import 'home.dart';

/// الأقسام: إضافة، تعديل، ترتيب، قفل بالاشتراك، إخفاء، وحذف.
class WorldsPage extends StatefulWidget {
  const WorldsPage({super.key});

  @override
  State<WorldsPage> createState() => _WorldsPageState();
}

class _WorldsPageState extends State<WorldsPage> {
  List<Map<String, dynamic>> worlds = [];
  Map<String, int> counts = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final w = await db.from('worlds').select().order('sort_order').order('id');
    final works = await db.from('works').select('world_id');
    final c = <String, int>{};
    for (final r in works) {
      c[r['world_id'] as String] = (c[r['world_id']] ?? 0) + 1;
    }
    if (!mounted) return;
    setState(() {
      worlds = List<Map<String, dynamic>>.from(w);
      counts = c;
      loading = false;
    });
  }

  Future<void> _move(int i, int d) async {
    final j = i + d;
    if (j < 0 || j >= worlds.length) return;
    final list = [...worlds];
    final x = list.removeAt(i);
    list.insert(j, x);
    setState(() => worlds = list);
    for (var k = 0; k < list.length; k++) {
      await db.from('worlds').update({'sort_order': k}).eq('id', list[k]['id']);
    }
  }

  Future<void> _delete(Map<String, dynamic> w) async {
    if ((counts[w['id']] ?? 0) > 0) {
      toast(context, 'انقل أو احذف قصص القسم أولًا');
      return;
    }
    if (!await confirm(context, 'حذف القسم', 'سيُحذف «${w['name']}» نهائيًا.')) return;
    await db.from('worlds').delete().eq('id', w['id']);
    _load();
  }

  Future<void> _edit([Map<String, dynamic>? w]) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => WorldDialog(world: w, nextOrder: worlds.length));
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      PageHeader(
        title: 'الأقسام',
        subtitle: 'تظهر في التطبيق بنفس هذا الترتيب',
        action: FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add_rounded), label: const Text('قسم جديد')),
      ),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : worlds.isEmpty
                ? const Center(child: Text('لا توجد أقسام بعد. ابدأ بإضافة أول قسم.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: worlds.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final w = worlds[i];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: _Thumb(url: w['cover'] as String? ?? '', color: w['color'] as String?),
                          title: Text(w['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Wrap(spacing: 6, runSpacing: 4, children: [
                            Text('${counts[w['id']] ?? 0} قصة'),
                            if (w['is_premium'] == true) const _Tag('اشتراك', Icons.lock_rounded),
                            if (w['published'] != true) const _Tag('مخفي', Icons.visibility_off_rounded),
                          ]),
                          trailing: Wrap(children: [
                            IconButton(tooltip: 'لأعلى', onPressed: i == 0 ? null : () => _move(i, -1), icon: const Icon(Icons.arrow_upward_rounded)),
                            IconButton(tooltip: 'لأسفل', onPressed: i == worlds.length - 1 ? null : () => _move(i, 1), icon: const Icon(Icons.arrow_downward_rounded)),
                            IconButton(tooltip: 'تعديل', onPressed: () => _edit(w), icon: const Icon(Icons.edit_rounded)),
                            IconButton(tooltip: 'حذف', onPressed: () => _delete(w), icon: const Icon(Icons.delete_outline_rounded)),
                          ]),
                        ),
                      );
                    },
                  ),
      ),
    ]);
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final IconData icon;
  const _Tag(this.label, this.icon);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: kAccent.withAlpha(40), borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 12, color: kAccent), const SizedBox(width: 4), Text(label, style: const TextStyle(fontSize: 12))]),
      );
}

class _Thumb extends StatelessWidget {
  final String url;
  final String? color;
  const _Thumb({required this.url, this.color});

  @override
  Widget build(BuildContext context) {
    final c = Color(int.tryParse('FF${(color ?? '#B794F6').replaceAll('#', '')}', radix: 16) ?? 0xFFB794F6);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 52,
        height: 52,
        child: url.isEmpty ? ColoredBox(color: c.withAlpha(90), child: const Icon(Icons.image_outlined)) : Image.network(url, fit: BoxFit.cover),
      ),
    );
  }
}

class WorldDialog extends StatefulWidget {
  final Map<String, dynamic>? world;
  final int nextOrder;
  const WorldDialog({super.key, this.world, required this.nextOrder});

  @override
  State<WorldDialog> createState() => _WorldDialogState();
}

class _WorldDialogState extends State<WorldDialog> {
  late final name = TextEditingController(text: widget.world?['name'] as String? ?? '');
  late final short = TextEditingController(text: widget.world?['short'] as String? ?? '');
  late final tagline = TextEditingController(text: widget.world?['tagline'] as String? ?? '');
  late String cover = widget.world?['cover'] as String? ?? '';
  late bool premium = widget.world?['is_premium'] == true;
  late bool published = widget.world?['published'] ?? true;
  bool busy = false;

  Future<void> _pickCover() async {
    final f = await FilePicker.pickFiles(type: FileType.image);
    final file = f.isEmpty ? null : f.single;
    if (file == null) return;
    final bytes = await file.xFile.readAsBytes();
    if (!mounted) return;
    setState(() => busy = true);
    try {
      cover = await uploadFile(bucket: 'covers', folder: 'worlds', fileName: file.name, bytes: bytes);
    } catch (e) {
      if (mounted) toast(context, 'تعذّر رفع الصورة: $e');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _save() async {
    if (name.text.trim().isEmpty) return toast(context, 'اكتب اسم القسم');
    setState(() => busy = true);
    final row = {
      'name': name.text.trim(),
      'short': short.text.trim().isEmpty ? name.text.trim() : short.text.trim(),
      'tagline': tagline.text.trim(),
      'cover': cover,
      'is_premium': premium,
      'published': published,
    };
    try {
      if (widget.world == null) {
        await db.from('worlds').insert({...row, 'id': newId('w'), 'sort_order': widget.nextOrder});
      } else {
        await db.from('worlds').update(row).eq('id', widget.world!['id']);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        toast(context, 'تعذّر الحفظ: $e');
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.world == null ? 'قسم جديد' : 'تعديل القسم'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم القسم (مثال: قصص النوم)')),
            const SizedBox(height: 10),
            TextField(controller: short, decoration: const InputDecoration(labelText: 'اسم مختصر للشرائح (اختياري)')),
            const SizedBox(height: 10),
            TextField(controller: tagline, decoration: const InputDecoration(labelText: 'وصف قصير (اختياري)')),
            const SizedBox(height: 12),
            Row(children: [
              _Thumb(url: cover),
              const SizedBox(width: 12),
              OutlinedButton.icon(onPressed: busy ? null : _pickCover, icon: const Icon(Icons.upload_rounded), label: const Text('صورة القسم')),
            ]),
            SwitchListTile(value: premium, onChanged: (v) => setState(() => premium = v), title: const Text('كل القسم باشتراك')),
            SwitchListTile(value: published, onChanged: (v) => setState(() => published = v), title: const Text('ظاهر في التطبيق')),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: busy ? null : _save, child: Text(busy ? 'جارٍ…' : 'حفظ')),
      ],
    );
  }
}
