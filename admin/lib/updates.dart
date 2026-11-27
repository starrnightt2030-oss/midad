import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:url_launcher/url_launcher.dart';

/// فحص تحديث تطبيق الإدارة (أندرويد فقط؛ نسخة الويب تتحدث لوحدها).
/// يقارن رقم البناء الحالي بأحدث إصدار admin-bN على GitHub Releases.
class AdminUpdates {
  static const _repo = 'starrnightt2030-oss/midad';
  static const int build = int.fromEnvironment('BUILD_NUMBER', defaultValue: 0);
  static bool _shown = false;

  static Future<({int build, String url, String? sha256})?> check() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android || build == 0) return null;
    try {
      final r = await http
          .get(Uri.parse('https://api.github.com/repos/$_repo/releases?per_page=40'), headers: {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      final list = jsonDecode(utf8.decode(r.bodyBytes)) as List;
      // الموبايلات القديمة (٣٢ بت) تأخذ نسخة armv7، والباقي arm64.
      final want = Platform.version.contains('android_arm"') ? 'atheer-admin-armv7.apk' : 'atheer-admin.apk';
      int best = 0;
      String? url;
      String? sha;
      for (final rel in list) {
        final m = RegExp(r'^admin-b(\d+)$').firstMatch((rel['tag_name'] ?? '') as String);
        if (m == null) continue;
        final n = int.parse(m.group(1)!);
        if (n <= best) continue;
        for (final a in (rel['assets'] as List? ?? [])) {
          if (a['name'] == want) {
            best = n;
            url = a['browser_download_url'] as String?;
            final d = a['digest'] as String?;
            sha = d != null && d.startsWith('sha256:') ? d.substring(7) : null;
          }
        }
      }
      if (url == null || best <= build) return null;
      return (build: best, url: url, sha256: sha);
    } catch (_) {
      return null;
    }
  }

  static Future<void> checkAndPrompt(BuildContext context) async {
    if (_shown) return;
    final info = await check();
    if (info == null || !context.mounted) return;
    _shown = true;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UpdateDialog(build: info.build, url: info.url, sha256: info.sha256),
    );
  }
}

/// ينزّل التحديث داخل التطبيق بشريط تقدم ثم يفتح شاشة التثبيت.
class _UpdateDialog extends StatefulWidget {
  final int build;
  final String url;
  final String? sha256;
  const _UpdateDialog({required this.build, required this.url, this.sha256});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  StreamSubscription<OtaEvent>? _sub;
  double? _progress;
  String? _status;
  bool _failed = false;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _progress = 0;
      _failed = false;
      _status = 'جاري التنزيل…';
    });
    try {
      _sub = OtaUpdate()
          .execute(widget.url, destinationFilename: 'atheer-admin-update.apk', sha256checksum: widget.sha256)
          .listen(_onEvent, onError: (_) => _fail('تعذّر التنزيل. تأكد من الإنترنت وحاول تاني.'));
    } catch (_) {
      _fail('تعذّر بدء التنزيل.');
    }
  }

  void _onEvent(OtaEvent e) {
    if (!mounted) return;
    switch (e.status) {
      case OtaStatus.DOWNLOADING:
        final p = double.tryParse(e.value ?? '') ?? 0;
        setState(() {
          _progress = p / 100;
          _status = 'جاري التنزيل… ${p.toStringAsFixed(0)}٪';
        });
      case OtaStatus.INSTALLING:
        setState(() {
          _progress = 1;
          _status = 'اكتمل التنزيل. اضغط «تثبيت» في الشاشة اللي ظهرت.';
        });
      case OtaStatus.INSTALLATION_DONE:
        setState(() => _status = 'تم التحديث ✓');
      case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
        _fail('لازم تسمح للتطبيق بتثبيت التطبيقات من الإعدادات، وبعدين حاول تاني.');
      case OtaStatus.CHECKSUM_ERROR:
        _fail('الملف وصل ناقص أو تالف. حاول تاني.');
      case OtaStatus.ALREADY_RUNNING_ERROR:
        setState(() => _status = 'التنزيل شغال بالفعل…');
      default:
        _fail('حصلت مشكلة في التحديث${e.value == null ? '' : ' (${e.value})'}.');
    }
  }

  void _fail(String msg) {
    if (!mounted) return;
    setState(() {
      _failed = true;
      _progress = null;
      _status = msg;
    });
  }

  @override
  Widget build(BuildContext context) {
    final downloading = _progress != null && !_failed;
    return AlertDialog(
      icon: const Icon(Icons.system_update_rounded),
      title: const Text('نسخة جديدة من لوحة الإدارة'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('متاح بناء ${widget.build} (عندك بناء ${AdminUpdates.build}).'),
        if (_status != null) ...[
          const SizedBox(height: 12),
          Text(_status!, textAlign: TextAlign.center, style: TextStyle(color: _failed ? Colors.redAccent : null)),
        ],
        if (downloading) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(value: _progress == 0 ? null : _progress, minHeight: 8),
        ],
      ]),
      actions: [
        if (_failed)
          TextButton(
            onPressed: () => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
            child: const Text('من المتصفح'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(downloading ? 'إخفاء' : 'لاحقًا')),
        if (!downloading) FilledButton(onPressed: _start, child: const Text('تحديث الآن')),
      ],
    );
  }
}
