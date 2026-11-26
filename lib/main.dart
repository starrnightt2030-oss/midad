import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'data/repository.dart';
import 'screens/splash_screen.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'state/library.dart';
import 'state/audio_handler.dart';
import 'state/player.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themes = ThemeController();
  await themes.load();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: MidadColors.ink,
  ));
  final repo = ContentRepository();
  final library = LibraryStore();
  final player = PlayerController(repo);
  player.attachMedia(await initAudioHandler());
  repo.load();
  library.load();
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: repo),
      ChangeNotifierProvider.value(value: library),
      ChangeNotifierProvider.value(value: player),
      ChangeNotifierProvider.value(value: themes),
    ],
    child: const AtheerApp(),
  ));
}

class AtheerApp extends StatefulWidget {
  const AtheerApp({super.key});

  @override
  State<AtheerApp> createState() => _AtheerAppState();
}

class _AtheerAppState extends State<AtheerApp> {
  ThemeController? _themes;
  String? _themeId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final t = context.read<ThemeController>();
    if (_themes != t) {
      _themes?.removeListener(_onTheme);
      _themes = t..addListener(_onTheme);
      _themeId = t.palette.id;
    }
  }

  /// عند تغيير الثيم: نعيد رسم كل الشاشات المفتوحة بالألوان الجديدة.
  void _onTheme() {
    if (_themes?.palette.id == _themeId) return;
    _themeId = _themes?.palette.id;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: MidadColors.ink,
    ));
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) rebuildAllChildren(context);
    });
  }

  @override
  void dispose() {
    _themes?.removeListener(_onTheme);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _Gate(),
    );
  }
}

class _Gate extends StatefulWidget {
  const _Gate();

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  bool _splashDone = false;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<ContentRepository>();
    final lib = context.watch<LibraryStore>();
    final ready = _splashDone && !repo.loading && repo.catalog != null && lib.loaded;
    Widget child;
    if (ready && !lib.onboarded) {
      child = const OnboardingScreen(key: ValueKey('onboarding'));
    } else if (ready) {
      child = const HomeShell(key: ValueKey('home'));
    } else if (_splashDone && repo.error != null) {
      child = _ErrorView(key: const ValueKey('err'), message: repo.error!, onRetry: () => repo.load());
    } else {
      child = CinematicSplash(key: const ValueKey('splash'), onDone: () => setState(() => _splashDone = true));
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 1100),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 1.08, end: 1.0).animate(a), child: c),
      ),
      child: child,
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MidadColors.ink,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(borderRadius: BorderRadius.circular(30), child: Image.asset('assets/brand/logo.png', width: 120)),
          const SizedBox(height: 20),
          Text(message, style: MidadText.ui(color: Colors.white70)),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
        ]),
      ),
    );
  }
}
