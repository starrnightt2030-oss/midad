import 'package:flutter/material.dart';

import '../api.dart';
import 'members.dart';
import 'settings.dart';
import 'works.dart';
import 'worlds.dart';

/// الهيكل: قائمة جانبية على الشاشات الواسعة، وشريط سفلي على الموبايل.
class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int tab = 0;

  static const _dest = [
    (icon: Icons.auto_stories_outlined, active: Icons.auto_stories_rounded, label: 'القصص'),
    (icon: Icons.grid_view_outlined, active: Icons.grid_view_rounded, label: 'الأقسام'),
    (icon: Icons.people_outline_rounded, active: Icons.people_rounded, label: 'المستمعون'),
    (icon: Icons.tune_outlined, active: Icons.tune_rounded, label: 'الإعدادات'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final page = switch (tab) { 0 => const WorksPage(), 1 => const WorldsPage(), 2 => const MembersPage(), _ => const SettingsPage() };
    final actions = [
      IconButton(tooltip: 'تسجيل الخروج', onPressed: () => db.auth.signOut(), icon: const Icon(Icons.logout_rounded)),
    ];
    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('أثير', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            ),
            trailing: Expanded(child: Align(alignment: Alignment.bottomCenter, child: Padding(padding: const EdgeInsets.all(12), child: actions.first))),
            destinations: [for (final d in _dest) NavigationRailDestination(icon: Icon(d.icon), selectedIcon: Icon(d.active), label: Text(d.label))],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: page),
        ]),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(_dest[tab].label), actions: actions),
      body: page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: [for (final d in _dest) NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.active), label: d.label)],
      ),
    );
  }
}

/// رأس صفحة موحّد مع زر إضافة.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const PageHeader({super.key, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            if (subtitle != null) Text(subtitle!, style: t.bodyMedium?.copyWith(color: Colors.white60)),
          ]),
        ),
        if (action != null) action!,
      ]),
    );
  }
}

void toast(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));

Future<bool> confirm(BuildContext context, String title, String body, {String ok = 'حذف'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error),
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r == true;
}
