import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient get db => Supabase.instance.client;

/// معرّف قصير فريد (حروف لاتينية وأرقام) للأقسام والقصص الجديدة.
String newId(String prefix) {
  final r = Random.secure();
  const chars = 'abcdefghijkmnpqrstuvwxyz23456789';
  return '$prefix-${List.generate(6, (_) => chars[r.nextInt(chars.length)]).join()}';
}

String _ext(String name) {
  final i = name.lastIndexOf('.');
  return i < 0 ? '' : name.substring(i + 1).toLowerCase();
}

String _mime(String ext) => switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'mp3' => 'audio/mpeg',
      'm4a' || 'mp4' => 'audio/mp4',
      'aac' => 'audio/aac',
      'ogg' || 'opus' => 'audio/ogg',
      'wav' => 'audio/wav',
      _ => 'application/octet-stream',
    };

/// يرفع ملفًا إلى حاوية. يرجع الرابط العام (للحاويات العامة) أو المسار (للحاوية الخاصة).
Future<String> uploadFile({required String bucket, required String folder, required String fileName, required Uint8List bytes}) async {
  final ext = _ext(fileName);
  final path = '$folder/${DateTime.now().millisecondsSinceEpoch}.$ext';
  await db.storage.from(bucket).uploadBinary(path, bytes, fileOptions: FileOptions(contentType: _mime(ext), upsert: true));
  if (bucket == 'premium') return path;
  return db.storage.from(bucket).getPublicUrl(path);
}

/// يحوّل النص إلى سطور القصة. كل سطر جملة؛ «اسم: كلام» لتحديد المتحدث، والسطر بلا اسم للراوي.
/// الفقرات الطويلة (نص ملصوق كقطعة واحدة) تُقسَم جملًا، حتى تتابع القراءة الحية الصوت سطرًا سطرًا.
Map<String, dynamic> scriptFromText(String text, {String narrator = 'الراوي'}) {
  final speakers = <String, dynamic>{narrator: {'color': '#B794F6'}};
  final lines = <Map<String, dynamic>>[];
  const palette = ['#F2B8D8', '#8FDCB0', '#5ED3E0', '#F0B35A', '#F2A7A0'];
  for (final raw in prepareImportedText(text).split('\n')) {
    final t = raw.trim();
    if (t.isEmpty) continue;
    var speaker = narrator;
    var body = t;
    final m = RegExp(r'^([^:：]{1,24})[:：]\s*(.+)$').firstMatch(t);
    if (m != null) {
      speaker = m.group(1)!.trim();
      body = m.group(2)!.trim();
      speakers.putIfAbsent(speaker, () => {'color': palette[(speakers.length - 1) % palette.length]});
    }
    lines.add({'speaker': speaker, 'text': body});
  }
  return {'speakers': speakers, 'lines': lines};
}

/// العكس: يحوّل سطور القصة المحفوظة إلى نص قابل للتعديل.
String textFromScript(Map<String, dynamic>? script, {String narrator = 'الراوي'}) {
  final lines = (script?['lines'] as List?) ?? const [];
  return lines.map((l) {
    final m = l as Map;
    final sp = (m['speaker'] ?? narrator) as String;
    return sp == narrator ? '${m['text']}' : '$sp: ${m['text']}';
  }).join('\n');
}

/// هل في النص توقيتات حقيقية (من توليد الصوت)؟
bool scriptHasTimings(Map<String, dynamic>? script) =>
    ((script?['lines'] as List?) ?? const []).any((l) => l is Map && l['start'] != null);

/// أصوات Gemini المتاحة للتوليد.
const kVoices = <(String, String)>[
  ('Charon', 'رجالي عميق هادئ'),
  ('Orus', 'رجالي ثابت'),
  ('Iapetus', 'رجالي واضح'),
  ('Algieba', 'رجالي ناعم'),
  ('Fenrir', 'رجالي حماسي'),
  ('Puck', 'رجالي مرح'),
  ('Sulafat', 'نسائي دافئ'),
  ('Kore', 'نسائي ثابت'),
  ('Achernar', 'نسائي ناعم'),
  ('Aoede', 'نسائي خفيف'),
  ('Leda', 'نسائي شاب'),
  ('Zephyr', 'نسائي مشرق'),
];

/// مشاهد المشغّل المتحركة.
const kScenes = <(String, String)>[
  ('', 'تلقائي'),
  ('night', 'ليل ونجوم'),
  ('rain', 'مطر'),
  ('sea', 'بحر'),
  ('forest', 'غابة ويراعات'),
  ('desert', 'صحراء'),
  ('snow', 'ثلج'),
  ('embers', 'نار هادئة'),
];

/// يضيف طلبًا لفصل؛ العامل على GitHub ينفّذه خلال دقائق.
/// kind: 'align' يضبط توقيت النص على الصوت المرفوع، و 'tts' يولّد الصوت بالذكاء الاصطناعي.
Future<void> enqueueVoice(String workId, String chapterId, {required String kind}) async {
  await db.from('voice_jobs').delete().eq('work_id', workId).eq('chapter_id', chapterId).inFilter('status', ['done', 'failed']);
  final open = await db.from('voice_jobs').select('id').eq('work_id', workId).eq('chapter_id', chapterId).inFilter('status', ['pending', 'running']);
  if (open.isEmpty) await db.from('voice_jobs').insert({'work_id': workId, 'chapter_id': chapterId, 'kind': kind});
}

/// يجهّز نصًا مستوردًا من ملف: الفقرات الطويلة تُقسَم جملًا (سطر لكل جملة) حتى تتابعها القراءة الحية.
/// سطور الحوار «اسم: كلام» تبقى كما هي.
String prepareImportedText(String raw) {
  final out = <String>[];
  final speaker = RegExp(r'^([^:：]{1,24})[:：]\s*(.+)$');
  for (final line in raw.replaceAll('\r', '').replaceAll('\uFEFF', '').split('\n')) {
    final t = line.trim();
    if (t.isEmpty) continue;
    if (speaker.hasMatch(t) || t.length <= 160) {
      out.add(t);
      continue;
    }
    for (final s in t.split(RegExp(r'(?<=[.!؟?…])\s+'))) {
      if (s.trim().isNotEmpty) out.add(s.trim());
    }
  }
  return out.join('\n');
}

/// يدمج إعدادات المتحدثين القديمة (اللون والصوت) في نص جديد.
Map<String, dynamic> mergeSpeakers(Map<String, dynamic> script, Map<String, dynamic>? old, Map<String, String> voices) {
  final sp = Map<String, dynamic>.from(script['speakers'] as Map? ?? {});
  final oldSp = (old?['speakers'] as Map?) ?? const {};
  for (final name in sp.keys.toList()) {
    final base = Map<String, dynamic>.from(sp[name] is Map ? sp[name] as Map : {'color': sp[name]});
    if (oldSp[name] is Map) base.addAll(Map<String, dynamic>.from(oldSp[name] as Map));
    if (voices[name] != null) base['voice'] = voices[name];
    sp[name] = base;
  }
  return {...script, 'speakers': sp};
}

/// أسماء المتحدثين بترتيب ظهورهم في النص.
List<String> speakersOf(String text, {String narrator = 'الراوي'}) {
  final s = scriptFromText(text, narrator: narrator);
  final names = <String>[narrator];
  for (final l in (s['lines'] as List)) {
    final n = (l as Map)['speaker'] as String;
    if (!names.contains(n)) names.add(n);
  }
  return names;
}
