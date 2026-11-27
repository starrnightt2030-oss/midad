import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models.dart';

/// مصدر المحتوى: Supabase فقط (تديره لوحة الإدارة).
/// بدون إنترنت نعرض آخر نسخة محفوظة منه. الأجواء الصوتية مدمجة في التطبيق.
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

  /// رمز المستخدم المسجّل (يضبطه main من AccountStore)، وإلا المفتاح العام.
  Future<String> Function()? tokenProvider;

  Future<Map<String, String>> _sbHeaders() async => {
        'apikey': AppConfig.supabaseKey,
        'Authorization': 'Bearer ${tokenProvider == null ? AppConfig.supabaseKey : await tokenProvider!()}',
        'Content-Type': 'application/json',
      };

  /// مسارات صوت الفصول المدفوعة (من chapter_json للمشترك).
  final Map<String, String> _premiumAudio = {};

  Future<String?> _rpc(String fn, [Map<String, dynamic> args = const {}]) async {
    final r = await http
        .post(Uri.parse('${AppConfig.supabaseUrl}/rest/v1/rpc/$fn'), headers: await _sbHeaders(), body: jsonEncode(args))
        .timeout(AppConfig.remoteTimeout);
    if (r.statusCode != 200) {
      debugPrint('supabase $fn: HTTP ${r.statusCode}');
      return null;
    }
    final body = utf8.decode(r.bodyBytes);
    return body == 'null' ? null : body;
  }

  final Set<String> _counted = {};

  /// يعدّ مرة استماع للقصة (مرة واحدة لكل قصة في كل تشغيل للتطبيق) لـ«الأكثر استماعًا».
  void countPlay(String workId) {
    if (!_hasSupabase || !_counted.add(workId)) return;
    _rpc('count_play', {'p_work': workId}).catchError((_) => null);
  }

  /// يجلب الفهرس من Supabase. القاعدة الفارغة فهرس صحيح (بدون قصص بعد).
  Future<String?> _fetchRemote() async {
    if (!_hasSupabase) return null;
    try {
      final body = await _rpc('catalog_json');
      if (body != null) Catalog.fromJson(jsonDecode(body) as Map<String, dynamic>); // تحقق من الشكل
      return body;
    } catch (e) {
      debugPrint('supabase catalog failed: $e');
      return null;
    }
  }

  /// الأجواء الصوتية المدمجة (تُستخدم لو لم تُضف أجواء من اللوحة).
  Future<List<Ambience>> _bundledAmbience() async {
    try {
      final s = await rootBundle.loadString('${AppConfig.bundledContentBase}catalog.json');
      return Catalog.fromJson(jsonDecode(s) as Map<String, dynamic>).ambience;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _apply(String body, String src) async {
    var c = Catalog.fromJson(jsonDecode(body) as Map<String, dynamic>);
    if (c.ambience.isEmpty) {
      c = Catalog(version: c.version, worlds: c.worlds, works: c.works, ambience: await _bundledAmbience());
    }
    catalog = c;
    source = src;
    // الأغلفة والصوت روابط كاملة؛ المسارات النسبية (الأجواء) من داخل التطبيق.
    _base = AppConfig.bundledContentBase;
    _baseIsRemote = false;
  }

  /// تحديث صامت في الخلفية (عند رجوع المستخدم للتطبيق).
  Future<void> refreshSilently() async {
    final before = catalog?.works.map((w) => w.id).toSet() ?? {};
    try {
      final body = await _fetchRemote();
      if (body == null) return;
      await _apply(body, 'supabase');
      newItems = catalog!.works.where((w) => !before.contains(w.id)).length;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, body);
      await prefs.setString(_cacheSourceKey, 'supabase');
      notifyListeners();
    } catch (_) {}
  }

  Future<void> load({bool refresh = false}) async {
    loading = true;
    error = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();

    // ١) من Supabase
    final body = await _fetchRemote();
    if (body != null) {
      try {
        await _apply(body, 'supabase');
        await prefs.setString(_cacheKey, body);
        await prefs.setString(_cacheSourceKey, 'supabase');
        _done();
        return;
      } catch (e) {
        debugPrint('catalog apply failed: $e');
      }
    }

    // ٢) آخر نسخة محفوظة من Supabase (المحتوى التجريبي القديم يُتجاهل)
    final cached = prefs.getString(_cacheKey);
    if (cached != null && prefs.getString(_cacheSourceKey) == 'supabase') {
      try {
        await _apply(cached, 'cache');
        _done();
        return;
      } catch (_) {}
    }

    error = 'تحتاج اتصالًا بالإنترنت لتحميل المكتبة أول مرة';
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

  /// رابط مؤقت لصوت فصل مدفوع (للمشترك فقط). يُستدعى بعد loadScript.
  Future<String?> signedAudio(ChapterRef ch) async {
    if (!ch.script.startsWith(_sbPrefix)) return null;
    final ref = ch.script.substring(_sbPrefix.length);
    var path = _premiumAudio[ref];
    if (path == null) {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('midad_script_sb_$ref');
      if (cached != null) path = '${(jsonDecode(cached) as Map)['audio_path'] ?? ''}';
    }
    if (path == null || path.isEmpty) return null;
    try {
      final r = await http
          .post(Uri.parse('${AppConfig.supabaseUrl}/storage/v1/object/sign/premium/$path'),
              headers: await _sbHeaders(), body: jsonEncode({'expiresIn': 6 * 3600}))
          .timeout(AppConfig.remoteTimeout);
      if (r.statusCode != 200) return null;
      final u = (jsonDecode(r.body) as Map)['signedURL'] as String?;
      return u == null ? null : '${AppConfig.supabaseUrl}/storage/v1$u';
    } catch (_) {
      return null;
    }
  }

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
          if (body != null) {
            final j = jsonDecode(body) as Map<String, dynamic>;
            if (j['locked'] == true) {
              // مقفول لغير المشترك: لا نحفظه حتى يظهر النص كاملًا بعد الاشتراك
              return ChapterScript(lines: [], speakerColors: {});
            }
            final ap = '${j['audio_path'] ?? ''}';
            if (ap.isNotEmpty) _premiumAudio[ref] = ap;
            await prefs.setString(key, body);
          }
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
