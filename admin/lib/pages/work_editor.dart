import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import 'home.dart';

/// إضافة أو تعديل قصة: البيانات، الغلاف، الإعدادات، والفصول (النص والصوت).
class WorkEditor extends StatefulWidget {
  final String? workId;
  final List<Map<String, dynamic>> worlds;
  const WorkEditor({super.key, this.workId, required this.worlds});

  @override
  State<WorkEditor> createState() => _WorkEditorState();
}

class _WorkEditorState extends State<WorkEditor> {
  String? id;
  final title = TextEditingController();
  final description = TextEditingController();
  final kind = TextEditingController(text: 'قصة');
  final narrator = TextEditingController(text: 'صوت أثير');
  final minutes = TextEditingController(text: '0');
  late String worldId = widget.worlds.first['id'] as String;
  String cover = '';
  bool premium = false, download = false, published = false;
  List<Map<String, dynamic>> chapters = [];
  bool loading = true, busy = false;

  @override
  void initState() {
    super.initState();
    id = widget.workId;
    _load();
  }

  Future<void> _load() async {
    if (id == null) return setState(() => loading = false);
    final w = await db.from('works').select().eq('id', id!).single();
    final c = await db.from('chapters').select().eq('work_id', id!).order('sort_order');
    if (!mounted) return;
    setState(() {
      title.text = w['title'] ?? '';
      description.text = w['description'] ?? '';
      kind.text = w['kind'] ?? '';
      narrator.text = w['narrator'] ?? '';
      minutes.text = '${w['minutes'] ?? 0}';
      worldId = w['world_id'] as String;
      cover = w['cover'] ?? '';
      premium = w['is_premium'] == true;
      download = w['allow_download'] == true;
      published = w['published'] == true;
      chapters = List<Map<String, dynamic>>.from(c);
      loading = false;
    });
  }

  Future<void> _pickCover() async {
    final f = await FilePicker.pickFiles(type: FileType.image);
    final file = f.isEmpty ? null : f.single;
    if (file == null) return;
    final bytes = await file.xFile.readAsBytes();
    if (!mounted) return;
    setState(() => busy = true);
    try {
      cover = await uploadFile(bucket: 'covers', folder: 'works', fileName: file.name, bytes: bytes);
    } catch (e) {
      if (mounted) toast(context, 'تعذّر رفع الغلاف: $e');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<bool> _save({bool quiet = false}) async {
    if (title.text.trim().isEmpty) {
      toast(context, 'اكتب عنوان القصة');
      return false;
    }
    setState(() => busy = true);
    final row = {
      'world_id': worldId,
      'title': title.text.trim(),
      'description': description.text.trim(),
      'kind': kind.text.trim(),
      'narrator': narrator.text.trim(),
      'minutes': int.tryParse(minutes.text.trim()) ?? 0,
      'cover': cover,
      'is_premium': premium,
      'allow_download': download,
      'published': published,
    };
    try {
      if (id == null) {
        final newWorkId = newId('s');
        final last = await db.from('works').select('sort_order').order('sort_order', ascending: false).limit(1);
        final order = last.isEmpty ? 0 : ((last.first['sort_order'] as int?) ?? 0) + 1;
        await db.from('works').insert({...row, 'id': newWorkId, 'sort_order': order});
        id = newWorkId;
      } else {
        await db.from('works').update(row).eq('id', id!);
      }
      if (mounted && !quiet) toast(context, 'تم الحفظ');
      return true;
    } catch (e) {
      if (mounted) toast(context, 'تعذّر الحفظ: $e');
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _delete() async {
    if (id == null) return Navigator.pop(context);
    if (!await confirm(context, 'حذف القصة', 'ستُحذف القصة وكل فصولها نهائيًا.')) return;
    await db.from('works').delete().eq('id', id!);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _editChapter([Map<String, dynamic>? ch]) async {
    if (id == null && !await _save(quiet: true)) return;
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ChapterDialog(workId: id!, chapter: ch, nextOrder: chapters.length, premium: premium),
    );
    if (saved == true) _load();
  }

  Future<void> _deleteChapter(Map<String, dynamic> ch) async {
    if (!await confirm(context, 'حذف الفصل', 'سيُحذف «${ch['title']}».')) return;
    await db.from('chapters').delete().eq('work_id', id!).eq('id', ch['id']);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(id == null ? 'قصة جديدة' : 'تعديل القصة'),
        actions: [
          if (id != null) IconButton(tooltip: 'حذف القصة', onPressed: busy ? null : _delete, icon: const Icon(Icons.delete_outline_rounded)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: FilledButton(onPressed: busy ? null : () => _save(), child: Text(busy ? 'جارٍ…' : 'حفظ')),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  Wrap(spacing: 20, runSpacing: 16, children: [
                    Column(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: SizedBox(
                          width: 160,
                          height: 180,
                          child: cover.isEmpty
                              ? const ColoredBox(color: kSurfaceHigh, child: Icon(Icons.image_outlined, size: 40))
                              : Image.network(cover, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(onPressed: busy ? null : _pickCover, icon: const Icon(Icons.upload_rounded), label: const Text('رفع غلاف')),
                    ]),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(children: [
                        TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان القصة')),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: worldId,
                          decoration: const InputDecoration(labelText: 'القسم'),
                          items: [for (final w in widget.worlds) DropdownMenuItem(value: w['id'] as String, child: Text(w['name'] as String))],
                          onChanged: (v) => setState(() => worldId = v ?? worldId),
                        ),
                        const SizedBox(height: 10),
                        TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'وصف قصير')),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: TextField(controller: kind, decoration: const InputDecoration(labelText: 'النوع (قصة، تأمل…)'))),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: narrator, decoration: const InputDecoration(labelText: 'الراوي'))),
                          const SizedBox(width: 10),
                          SizedBox(width: 110, child: TextField(controller: minutes, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'دقائق'))),
                        ]),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Card(
                    child: Column(children: [
                      SwitchListTile(value: published, onChanged: (v) => setState(() => published = v), title: const Text('منشورة في التطبيق'), subtitle: const Text('اقفلها لحد ما تخلص الفصول والصوت')),
                      SwitchListTile(value: premium, onChanged: (v) => setState(() => premium = v), title: const Text('باشتراك'), subtitle: const Text('تظهر بقفل لغير المشتركين')),
                      SwitchListTile(value: download, onChanged: (v) => setState(() => download = v), title: const Text('مسموح بالتحميل'), subtitle: const Text('الاستماع بدون إنترنت')),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: Text('الفصول', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
                    FilledButton.icon(onPressed: busy ? null : () => _editChapter(), icon: const Icon(Icons.add_rounded), label: const Text('فصل جديد')),
                  ]),
                  const SizedBox(height: 10),
                  if (chapters.isEmpty)
                    const Padding(padding: EdgeInsets.all(16), child: Text('أضف أول فصل: النص والصوت.', style: TextStyle(color: Colors.white60))),
                  for (final ch in chapters)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: kSurfaceHigh, child: Text('${chapters.indexOf(ch) + 1}')),
                        title: Text(ch['title'] as String? ?? ''),
                        subtitle: Text([
                          '${((ch['script'] as Map?)?['lines'] as List?)?.length ?? 0} سطر',
                          (ch['audio'] ?? '') != '' || (ch['audio_path'] ?? '') != '' ? 'فيه صوت' : 'بدون صوت',
                          if (scriptHasTimings(ch['script'] as Map<String, dynamic>?)) 'متزامن',
                        ].join(' • ')),
                        trailing: Wrap(children: [
                          IconButton(tooltip: 'تعديل', onPressed: () => _editChapter(ch), icon: const Icon(Icons.edit_rounded)),
                          IconButton(tooltip: 'حذف', onPressed: () => _deleteChapter(ch), icon: const Icon(Icons.delete_outline_rounded)),
                        ]),
                      ),
                    ),
                ]),
              ),
            ),
    );
  }
}

class ChapterDialog extends StatefulWidget {
  final String workId;
  final Map<String, dynamic>? chapter;
  final int nextOrder;
  final bool premium;
  const ChapterDialog({super.key, required this.workId, this.chapter, required this.nextOrder, required this.premium});

  @override
  State<ChapterDialog> createState() => _ChapterDialogState();
}

class _ChapterDialogState extends State<ChapterDialog> {
  late final title = TextEditingController(text: widget.chapter?['title'] as String? ?? '');
  late final String originalText = textFromScript(widget.chapter?['script'] as Map<String, dynamic>?);
  late final text = TextEditingController(text: originalText);
  late String audio = widget.chapter?['audio'] as String? ?? '';
  late String audioPath = widget.chapter?['audio_path'] as String? ?? '';
  String? audioName;
  bool busy = false;

  Future<void> _pickAudio() async {
    final f = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['mp3', 'm4a', 'aac', 'wav', 'ogg']);
    final file = f.isEmpty ? null : f.single;
    if (file == null) return;
    final bytes = await file.xFile.readAsBytes();
    if (!mounted) return;
    if (bytes.length > 50 * 1024 * 1024) return toast(context, 'الملف أكبر من ٥٠ ميجا');
    setState(() => busy = true);
    try {
      final bucket = widget.premium ? 'premium' : 'audio';
      final r = await uploadFile(bucket: bucket, folder: widget.workId, fileName: file.name, bytes: bytes);
      if (widget.premium) {
        audioPath = r;
        audio = '';
      } else {
        audio = r;
        audioPath = '';
      }
      audioName = file.name;
    } catch (e) {
      if (mounted) toast(context, 'تعذّر رفع الصوت: $e');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _save() async {
    if (title.text.trim().isEmpty) return toast(context, 'اكتب عنوان الفصل');
    setState(() => busy = true);
    // لو النص لم يتغيّر نحتفظ بالتوقيتات القديمة.
    final script = text.text.trim() == originalText.trim() && widget.chapter != null
        ? widget.chapter!['script']
        : scriptFromText(text.text);
    final row = {'title': title.text.trim(), 'script': script, 'audio': audio, 'audio_path': audioPath};
    try {
      if (widget.chapter == null) {
        await db.from('chapters').insert({...row, 'work_id': widget.workId, 'id': 'ch${DateTime.now().millisecondsSinceEpoch}', 'sort_order': widget.nextOrder});
      } else {
        await db.from('chapters').update(row).eq('work_id', widget.workId).eq('id', widget.chapter!['id']);
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
    final hasAudio = audio.isNotEmpty || audioPath.isNotEmpty;
    return AlertDialog(
      title: Text(widget.chapter == null ? 'فصل جديد' : 'تعديل الفصل'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان الفصل')),
            const SizedBox(height: 10),
            TextField(
              controller: text,
              minLines: 8,
              maxLines: 16,
              decoration: const InputDecoration(
                labelText: 'نص الفصل',
                hintText: 'كل جملة في سطر.\nلتحديد متحدث: ليلى: هل تسمع ذلك؟\nالسطر بدون اسم يقرأه الراوي.',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Icon(hasAudio ? Icons.check_circle_rounded : Icons.music_off_rounded, color: hasAudio ? kAccent : Colors.white54),
              const SizedBox(width: 8),
              Expanded(child: Text(audioName ?? (hasAudio ? 'يوجد ملف صوت' : 'لا يوجد صوت بعد (يُعرض النص بقراءة تقديرية)'))),
              OutlinedButton.icon(onPressed: busy ? null : _pickAudio, icon: const Icon(Icons.upload_file_rounded), label: Text(hasAudio ? 'استبدال الصوت' : 'رفع صوت')),
              if (hasAudio)
                IconButton(
                  tooltip: 'إزالة الصوت',
                  onPressed: busy ? null : () => setState(() {
                    audio = '';
                    audioPath = '';
                    audioName = null;
                  }),
                  icon: const Icon(Icons.close_rounded),
                ),
            ]),
            if (widget.premium)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('القصة باشتراك: الصوت يُحفظ في مكان محمي.', style: TextStyle(fontSize: 12, color: Colors.white54)),
              ),
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
