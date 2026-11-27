import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repository.dart';
import '../data/updates.dart';
import '../state/account.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/mini_player.dart';
import '../widgets/story_card.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'more_screen.dart';
import 'world_screen.dart';
import 'worlds_screen.dart';

/// الهيكل الرئيسي: أربع تبويبات وشريط سفلي، والمشغّل المصغّر فوقه.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int tab = 0;

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

  void _openWorld(String id) => Navigator.of(context).push(fadeRoute(WorldScreen(worldId: id)));

  static const _items = [
    (icon: Icons.home_outlined, active: Icons.home_rounded, label: 'الرئيسية'),
    (icon: Icons.auto_awesome_mosaic_outlined, active: Icons.auto_awesome_mosaic_rounded, label: 'العوالم'),
    (icon: Icons.bookmarks_outlined, active: Icons.bookmarks_rounded, label: 'مكتبتي'),
    (icon: Icons.more_horiz_rounded, active: Icons.more_horiz_rounded, label: 'المزيد'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onOpenWorld: _openWorld),
      const WorldsScreen(),
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
          const MiniPlayer(),
          _NavBar(index: tab, onTap: (i) => setState(() => tab = i)),
        ]),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _NavBar({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = MidadColors.palette;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: p.bg.op(0.88),
            border: Border(top: BorderSide(color: Colors.white.op(0.06))),
          ),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Row(children: [
                for (var i = 0; i < _HomeShellState._items.length; i++)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: i == index,
                      label: _HomeShellState._items[i].label,
                      child: InkResponse(
                        onTap: () => onTap(i),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const SizedBox(height: 6),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: i == index ? p.accent.op(0.18) : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(i == index ? _HomeShellState._items[i].active : _HomeShellState._items[i].icon,
                                color: i == index ? p.accent : Colors.white60, size: 24),
                          ),
                          const SizedBox(height: 4),
                          Text(_HomeShellState._items[i].label,
                              style: MidadText.ui(
                                  size: 11,
                                  weight: i == index ? FontWeight.w700 : FontWeight.w500,
                                  color: i == index ? Colors.white : Colors.white60)),
                          const SizedBox(height: 6),
                        ]),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
