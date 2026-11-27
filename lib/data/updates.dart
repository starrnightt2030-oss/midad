import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../theme.dart';

class UpdateInfo {
  final String version;
  final int build;
  final String apkUrl;
  final String notes;
  /// بصمة sha256 للملف من GitHub: نتأكد إن التنزيل كامل وسليم قبل التثبيت.
  final String? sha256;
  UpdateInfo(this.version, this.build, this.apkUrl, this.notes, [this.sha256]);
}

/// يتحقق من آخر إصدار على GitHub Releases ويقارنه برقم البناء الحالي.
class UpdateService {
  static bool _shownThisSession = false;

  /// الموبايلات القديمة (٣٢ بت) تأخذ atheer-armv7.apk، والباقي atheer.apk (arm64).
  static String _apkNameForDevice() {
    final v = Platform.version; // ينتهي بـ on "android_arm64" أو "android_arm"
    return v.contains('android_arm"') ? 'atheer-armv7.apk' : 'atheer.apk';
  }

  static Future<UpdateInfo?> check() async {
    try {
      final r = await http
          .get(Uri.parse('https://api.github.com/repos/${AppConfig.githubRepo}/releases/latest'), headers: {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      final tag = (j['tag_name'] ?? '') as String; // مثال: v1.0.0-b12
      final m = RegExp(r'v?([\d.]+)(?:[-+]b?(\d+))?').firstMatch(tag);
      if (m == null) return null;
      final version = m.group(1)!;
      final build = int.tryParse(m.group(2) ?? '') ?? 0;
      // كل إصدار فيه نسخة لكل نوع معالج؛ نختار المناسبة لهذا الموبايل.
      final urls = <String, String>{};
      final digests = <String, String>{};
      for (final a in (j['assets'] as List? ?? [])) {
        final name = (a['name'] ?? '') as String;
        final url = a['browser_download_url'] as String?;
        if (name.endsWith('.apk') && url != null) urls[name] = url;
        final d = a['digest'] as String?;
        if (d != null && d.startsWith('sha256:')) digests[name] = d.substring(7);
      }
      final name = urls.containsKey(_apkNameForDevice()) ? _apkNameForDevice() : 'atheer.apk';
      final apk = urls[name];
      if (apk == null) return null;
      if (build <= AppConfig.build) return null;
      return UpdateInfo(version, build, apk, (j['body'] ?? '') as String, digests[name]);
    } catch (_) {
      return null;
    }
  }

  static Future<void> checkAndPrompt(BuildContext context, {bool manual = false}) async {
    if (_shownThisSession && !manual) return;
    final info = await check();
    if (!context.mounted) return;
    if (info == null) {
      if (manual) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أنت على أحدث إصدار')));
      }
      return;
    }
    _shownThisSession = true;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UpdateSheet(info: info),
    );
  }
}

class _UpdateSheet extends StatefulWidget {
  final UpdateInfo info;
  const _UpdateSheet({required this.info});

  @override
  State<_UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<_UpdateSheet> {
  UpdateInfo get info => widget.info;
  StreamSubscription<OtaEvent>? _sub;
  double? _progress; // null = لم يبدأ التنزيل
  String? _status;
  bool _failed = false;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// ينزّل التحديث داخل التطبيق بشريط تقدم، ثم يفتح شاشة التثبيت مباشرة.
  void _start() {
    setState(() {
      _progress = 0;
      _failed = false;
      _status = 'جاري التنزيل…';
    });
    try {
      _sub = OtaUpdate()
          .execute(info.apkUrl, destinationFilename: 'atheer-update.apk', sha256checksum: info.sha256)
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
        _fail('لازم تسمح لأثير بتثبيت التطبيقات من الإعدادات، وبعدين اضغط «تحديث الآن» تاني.');
      case OtaStatus.CHECKSUM_ERROR:
        _fail('الملف وصل ناقص أو تالف. اضغط «تحديث الآن» تاني.');
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
    // ملاحظات الإصدار تأتي من رسالة الـ commit؛ نحذف سطور التوقيع التقنية.
    final notes = info.notes
        .split('\n')
        .where((l) => !RegExp(r'^\s*(Co-Authored-By|Claude-Session|Signed-off-by):', caseSensitive: false).hasMatch(l))
        .join('\n')
        .trim();
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [MidadColors.inkTop, MidadColors.ink]),
        border: Border.all(color: MidadColors.saffron.op(0.35)),
        boxShadow: [BoxShadow(color: MidadColors.saffron.op(0.2), blurRadius: 40)],
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(borderRadius: BorderRadius.circular(22), child: Image.asset('assets/brand/logo.png', width: 92, height: 92)),
          const SizedBox(height: 14),
          Text('إصدار جديد من ${AppConfig.appName}', style: MidadText.title(size: 22, color: MidadColors.saffron)),
          const SizedBox(height: 4),
          Text('الإصدار ${info.version}  •  بناء ${info.build}', style: MidadText.ui(size: 12, color: Colors.white70)),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: SingleChildScrollView(child: Text(notes, textAlign: TextAlign.center, style: MidadText.ui(size: 13, color: Colors.white.op(0.85), height: 1.7))),
            ),
          ],
          const SizedBox(height: 20),
          if (_status != null) ...[
            Text(_status!, textAlign: TextAlign.center, style: MidadText.ui(size: 13, color: _failed ? const Color(0xFFFF8A80) : Colors.white)),
            const SizedBox(height: 10),
          ],
          if (_progress != null && !_failed) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress == 0 ? null : _progress,
                minHeight: 10,
                backgroundColor: Colors.white12,
                color: MidadColors.saffron,
              ),
            ),
            const SizedBox(height: 14),
          ] else
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: MidadColors.saffron,
              foregroundColor: MidadColors.ink,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
            ),
            onPressed: _start,
            icon: const Icon(Icons.system_update_rounded),
            label: Text('تحديث الآن', style: MidadText.ui(weight: FontWeight.w700, color: MidadColors.ink)),
          ),
          if (_failed)
            TextButton(
              onPressed: () => launchUrl(Uri.parse(info.apkUrl), mode: LaunchMode.externalApplication),
              child: Text('تنزيل من المتصفح بدلًا من ذلك', style: MidadText.ui(size: 12, color: Colors.white60)),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: Text(_progress != null && !_failed ? 'إخفاء' : 'لاحقًا', style: MidadText.ui(color: Colors.white70))),
        ]),
      ),
    );
  }
}
