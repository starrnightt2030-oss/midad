import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repository.dart';
import '../design/atheer_design_system.dart';
import '../data/updates.dart';
import '../state/account.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/story_card.dart';
import 'categories_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'more_screen.dart';

/// الهيكل الرئيسي: أربع تبويبات وشريط سفلي، والمشغّل المصغّر فوقه.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int tab = 0;
  String? worldId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) UpdateService.checkAndPrompt(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// كل مرة يرجع المستخدم للتطبيق: نحدّث المكتبة بصمت ونتحقق من إصدار جديد.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state != AppLifecycleState.resumed) return;
    final repo = context.read<ContentRepository>();
    final messenger = ScaffoldMessenger.of(context);
    context.read<AccountStore>().refreshStatus();
    await repo.refreshSilently();
    if (repo.newItems > 0) {
      messenger.showSnackBar(SnackBar(
        content: Text('وصل ${arNum(repo.newItems)} ${repo.newItems == 1 ? 'عمل جديد' : 'أعمال جديدة'} إلى مكتبتك', style: MidadText.ui()),
      ));
      repo.newItems = 0;
    }
    if (mounted) UpdateService.checkAndPrompt(context);
  }

  void _openWorld(String id) => setState(() {
        worldId = id;
        tab = 1;
      });

  static const _items = [
    AtheerNavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'الرئيسية'),
    AtheerNavItem(icon: Icons.auto_awesome_mosaic_outlined, activeIcon: Icons.auto_awesome_mosaic_rounded, label: 'الأقسام'),
    AtheerNavItem(icon: Icons.bookmarks_outlined, activeIcon: Icons.bookmarks_rounded, label: 'مكتبتي'),
    AtheerNavItem(icon: Icons.more_horiz_rounded, activeIcon: Icons.more_horiz_rounded, label: 'المزيد'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onOpenWorld: _openWorld),
      CategoriesScreen(worldId: worldId, onSelect: (id) => setState(() => worldId = id)),
      const LibraryScreen(),
      const MoreScreen(),
    ];
    return PopScope(
      canPop: tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => tab = 0);
      },
      child: Scaffold(
        backgroundColor: MidadColors.ink,
        body: AtheerBackground(child: IndexedStack(index: tab, children: pages)),
        bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
          const AtheerMiniPlayer(),
          AtheerBottomNavigation(items: _items, index: tab, onTap: (i) => setState(() => tab = i)),
        ]),
      ),
    );
  }
}
