import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// حساب المستمع (بريد وكلمة مرور على Supabase Auth) وحالة اشتراكه.
/// تنفيذ خفيف مباشر على واجهة Supabase بدون مكتبات إضافية.
class AccountStore extends ChangeNotifier {
  String? _access, _refresh, email, userId;
  DateTime? _expires;
  bool premium = false;
  DateTime? until;
  bool loaded = false;

  /// معلومات الاشتراك العامة من اللوحة (السعر، واتساب، النص).
  Map<String, dynamic> info = {};

  bool get signedIn => _access != null;

  static const _k = 'atheer_account_v1';
  String get _auth => '${AppConfig.supabaseUrl}/auth/v1';
  Map<String, String> get _baseHeaders => {'apikey': AppConfig.supabaseKey, 'Content-Type': 'application/json'};

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_k);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        _access = j['access'];
        _refresh = j['refresh'];
        email = j['email'];
        userId = j['id'];
        _expires = DateTime.tryParse(j['expires'] ?? '');
        premium = j['premium'] == true;
        until = DateTime.tryParse(j['until'] ?? '');
      } catch (_) {}
    }
    loaded = true;
    notifyListeners();
    refreshStatus();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    if (_access == null) {
      await prefs.remove(_k);
      return;
    }
    await prefs.setString(_k, jsonEncode({
      'access': _access,
      'refresh': _refresh,
      'email': email,
      'id': userId,
      'expires': _expires?.toIso8601String(),
      'premium': premium,
      'until': until?.toIso8601String(),
    }));
  }

  void _applySession(Map<String, dynamic> j) {
    _access = j['access_token'] as String?;
    _refresh = j['refresh_token'] as String?;
    final secs = (j['expires_in'] as num?)?.toInt() ?? 3600;
    _expires = DateTime.now().add(Duration(seconds: secs));
    final u = j['user'] as Map<String, dynamic>?;
    email = u?['email'] as String? ?? email;
    userId = u?['id'] as String? ?? userId;
  }

  /// رمز صالح للطلبات (يجدّده تلقائيًا)، أو المفتاح العام لو لم يسجّل الدخول.
  Future<String> token() async {
    if (_access == null) return AppConfig.supabaseKey;
    if (_expires != null && DateTime.now().isAfter(_expires!.subtract(const Duration(minutes: 1)))) {
      await _refreshSession();
    }
    return _access ?? AppConfig.supabaseKey;
  }

  Future<void> _refreshSession() async {
    if (_refresh == null) return;
    try {
      final r = await http
          .post(Uri.parse('$_auth/token?grant_type=refresh_token'), headers: _baseHeaders, body: jsonEncode({'refresh_token': _refresh}))
          .timeout(AppConfig.remoteTimeout);
      if (r.statusCode == 200) {
        _applySession(jsonDecode(r.body) as Map<String, dynamic>);
        await _save();
      } else if (r.statusCode == 400 || r.statusCode == 401) {
        await signOut(); // الجلسة انتهت فعلًا
      }
    } catch (_) {
      // بدون إنترنت: نترك الجلسة كما هي ونحاول لاحقًا
    }
  }

  String _err(http.Response r) {
    try {
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final m = '${j['msg'] ?? j['error_description'] ?? j['message'] ?? ''}'.toLowerCase();
      if (m.contains('invalid login')) return 'البريد أو كلمة المرور غير صحيحة';
      if (m.contains('already registered') || m.contains('already been registered')) return 'هذا البريد مسجّل بالفعل، سجّل الدخول';
      if (m.contains('password')) return 'كلمة المرور قصيرة (٦ أحرف على الأقل)';
      if (m.contains('email not confirmed')) return 'أكّد بريدك أولًا من الرسالة التي وصلتك';
      if (m.contains('rate limit')) return 'محاولات كثيرة، حاول بعد قليل';
      if (m.contains('email')) return 'اكتب بريدًا صحيحًا';
    } catch (_) {}
    return 'تعذّر الاتصال (${r.statusCode})';
  }

  /// يرجع null عند النجاح، أو رسالة للمستخدم.
  Future<String?> signIn(String mail, String password) async {
    try {
      final r = await http
          .post(Uri.parse('$_auth/token?grant_type=password'),
              headers: _baseHeaders, body: jsonEncode({'email': mail.trim(), 'password': password}))
          .timeout(AppConfig.remoteTimeout);
      if (r.statusCode != 200) return _err(r);
      _applySession(jsonDecode(r.body) as Map<String, dynamic>);
      await _save();
      notifyListeners();
      await refreshStatus();
      return null;
    } catch (_) {
      return 'تأكد من الاتصال بالإنترنت';
    }
  }

  Future<String?> signUp(String mail, String password) async {
    try {
      final r = await http
          .post(Uri.parse('$_auth/signup'), headers: _baseHeaders, body: jsonEncode({'email': mail.trim(), 'password': password}))
          .timeout(AppConfig.remoteTimeout);
      if (r.statusCode != 200) return _err(r);
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      if (j['access_token'] == null) return 'تم إنشاء الحساب. افتح رسالة التأكيد في بريدك ثم سجّل الدخول';
      _applySession(j);
      await _save();
      notifyListeners();
      await refreshStatus();
      return null;
    } catch (_) {
      return 'تأكد من الاتصال بالإنترنت';
    }
  }

  Future<void> signOut() async {
    final t = _access;
    _access = _refresh = email = userId = null;
    premium = false;
    until = null;
    await _save();
    notifyListeners();
    if (t != null) {
      try {
        await http.post(Uri.parse('$_auth/logout'), headers: {..._baseHeaders, 'Authorization': 'Bearer $t'}).timeout(AppConfig.remoteTimeout);
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>?> _rpc(String fn) async {
    final r = await http
        .post(Uri.parse('${AppConfig.supabaseUrl}/rest/v1/rpc/$fn'),
            headers: {..._baseHeaders, 'Authorization': 'Bearer ${await token()}'}, body: '{}')
        .timeout(AppConfig.remoteTimeout);
    if (r.statusCode != 200) return null;
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>?;
  }

  /// يحدّث حالة الاشتراك ومعلومات الاشتراك العامة.
  Future<void> refreshStatus() async {
    try {
      final i = await _rpc('app_info');
      if (i != null) info = i;
      if (signedIn) {
        final s = await _rpc('my_status');
        if (s != null) {
          premium = s['premium'] == true;
          until = DateTime.tryParse('${s['until'] ?? ''}');
          await _save();
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('account status: $e');
    }
  }

  String infoText(String key, [String fallback = '']) {
    final v = info['public.$key'];
    return v == null ? fallback : (v is String ? v : '$v');
  }
}
