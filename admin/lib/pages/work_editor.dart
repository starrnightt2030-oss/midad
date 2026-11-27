import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import 'home.dart';
import 'preview.dart';

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

  /// أقسام إضافية تظهر فيها القصة (غير القسم الأساسي).
  Set<String> extraWorlds = {};
  String cover = '';
  String scene = '';
  Map<String, Map<String, dynamic>> jobs = {};
  Timer? _poll;
  bool premium = false, download = false, published = false;
  List<Map<String, dynamic>> chapters = [];
  bool loading = true, busy = false;

  @override
  void initState() {
    super.initState();
    id = widget.workId;
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _loadJobs() async {
    if (id == null) return;
    final j = await db.from('voice_jobs').select().eq('work_id', id!).order('created_at');
    if (!mounted) return;
    final map = {for (final x in j) x['chapter_id'] as String: Map<String, dynamic>.from(x)};
    final active = map.values.any((x) => x['status'] == 'pending' || x['status'] == 'running');
    final wasActive = jobs.values.any((x) => x['status'] == 'pending' || x['status'] == 'running');
    setState(() => jobs = map);
    if (wasActive && !active) _load();
    _poll?.cancel();
    if (active) _poll = Timer(const Duration(seconds: 15), _loadJobs);
  }

  Future<void> _enqueue(Map<String, dynamic> ch, String kind) async {
    try {
      await enqueueVoice(id!, ch['id'] as String, kind: kind);
      if (mounted) toast(context, kind == 'align' ? 'تم طلب ضبط التوقيت؛ يجهز خلال دقائق' : 'تم طلب توليد الصوت؛ يجهز خلال دقائق');
      _loadJobs();
    } catch (e) {
      if (mounted) toast(context, 'تعذّر الطلب: $e');
    }
  }

  String? _jobLabel(Map<String, dynamic>? j) {
    final what = j?['kind'] == 'align' ? 'ضبط التوقيت' : 'التوليد';
    return switch (j?['status']) {
      'pending' => 'في انتظار $what…',
      'running' => 'جارٍ $what ${j!['progress'] ?? ''}',
      'failed' => 'فشل $what: ${j!['error']}',
      _ => null,
    };
  }

  Future<void> _load() async {
    if (id == null) return setState(() => loading = false);
    final w = await db.from('works').select().eq('id', id!).single();
    final c = await db.from('chapters').select().eq('work_id', id!).order('sort_order');
    var extra = <String>{};
    try {
      final ww = await db.from('work_worlds').select('world_id').eq('work_id', id!);
      extra = {for (final r in ww) r['world_id'] as String};
    } catch (_) {} // قبل تشغيل 0006_worlds.sql
    if (!mounted) return;
    setState(() {
      title.text = w['title'] ?? '';
      description.text = w['description'] ?? '';
      kind.text = w['kind'] ?? '';
      narrator.text = w['narrator'] ?? '';
      minutes.text = '${w['minutes'] ?? 0}';
      worldId = w['world_id'] as String;
      extraWorlds = extra..remove(worldId);
      cover = w['cover'] ?? '';
      premium = w['is_premium'] == true;
      download = w['allow_download'] == true;
      published = w['published'] == true;
      chapters = List<Map<String, dynamic>>.from(c);
      scene = w['scene'] as String? ?? '';
      loading = false;
    });
    _loadJobs();
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

  Future<void> _saveExtraWorlds() async {
    final extra = extraWorlds.where((w) => w != worldId).toList();
    try {
      await db.from('work_worlds').delete().eq('work_id', id!);
      if (extra.isNotEmpty) {
        await db.from('work_worlds').insert([
          for (final w in extra) {'work_id': id, 'world_id': w}
        ]);
      }
    } catch (e) {
      if (extra.isNotEmpty && mounted) toast(context, 'الأقسام الإضافية محتاجة تشغيل 0006_worlds.sql في Supabase');
    }
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
      'scene': scene,
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
      await _saveExtraWorlds();
      if (mounted && !quiet) toast(context, 'تم الحفظ');
      return true;
    } catch (e) {
      if (mounted) toast(context, 'تعذّر الحفظ: $e');
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// يفتح المعاينة بالبيانات الحالية (حتى غير المحفوظة)؛ ومنها يمكن النشر مباشرة.
  Future<void> _preview() async {
    if (chapters.isEmpty) return toast(context, 'أضف فصلًا الأول عشان تعاين القصة');
    final world = widget.worlds.where((w) => w['id'] == worldId).firstOrNull;
    final publish = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => StoryPreviewPage(
          title: title.text.trim(),
          narrator: narrator.text.trim(),
          category: (world?['name'] as String?) ?? kind.text.trim(),
          cover: cover,
          scene: scene,
          published: published,
          chapters: chapters,
        ),
      ),
    );
    if (publish != true || !mounted) return;
    setState(() => published = true);
    if (await _save(quiet: true)) {
      if (mounted) toast(context, 'تم نشر القصة في التطبيق ✓');
    } else if (mounted) {
      setState(() => published = false);
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
          if (id != null && chapters.isNotEmpty)
            TextButton.icon(onPressed: busy ? null : _preview, icon: const Icon(Icons.visibility_outlined), label: const Text('معاينة')),
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
                        if (widget.worlds.length > 1) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text('تظهر أيضًا في (اختياري):', style: Theme.of(context).textTheme.bodySmall),
                          ),
                          const SizedBox(height: 6),
                          Wrap(spacing: 6, runSpacing: 6, children: [
                            for (final w in widget.worlds)
                              if (w['id'] != worldId)
                                FilterChip(
                                  label: Text(w['name'] as String),
                                  selected: extraWorlds.contains(w['id']),
                                  onSelected: (on) => setState(() => on ? extraWorlds.add(w['id'] as String) : extraWorlds.remove(w['id'])),
                                ),
                          ]),
                        ],
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
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: kScenes.any((x) => x.$1 == scene) ? scene : '',
                          decoration: const InputDecoration(labelText: 'مشهد المشغّل المتحرك'),
                          items: [for (final (v, label) in kScenes) DropdownMenuItem(value: v, child: Text(label))],
                          onChanged: (v) => setState(() => scene = v ?? ''),
                        ),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Card(
                    child: Column(children: [
                      SwitchListTile(value: published, onChanged: (v) => setState(() => published = v), title: const Text('منشورة في التطبيق'), subtitle: const Text('اقفلها لحد ما تخلص الفصول والصوت')),
                      if (chapters.isNotEmpty)
                        ListTile(
                          leading: const Icon(Icons.visibility_outlined, color: kAccent),
                          title: const Text('عاين القصة قبل النشر'),
                          subtitle: const Text('شوفها زي المستمع بالظبط: المشهد والصوت والكلام المتزامن'),
                          trailing: const Icon(Icons.chevron_left_rounded),
                          onTap: busy ? null : _preview,
                        ),
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
                          if (_jobLabel(jobs[ch['id']]) != null) _jobLabel(jobs[ch['id']])!,
                        ].join(' • ')),
                        trailing: Wrap(children: [
                          if ((ch['audio'] ?? '') != '' || (ch['audio_path'] ?? '') != '')
                            IconButton(
                              tooltip: 'ضبط توقيت النص على الصوت',
                              onPressed: const ['pending', 'running'].contains(jobs[ch['id']]?['status']) ? null : () => _enqueue(ch, 'align'),
                              icon: const Icon(Icons.timer_outlined),
                            ),
                          IconButton(
                            tooltip: 'توليد الصوت بالذكاء الاصطناعي',
                            onPressed: const ['pending', 'running'].contains(jobs[ch['id']]?['status']) ? null : () => _enqueue(ch, 'tts'),
                            icon: const Icon(Icons.auto_awesome_rounded),
                          ),
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
  bool generate = false;
  bool align = false, _alignTouched = false;
  late final Map<String, String> voices = {
    for (final e in (((widget.chapter?['script'] as Map?)?['speakers'] as Map?) ?? const {}).entries)
      if (e.value is Map && (e.value as Map)['voice'] != null) e.key as String: (e.value as Map)['voice'] as String,
  };

  @override
  void initState() {
    super.initState();
    text.addListener(() => setState(() {
          // نص جديد على صوت موجود: نقترح ضبط التوقيت تلقائيًا
          if (!_alignTouched && _hasAudio && text.text.trim() != originalText.trim()) align = true;
        }));
  }

  bool get _hasAudio => audio.isNotEmpty || audioPath.isNotEmpty;

  Future<void> _pickText() async {
    final f = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['txt']);
    final file = f.isEmpty ? null : f.single;
    if (file == null) return;
    final bytes = await file.xFile.readAsBytes();
    if (!mounted) return;
    final t = prepareImportedText(utf8.decode(bytes, allowMalformed: true));
    if (t.isEmpty) return toast(context, 'الملف فارغ');
    text.text = t;
    if (title.text.trim().isEmpty) title.text = file.name.replaceAll(RegExp(r'\.txt$', caseSensitive: false), '');
  }

  String _defaultVoice(String name, int i) {
    if (name == 'الراوي') return 'Charon';
    const others = ['Aoede', 'Puck', 'Fenrir', 'Leda', 'Orus', 'Kore'];
    return others[(i - 1) % others.length];
  }

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
      if (!_alignTouched) align = true;
    } catch (e) {
      if (mounted) toast(context, 'تعذّر رفع الصوت: $e');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _save() async {
    if (title.text.trim().isEmpty) return toast(context, 'اكتب عنوان الفصل');
    setState(() => busy = true);
    // لو النص لم يتغيّر نحتفظ بالتوقيتات القديمة.
    final old = widget.chapter?['script'] as Map<String, dynamic>?;
    final same = text.text.trim() == originalText.trim() && old != null;
    final script = mergeSpeakers(same ? old : scriptFromText(text.text), old, voices);
    final row = {'title': title.text.trim(), 'script': script, 'audio': audio, 'audio_path': audioPath};
    try {
      final chId = widget.chapter?['id'] as String? ?? 'ch${DateTime.now().millisecondsSinceEpoch}';
      if (widget.chapter == null) {
        await db.from('chapters').insert({...row, 'work_id': widget.workId, 'id': chId, 'sort_order': widget.nextOrder});
      } else {
        await db.from('chapters').update(row).eq('work_id', widget.workId).eq('id', chId);
      }
      if (generate) {
        await enqueueVoice(widget.workId, chId, kind: 'tts');
      } else if (align && _hasAudio) {
        await enqueueVoice(widget.workId, chId, kind: 'align');
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
    final hasAudio = _hasAudio;
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
                hintText: 'الصق نص التسجيل هنا، كل جملة في سطر.\nلتحديد متحدث: ليلى: هل تسمع ذلك؟\nالسطر بدون اسم يقرأه الراوي.',
                alignLabelWithHint: true,
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(onPressed: busy ? null : _pickText, icon: const Icon(Icons.description_outlined), label: const Text('رفع النص من ملف (.txt)')),
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
            if (hasAudio && !generate)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: align,
                onChanged: (v) => setState(() {
                  align = v == true;
                  _alignTouched = true;
                }),
                title: const Text('اضبط توقيت النص على الصوت بعد الحفظ'),
                subtitle: const Text('يجهز خلال دقائق: كل سطر وكلمة تظهر في وقتها مع صوتك.'),
              ),
            const Divider(height: 24),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: generate,
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              title: const Text('أو ولّد الصوت بالذكاء الاصطناعي (اختياري)'),
              children: [
                Text('أصوات المتحدثين (للتوليد بالذكاء الاصطناعي)', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                for (final (i, name) in speakersOf(text.text).indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      SizedBox(width: 110, child: Text(name, overflow: TextOverflow.ellipsis)),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: voices[name] ?? _defaultVoice(name, i),
                          isDense: true,
                          items: [for (final (v, label) in kVoices) DropdownMenuItem(value: v, child: Text('$label ($v)'))],
                          onChanged: (v) => setState(() => voices[name] = v!),
                        ),
                      ),
                    ]),
                  ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: generate,
                  onChanged: (v) => setState(() => generate = v == true),
                  title: const Text('ولّد صوت الفصل بعد الحفظ'),
                  subtitle: const Text('يجهز خلال دقائق، ويستبدل الصوت الحالي، والنص يتزامن تلقائيًا.'),
                ),
              ],
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
