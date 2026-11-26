import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repository.dart';
import '../models.dart';

/// تحميل القصص للاستماع بدون إنترنت (للقصص المسموح بتحميلها من اللوحة).
class DownloadStore extends ChangeNotifier {
  final ContentRepository repo;
  DownloadStore(this.repo);

  static const _k = 'atheer_downloads_v1';
  final Set<String> done = {};

  /// تقدّم التحميل الجاري لكل قصة (0..1).
  final Map<String, double> active = {};
  Directory? _dir;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    done.addAll(prefs.getStringList(_k) ?? const []);
    try {
      _dir = Directory('${(await getApplicationDocumentsDirectory()).path}/downloads');
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_k, done.toList());
  }

  bool isDone(String workId) => done.contains(workId);

  File? _file(String workId, String chapterId) => _dir == null ? null : File('${_dir!.path}/$workId/$chapterId.m4a');

  /// ملف محلي للفصل لو كان محمّلًا.
  String? localPath(Work w, ChapterRef ch) {
    if (!done.contains(w.id)) return null;
    final f = _file(w.id, ch.id);
    return f != null && f.existsSync() ? f.path : null;
  }

  /// يرجع null عند النجاح، أو رسالة.
  Future<String?> download(Work w) async {
    if (active.containsKey(w.id)) return null;
    if (_dir == null) return 'التخزين غير متاح على هذا الجهاز';
    active[w.id] = 0;
    notifyListeners();
    try {
      for (var i = 0; i < w.chapters.length; i++) {
        final ch = w.chapters[i];
        await repo.loadScript(ch); // يحفظ النص والتوقيتات للعمل بدون إنترنت
        final url = (ch.audio != null && repo.isRemote(ch.audio!)) ? ch.audio : (w.premium ? await repo.signedAudio(ch) : null);
        if (url != null) {
          final f = _file(w.id, ch.id)!;
          await f.parent.create(recursive: true);
          final res = await http.Client().send(http.Request('GET', Uri.parse(url)));
          if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
          final tmp = File('${f.path}.part');
          final sink = tmp.openWrite();
          final total = res.contentLength ?? 0;
          var got = 0;
          await for (final chunk in res.stream) {
            sink.add(chunk);
            got += chunk.length;
            if (total > 0) {
              active[w.id] = (i + got / total) / w.chapters.length;
              notifyListeners();
            }
          }
          await sink.close();
          await tmp.rename(f.path);
        }
        active[w.id] = (i + 1) / w.chapters.length;
        notifyListeners();
      }
      done.add(w.id);
      await _save();
      return null;
    } catch (e) {
      debugPrint('download ${w.id}: $e');
      return 'تعذّر التحميل، تأكد من الإنترنت وحاول مرة أخرى';
    } finally {
      active.remove(w.id);
      notifyListeners();
    }
  }

  Future<void> remove(Work w) async {
    done.remove(w.id);
    await _save();
    try {
      final d = Directory('${_dir!.path}/${w.id}');
      if (d.existsSync()) await d.delete(recursive: true);
    } catch (_) {}
    notifyListeners();
  }
}
