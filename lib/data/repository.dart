import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models.dart';

/// مصدر المحتوى: يقرأ الفهرس من الإنترنت (GitHub/R2) مع نسخة محفوظة ونسخة مدمجة.
class ContentRepository extends ChangeNotifier {
  Catalog? catalog;
  bool loading = true;
  String? error;

  /// الأساس الذي تُحلّ عليه المسارات النسبية في الفهرس.
  String _base = AppConfig.bundledContentBase;
  bool _baseIsRemote = false;

  static const _cacheKey = 'midad_catalog_cache_v1';

  /// عدد الأعمال الجديدة التي ظهرت في آخر تحديث صامت (لإظهار تنبيه لطيف).
  int newItems = 0;

  /// تحديث صامت في الخلفية (عند رجوع المستخدم للتطبيق).
  Future<void> refreshSilently() async {
    if (AppConfig.remoteContentBase.isEmpty) return;
    final before = catalog?.works.map((w) => w.id).toSet() ?? {};
    try {
      final r = await http
          .get(Uri.parse('${AppConfig.remoteContentBase}catalog.json?t=${DateTime.now().millisecondsSinceEpoch ~/ 60000}'))
          .timeout(AppConfig.remoteTimeout);
      if (r.statusCode != 200) return;
      final body = utf8.decode(r.bodyBytes);
      final c = Catalog.fromJson(jsonDecode(body) as Map<String, dynamic>);
      newItems = c.works.where((w) => !before.contains(w.id)).length;
      catalog = c;
      _base = AppConfig.remoteContentBase;
      _baseIsRemote = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, body);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> load({bool refresh = false}) async {
    loading = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();

    // ١) المحاولة من الإنترنت
    if (AppConfig.remoteContentBase.isNotEmpty) {
      try {
        final r = await http
            .get(Uri.parse('${AppConfig.remoteContentBase}catalog.json?t=${DateTime.now().millisecondsSinceEpoch ~/ 60000}'))
            .timeout(AppConfig.remoteTimeout);
        if (r.statusCode == 200) {
          final body = utf8.decode(r.bodyBytes);
          catalog = Catalog.fromJson(jsonDecode(body) as Map<String, dynamic>);
          _base = AppConfig.remoteContentBase;
          _baseIsRemote = true;
          await prefs.setString(_cacheKey, body);
          _done();
          return;
        }
      } catch (e) {
        debugPrint('remote catalog failed: $e');
      }
      // ٢) آخر نسخة محفوظة
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        try {
          catalog = Catalog.fromJson(jsonDecode(cached) as Map<String, dynamic>);
          _base = AppConfig.remoteContentBase;
          _baseIsRemote = true;
          _done();
          return;
        } catch (_) {}
      }
    }

    // ٣) النسخة المدمجة
    try {
      final s = await rootBundle.loadString('${AppConfig.bundledContentBase}catalog.json');
      catalog = Catalog.fromJson(jsonDecode(s) as Map<String, dynamic>);
      _base = AppConfig.bundledContentBase;
      _baseIsRemote = false;
    } catch (e) {
      error = 'تعذّر تحميل المكتبة';
    }
    _done();
  }

  void _done() {
    loading = false;
    notifyListeners();
  }

  bool isRemote(String path) => path.startsWith('http://') || path.startsWith('https://');

  /// يحوّل مسارًا من الفهرس إلى رابط أو مسار أصل (asset).
  ({String path, bool remote}) resolve(String path) {
    if (isRemote(path)) return (path: path, remote: true);
    return (path: '$_base$path', remote: _baseIsRemote);
  }

  Future<ChapterScript> loadScript(ChapterRef ch) async {
    final r = resolve(ch.script);
    String? body;
    if (r.remote) {
      final prefs = await SharedPreferences.getInstance();
      final key = 'midad_script_${r.path.hashCode}';
      try {
        final res = await http.get(Uri.parse(r.path)).timeout(AppConfig.remoteTimeout);
        if (res.statusCode == 200) {
          body = utf8.decode(res.bodyBytes);
          await prefs.setString(key, body);
        }
      } catch (_) {}
      body ??= prefs.getString(key);
    }
    if (body == null) {
      try {
        body = await rootBundle.loadString('${AppConfig.bundledContentBase}${ch.script}');
      } catch (_) {}
    }
    if (body == null) return ChapterScript(lines: [], speakerColors: {});
    return ChapterScript.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }
}
