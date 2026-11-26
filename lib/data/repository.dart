import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models.dart';

/// مصدر المحتوى، بالترتيب:
/// ١) Supabase (المصدر الأساسي، تديره لوحة الإدارة)
/// ٢) GitHub (احتياطي أثناء الانتقال)
/// ٣) آخر نسخة محفوظة على الجهاز
/// ٤) النسخة المدمجة داخل التطبيق
class ContentRepository extends ChangeNotifier {
  Catalog? catalog;
  bool loading = true;
  String? error;

  /// من أين جاء الفهرس الحالي: supabase | github | cache | bundled
  String source = 'bundled';

  /// الأساس الذي تُحلّ عليه المسارات النسبية في الفهرس.
  String _base = AppConfig.bundledContentBase;
  bool _baseIsRemote = false;

  static const _cacheKey = 'midad_catalog_cache_v1';
  static const _cacheSourceKey = 'midad_catalog_cache_source';

  /// عدد الأعمال الجديدة التي ظهرت في آخر تحديث صامت (لإظهار تنبيه لطيف).
  int newItems = 0;

  bool get _hasSupabase => AppConfig.supabaseUrl.isNotEmpty && AppConfig.supabaseKey.isNotEmpty;

  Map<String, String> get _sbHeaders => {
        'apikey': AppConfig.supabaseKey,
        'Authorization': 'Bearer ${AppConfig.supabaseKey}',
        'Content-Type': 'application/json',
      };

  Future<String?> _rpc(String fn, [Map<String, dynamic> args = const {}]) async {
    final r = await http
        .post(Uri.parse('${AppConfig.supabaseUrl}/rest/v1/rpc/$fn'), headers: _sbHeaders, body: jsonEncode(args))
        .timeout(AppConfig.remoteTimeout);
    if (r.statusCode != 200) {
      debugPrint('supabase $fn: HTTP ${r.statusCode}');
      return null;
    }
    final body = utf8.decode(r.bodyBytes);
    return body == 'null' ? null : body;
  }

  /// يجلب الفهرس من الإنترنت: Supabase أولًا ثم GitHub.
  Future<({String body, String source})?> _fetchRemote() async {
    if (_hasSupabase) {
      try {
        final body = await _rpc('catalog_json');
        if (body != null) {
          final c = Catalog.fromJson(jsonDecode(body) as Map<String, dynamic>);
          // قاعدة فارغة (قبل نقل المحتوى) = نكمل على GitHub.
          if (c.works.isNotEmpty) return (body: body, source: 'supabase');
        }
      } catch (e) {
        debugPrint('supabase catalog failed: $e');
      }
    }
    if (AppConfig.remoteContentBase.isNotEmpty) {
      try {
        final r = await http
            .get(Uri.parse('${AppConfig.remoteContentBase}catalog.json?t=${DateTime.now().millisecondsSinceEpoch ~/ 60000}'))
            .timeout(AppConfig.remoteTimeout);
        if (r.statusCode == 200) return (body: utf8.decode(r.bodyBytes), source: 'github');
      } catch (e) {
        debugPrint('github catalog failed: $e');
      }
    }
    return null;
  }

  void _apply(String body, String src) {
    catalog = Catalog.fromJson(jsonDecode(body) as Map<String, dynamic>);
    source = src;
    // المسارات النسبية (الأجواء، الأغلفة) تُحلّ على GitHub في الحالتين.
    _base = AppConfig.remoteContentBase;
    _baseIsRemote = true;
  }

  /// تحديث صامت في الخلفية (عند رجوع المستخدم للتطبيق).
  Future<void> refreshSilently() async {
    final before = catalog?.works.map((w) => w.id).toSet() ?? {};
    try {
      final got = await _fetchRemote();
      if (got == null) return;
      _apply(got.body, got.source);
      newItems = catalog!.works.where((w) => !before.contains(w.id)).length;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, got.body);
      await prefs.setString(_cacheSourceKey, got.source);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> load({bool refresh = false}) async {
    loading = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();

    // ١ و٢) من الإنترنت
    try {
      final got = await _fetchRemote();
      if (got != null) {
        _apply(got.body, got.source);
        await prefs.setString(_cacheKey, got.body);
        await prefs.setString(_cacheSourceKey, got.source);
        _done();
        return;
      }
    } catch (e) {
      debugPrint('remote catalog failed: $e');
    }

    // ٣) آخر نسخة محفوظة
    final cached = prefs.getString(_cacheKey);
    if (cached != null) {
      try {
        _apply(cached, 'cache');
        _done();
        return;
      } catch (_) {}
    }

    // ٤) النسخة المدمجة
    try {
      final s = await rootBundle.loadString('${AppConfig.bundledContentBase}catalog.json');
      catalog = Catalog.fromJson(jsonDecode(s) as Map<String, dynamic>);
      source = 'bundled';
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

  static const _sbPrefix = 'sb:';

  Future<ChapterScript> loadScript(ChapterRef ch) async {
    final prefs = await SharedPreferences.getInstance();
    String? body;

    if (ch.script.startsWith(_sbPrefix)) {
      // فصل من Supabase: sb:<work>/<chapter>
      final ref = ch.script.substring(_sbPrefix.length);
      final slash = ref.indexOf('/');
      final key = 'midad_script_sb_$ref';
      if (slash > 0) {
        try {
          body = await _rpc('chapter_json', {'p_work': ref.substring(0, slash), 'p_chapter': ref.substring(slash + 1)});
          if (body != null) await prefs.setString(key, body);
        } catch (e) {
          debugPrint('supabase chapter failed: $e');
        }
      }
      body ??= prefs.getString(key);
      // آخر حل: نفس الفصل من الملفات المدمجة بالاسم القديم.
      if (body == null && slash > 0) {
        try {
          body = await rootBundle.loadString('${AppConfig.bundledContentBase}chapters/${ref.replaceFirst('/', '-')}.json');
        } catch (_) {}
      }
    } else {
      final r = resolve(ch.script);
      if (r.remote) {
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
    }
    if (body == null) return ChapterScript(lines: [], speakerColors: {});
    return ChapterScript.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }
}
