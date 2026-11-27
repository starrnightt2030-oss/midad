import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// فحص تحديث تطبيق الإدارة (أندرويد فقط؛ نسخة الويب تتحدث لوحدها).
/// يقارن رقم البناء الحالي بأحدث إصدار admin-bN على GitHub Releases.
class AdminUpdates {
  static const _repo = 'starrnightt2030-oss/midad';
  static const int build = int.fromEnvironment('BUILD_NUMBER', defaultValue: 0);
  static bool _shown = false;

  static Future<({int build, String url})?> check() async {
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
      for (final rel in list) {
        final m = RegExp(r'^admin-b(\d+)$').firstMatch((rel['tag_name'] ?? '') as String);
        if (m == null) continue;
        final n = int.parse(m.group(1)!);
        if (n <= best) continue;
        for (final a in (rel['assets'] as List? ?? [])) {
          if (a['name'] == want) {
            best = n;
            url = a['browser_download_url'] as String?;
          }
        }
      }
      if (url == null || best <= build) return null;
      return (build: best, url: url);
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
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.system_update_rounded),
        title: const Text('نسخة جديدة من لوحة الإدارة'),
        content: Text('متاح بناء ${info.build} (عندك بناء $build). نزّله وثبّته فوق النسخة الحالية.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('لاحقًا')),
          FilledButton(
            onPressed: () {
              launchUrl(Uri.parse(info.url), mode: LaunchMode.externalApplication);
              Navigator.pop(ctx);
            },
            child: const Text('تحديث الآن'),
          ),
        ],
      ),
    );
  }
}
