import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../theme.dart';

class UpdateInfo {
  final String version;
  final int build;
  final String apkUrl;
  final String notes;
  UpdateInfo(this.version, this.build, this.apkUrl, this.notes);
}

/// يتحقق من آخر إصدار على GitHub Releases ويقارنه برقم البناء الحالي.
class UpdateService {
  static bool _shownThisSession = false;

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
      String? apk;
      for (final a in (j['assets'] as List? ?? [])) {
        final name = (a['name'] ?? '') as String;
        if (name.endsWith('.apk')) apk = a['browser_download_url'] as String?;
      }
      if (apk == null) return null;
      if (build <= AppConfig.build) return null;
      return UpdateInfo(version, build, apk, (j['body'] ?? '') as String);
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

class _UpdateSheet extends StatelessWidget {
  final UpdateInfo info;
  const _UpdateSheet({required this.info});

  @override
  Widget build(BuildContext context) {
    final notes = info.notes.trim();
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1A2440), MidadColors.ink]),
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
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: MidadColors.saffron,
              foregroundColor: MidadColors.ink,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
            ),
            onPressed: () {
              launchUrl(Uri.parse(info.apkUrl), mode: LaunchMode.externalApplication);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.system_update_rounded),
            label: Text('تحديث الآن', style: MidadText.ui(weight: FontWeight.w700, color: MidadColors.ink)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: Text('لاحقًا', style: MidadText.ui(color: Colors.white70))),
        ]),
      ),
    );
  }
}
