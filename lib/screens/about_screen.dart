import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../data/repository.dart';
import '../data/updates.dart';
import '../state/library.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// عن التطبيق: الهوية، رقم الإصدار، والمطوّر.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryStore>();
    final cat = context.watch<ContentRepository>().catalog;
    final gold = MidadColors.saffron;

    return Scaffold(
      backgroundColor: MidadColors.ink,
      body: Stack(children: [
        AmbientGlow(color: gold, alignment: const Alignment(0, -0.75), size: 420, opacity: 0.25),
        const Positioned.fill(child: Starfield(count: 30)),
        SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 30), children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: GlassIconButton(icon: Icons.arrow_back_rounded, tooltip: 'رجوع', onTap: () => Navigator.pop(context)),
            ),
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(38), boxShadow: [
                  BoxShadow(color: gold.op(0.35), blurRadius: 50, spreadRadius: 2),
                ]),
                child: ClipRRect(borderRadius: BorderRadius.circular(38), child: Image.asset('assets/brand/logo.png')),
              ),
            ),
            const SizedBox(height: 18),
            Center(child: Text(AppConfig.appName, style: MidadText.callig(size: 46, color: gold))),
            Center(
              child: Text(AppConfig.appNameLatin,
                  style: MidadText.ui(size: 13, weight: FontWeight.w600, color: Colors.white70).copyWith(letterSpacing: 8)),
            ),
            const SizedBox(height: 6),
            Center(child: Text(AppConfig.tagline, style: MidadText.ui(size: 13, color: Colors.white60))),
            const SizedBox(height: 26),
            _Card(children: [
              _Row(icon: Icons.verified_rounded, label: 'الإصدار', value: '${AppConfig.version}  •  بناء ${arNum(AppConfig.build)}'),
              if (cat != null && cat.version.isNotEmpty) _Row(icon: Icons.auto_stories_rounded, label: 'إصدار المكتبة', value: cat.version),
              _Row(
                icon: Icons.library_books_rounded,
                label: 'المحتوى',
                value: cat == null ? '—' : '${arNum(cat.worlds.length)} عوالم  •  ${arNum(cat.works.length)} عملًا',
              ),
            ]),
            const SizedBox(height: 14),
            _Card(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Text('تصميم وتطوير', style: MidadText.ui(size: 12, color: Colors.white60)),
              ),
              ListTile(
                leading: Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: MidadColors.palette.button,
                    boxShadow: [BoxShadow(color: gold.op(0.4), blurRadius: 14)],
                  ),
                  child: Text('M', style: MidadText.title(size: 20, color: MidadColors.ink)),
                ),
                title: Text(AppConfig.developer, textDirection: TextDirection.ltr, style: MidadText.ui(size: 16, weight: FontWeight.w700)),
                subtitle: Text('Developer & Designer', textDirection: TextDirection.ltr, style: MidadText.ui(size: 12, color: Colors.white60)),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () => launchUrl(Uri.parse(AppConfig.developerGithub), mode: LaunchMode.externalApplication),
              ),
              const SizedBox(height: 6),
            ]),
            const SizedBox(height: 14),
            _Card(children: [
              SwitchListTile(
                value: lib.introSound,
                onChanged: lib.setIntroSound,
                activeColor: gold,
                title: Text('صوت شاشة البداية', style: MidadText.ui(weight: FontWeight.w600)),
                secondary: const Icon(Icons.music_note_rounded),
              ),
              ListTile(
                leading: const Icon(Icons.system_update_rounded),
                title: Text('التحقق من التحديثات', style: MidadText.ui(weight: FontWeight.w600)),
                onTap: () => UpdateService.checkAndPrompt(context, manual: true),
              ),
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: Text('تحديث المكتبة الآن', style: MidadText.ui(weight: FontWeight.w600)),
                onTap: () async {
                  final repo = context.read<ContentRepository>();
                  final messenger = ScaffoldMessenger.of(context);
                  await repo.refreshSilently();
                  messenger.showSnackBar(SnackBar(
                    content: Text(repo.newItems > 0 ? 'وصل ${arNum(repo.newItems)} عمل جديد' : 'المكتبة محدّثة'),
                  ));
                },
              ),
            ]),
            const SizedBox(height: 26),
            Center(
              child: Text('© ${DateTime.now().year} ${AppConfig.developer}', textDirection: TextDirection.ltr, style: MidadText.ui(size: 11, color: Colors.white38)),
            ),
            Center(child: Text('صُنع بحب للحكاية العربية', style: MidadText.ui(size: 11, color: Colors.white38))),
          ]),
        ),
      ]),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) => Glass(
        radius: 22,
        opacity: 0.06,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Row({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Icon(icon, size: 20, color: MidadColors.saffron),
          const SizedBox(width: 12),
          Text(label, style: MidadText.ui(color: Colors.white70)),
          const Spacer(),
          Text(value, style: MidadText.ui(weight: FontWeight.w700)),
        ]),
      );
}
