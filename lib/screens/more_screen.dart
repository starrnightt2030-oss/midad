import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../data/updates.dart';
import '../state/library.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'about_screen.dart';

/// المزيد: اختيار الثيم، حجم الخط، والإعدادات العامة.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryStore>();
    final themes = context.watch<ThemeController>();
    return SafeArea(
      bottom: false,
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 24), children: [
        Text('المزيد', style: MidadText.title(size: 26)),
        const SizedBox(height: 20),
        Text('ألوان التطبيق', style: MidadText.ui(size: 13, color: Colors.white60)),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.55,
          children: [
            for (final p in AtheerPalettes.all)
              _ThemeTile(palette: p, selected: themes.palette.id == p.id, onTap: () => themes.set(p)),
          ],
        ),
        const SizedBox(height: 22),
        _Section(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(children: [
              const Icon(Icons.format_size_rounded, size: 20),
              const SizedBox(width: 12),
              Text('حجم خط القراءة', style: MidadText.ui(weight: FontWeight.w600)),
            ]),
          ),
          Slider(value: lib.fontScale, min: 0.8, max: 1.5, divisions: 7, onChanged: lib.setFontScale),
          SwitchListTile(
            value: lib.introSound,
            onChanged: lib.setIntroSound,
            activeThumbColor: MidadColors.accent,
            title: Text('صوت شاشة البداية', style: MidadText.ui(weight: FontWeight.w600)),
            secondary: const Icon(Icons.music_note_rounded),
          ),
        ]),
        const SizedBox(height: 14),
        _Section(children: [
          ListTile(
            leading: const Icon(Icons.system_update_rounded),
            title: Text('التحقق من التحديثات', style: MidadText.ui(weight: FontWeight.w600)),
            onTap: () => UpdateService.checkAndPrompt(context, manual: true),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: Text('عن ${AppConfig.appName}', style: MidadText.ui(weight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_left_rounded),
            onTap: () => Navigator.of(context).push(fadeRoute(const AboutScreen())),
          ),
        ]),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  final List<Widget> children;
  const _Section({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: MidadColors.surface.op(0.85),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.op(0.06)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

class _ThemeTile extends StatelessWidget {
  final AtheerPalette palette;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeTile({required this.palette, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'ثيم ${palette.name}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            gradient: palette.background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? palette.accent : Colors.white.op(0.08), width: selected ? 2 : 1),
            boxShadow: selected ? [BoxShadow(color: palette.accent.op(0.3), blurRadius: 16)] : null,
          ),
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 22, height: 22, decoration: BoxDecoration(shape: BoxShape.circle, gradient: palette.button)),
              const SizedBox(width: 6),
              Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: palette.surfaceHigh)),
              const Spacer(),
              if (selected) Icon(Icons.check_circle_rounded, color: palette.accent, size: 20),
            ]),
            const Spacer(),
            Text(palette.name, style: MidadText.ui(size: 14, weight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}
