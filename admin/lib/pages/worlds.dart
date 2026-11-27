import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import 'home.dart';

/// «عوالم أثير»: إضافة الأقسام وتعديلها وترتيبها، والصورة والألوان، والإظهار والتفعيل، وحذف القسم الفاضي.
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
    final works = await db.from('works').select('id,world_id');
    final ids = <String, Set<String>>{};
    for (final r in works) {
      ids.putIfAbsent(r['world_id'] as String, () => {}).add(r['id'] as String);
    }
    try {
      for (final r in await db.from('work_worlds').select('work_id,world_id')) {
        ids.putIfAbsent(r['world_id'] as String, () => {}).add(r['work_id'] as String);
      }
    } catch (_) {} // قبل تشغيل 0006_worlds.sql
    final c = {for (final e in ids.entries) e.key: e.value.length};
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
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => WorldDialog(world: w, nextOrder: worlds.length),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PageHeader(
          title: 'عوالم أثير',
          subtitle: 'الأقسام تظهر في التطبيق بنفس هذا الترتيب',
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
                        leading: _Thumb(url: worldImage(w), color: w['color'] as String?),
                        title: Text(w['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Text('${counts[w['id']] ?? 0} قصة'),
                            if ((w['tagline'] as String? ?? '').isNotEmpty) Text('«${w['tagline']}»', style: const TextStyle(color: Colors.white60)),
                            if (w['is_premium'] == true) const _Tag('اشتراك', Icons.lock_rounded),
                            if (w['published'] != true) const _Tag('معطّل', Icons.block_rounded),
                            if (w['published'] == true && w['visible'] == false) const _Tag('مخفي من العوالم', Icons.visibility_off_rounded),
                            if ((counts[w['id']] ?? 0) == 0) _Tag(w['empty_mode'] == 'hide' ? 'فاضي: مخفي' : 'فاضي: قريبًا', Icons.hourglass_empty_rounded),
                          ],
                        ),
                        trailing: Wrap(
                          children: [
                            IconButton(tooltip: 'لأعلى', onPressed: i == 0 ? null : () => _move(i, -1), icon: const Icon(Icons.arrow_upward_rounded)),
                            IconButton(
                              tooltip: 'لأسفل',
                              onPressed: i == worlds.length - 1 ? null : () => _move(i, 1),
                              icon: const Icon(Icons.arrow_downward_rounded),
                            ),
                            IconButton(tooltip: 'تعديل', onPressed: () => _edit(w), icon: const Icon(Icons.edit_rounded)),
                            IconButton(tooltip: 'حذف', onPressed: () => _delete(w), icon: const Icon(Icons.delete_outline_rounded)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
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
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: kAccent),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    ),
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
        child: url.isEmpty
            ? ColoredBox(color: c.withAlpha(90), child: const Icon(Icons.image_outlined))
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(color: c.withAlpha(90)),
              ),
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
  late final id = TextEditingController();
  late final name = TextEditingController(text: widget.world?['name'] as String? ?? '');
  late final short = TextEditingController(text: widget.world?['short'] as String? ?? '');
  late final tagline = TextEditingController(text: widget.world?['tagline'] as String? ?? '');
  late final description = TextEditingController(text: widget.world?['description'] as String? ?? '');
  late final color = TextEditingController(text: widget.world?['color'] as String? ?? '#B794F6');
  late final color2 = TextEditingController(text: widget.world?['color2'] as String? ?? '');
  late String cover = widget.world?['cover'] as String? ?? '';
  late bool premium = widget.world?['is_premium'] == true;
  late bool published = widget.world?['published'] ?? true;
  late bool visible = widget.world?['visible'] ?? true;
  late String emptyMode = widget.world?['empty_mode'] as String? ?? 'soon';
  bool busy = false;

  static const _swatches = [
    '#E8A0A8',
    '#D4AF37',
    '#E9DCC0',
    '#C08A52',
    '#3FA37A',
    '#A58CF0',
    '#1C2457',
    '#8FD694',
    '#5ED3E0',
    '#F0B35A',
    '#E7A6B5',
    '#7D8B52',
    '#4FC08D',
    '#2E7D5B',
    '#121212',
  ];

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

  static final _hex = RegExp(r'^#[0-9A-Fa-f]{6}$');
  static final _slug = RegExp(r'^[a-z][a-z0-9_]{1,40}$');

  Future<void> _save() async {
    if (name.text.trim().isEmpty) return toast(context, 'اكتب اسم القسم');
    if (!_hex.hasMatch(color.text.trim())) return toast(context, 'اللون الأساسي لازم يكون بالشكل #RRGGBB');
    if (color2.text.trim().isNotEmpty && !_hex.hasMatch(color2.text.trim())) return toast(context, 'اللون الثاني لازم يكون بالشكل #RRGGBB');
    final newWorld = widget.world == null;
    if (newWorld && id.text.trim().isNotEmpty && !_slug.hasMatch(id.text.trim())) {
      return toast(context, 'المعرّف: حروف إنجليزية صغيرة وأرقام و _ فقط');
    }
    setState(() => busy = true);
    final row = {
      'name': name.text.trim(),
      'short': short.text.trim().isEmpty ? name.text.trim() : short.text.trim(),
      'tagline': tagline.text.trim(),
      'cover': cover,
      'is_premium': premium,
      'published': published,
      'color': color.text.trim(),
      'description': description.text.trim(),
      'color2': color2.text.trim(),
      'visible': visible,
      'empty_mode': emptyMode,
    };
    try {
      if (newWorld) {
        final wid = id.text.trim().isEmpty ? newId('w') : id.text.trim();
        await db.from('worlds').insert({...row, 'id': wid, 'sort_order': widget.nextOrder});
      } else {
        await db.from('worlds').update(row).eq('id', widget.world!['id']);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        final msg = '$e'.contains('description') || '$e'.contains('visible') ? 'شغّل 0006_worlds.sql في Supabase الأول' : '$e';
        toast(context, 'تعذّر الحفظ: $msg');
        setState(() => busy = false);
      }
    }
  }

  Widget _colorField(TextEditingController c, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: c,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: CircleAvatar(radius: 9, backgroundColor: parseColor(c.text) ?? Colors.transparent),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final h in _swatches)
                InkWell(
                  onTap: () => setState(() => c.text = h),
                  child: CircleAvatar(radius: 9, backgroundColor: parseColor(h)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.world;
    final image = worldImage({...?w, 'cover': cover, 'id': w?['id'] ?? id.text.trim()});
    return AlertDialog(
      title: Text(w == null ? 'قسم جديد' : 'تعديل القسم'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (w == null) ...[
                TextField(
                  controller: id,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'المعرّف الثابت بالإنجليزي (اختياري، مثال: night_tales)'),
                ),
                const SizedBox(height: 10),
              ] else
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'المعرّف: ${w['id']}',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'اسم القسم (مثال: قبل أن تنام)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: tagline,
                decoration: const InputDecoration(labelText: 'العبارة التعريفية (مثال: دع ضجيج اليوم يرحل)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'وصف القسم'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: short,
                decoration: const InputDecoration(labelText: 'اسم مختصر (اختياري)'),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_colorField(color, 'اللون الأساسي'), const SizedBox(width: 12), _colorField(color2, 'لون التدرّج (اختياري)')],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Thumb(url: image, color: color.text),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(onPressed: busy ? null : _pickCover, icon: const Icon(Icons.upload_rounded), label: const Text('تغيير الصورة')),
                        if (cover.isNotEmpty) TextButton(onPressed: busy ? null : () => setState(() => cover = ''), child: const Text('الصورة الافتراضية')),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                value: published,
                onChanged: (v) => setState(() => published = v),
                title: const Text('القسم مفعّل'),
                subtitle: const Text('لو اتعطّل، القسم وقصصه اللي مالهاش قسم تاني مفعّل يختفوا من التطبيق'),
              ),
              SwitchListTile(
                value: visible,
                onChanged: (v) => setState(() => visible = v),
                title: const Text('ظاهر في صفحة «عوالم أثير»'),
                subtitle: const Text('لو مخفي، قصصه تفضل تظهر في البحث والرئيسية'),
              ),
              SwitchListTile(value: premium, onChanged: (v) => setState(() => premium = v), title: const Text('كل القسم باشتراك')),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: emptyMode == 'hide' ? 'hide' : 'soon',
                decoration: const InputDecoration(labelText: 'لو القسم فاضي'),
                items: const [
                  DropdownMenuItem(value: 'soon', child: Text('يظهر «قريبًا»')),
                  DropdownMenuItem(value: 'hide', child: Text('يختفي لحد ما يتضاف محتوى')),
                ],
                onChanged: (v) => setState(() => emptyMode = v ?? 'soon'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: busy ? null : _save, child: Text(busy ? 'جارٍ…' : 'حفظ')),
      ],
    );
  }
}

Color? parseColor(String hex) {
  final h = hex.trim().replaceAll('#', '');
  if (h.length != 6) return null;
  final v = int.tryParse('FF$h', radix: 16);
  return v == null ? null : Color(v);
}

/// صورة القسم: البديلة لو مرفوعة، وإلا الصورة المضمّنة في التطبيق (من المستودع العام).
String worldImage(Map<String, dynamic> w) {
  final cover = (w['cover'] as String? ?? '').trim();
  if (cover.isNotEmpty) return cover;
  final id = (w['id'] as String? ?? '').trim();
  if (!_bundled.contains(id)) return '';
  return 'https://raw.githubusercontent.com/starrnightt2030-oss/midad/main/assets/categories/$id.webp';
}

const _bundled = {
  'heartfelt_messages',
  'meaningful_words',
  'real_stories',
  'from_the_archive',
  'quran_stories',
  'biographies',
  'bedtime_stories',
  'self_discovery',
  'tranquility',
  'life_lessons',
  'hope_after_hardship',
  'wisdom_minutes',
  'between_hearts',
  'nostalgic_tales',
  'turning_point',
  'spiritual_nourishment',
};
