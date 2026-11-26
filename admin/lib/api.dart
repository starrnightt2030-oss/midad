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
Map<String, dynamic> scriptFromText(String text, {String narrator = 'الراوي'}) {
  final speakers = <String, dynamic>{narrator: {'color': '#B794F6'}};
  final lines = <Map<String, dynamic>>[];
  const palette = ['#F2B8D8', '#8FDCB0', '#5ED3E0', '#F0B35A', '#F2A7A0'];
  for (final raw in text.split('\n')) {
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
