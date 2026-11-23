import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../data/repository.dart';
import '../data/updates.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/cover_art.dart';
import '../widgets/mini_player.dart';
import 'about_screen.dart';
import 'library_screen.dart';
import 'work_screen.dart';
import 'world_screen.dart';

/// الشاشة الرئيسية: كل عالم كوكب، والمسموعات تدور حوله.
class WorldsScreen extends StatefulWidget {
  const WorldsScreen({super.key});

  @override
  State<WorldsScreen> createState() => _WorldsScreenState();
}

class _WorldsScreenState extends State<WorldsScreen> with WidgetsBindingObserver {
  int index = 0;

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
    await repo.refreshSilently();
    if (repo.newItems > 0) {
      messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: MidadColors.surface,
        content: Text('وصل ${arNum(repo.newItems)} ${repo.newItems == 1 ? 'عمل جديد' : 'أعمال جديدة'} إلى مكتبتك', style: MidadText.ui()),
      ));
      repo.newItems = 0;
    }
    if (mounted) UpdateService.checkAndPrompt(context);
  }

  void _go(int i, int n) => setState(() => index = (i % n + n) % n);

  @override
  Widget build(BuildContext context) {
    final cat = context.watch<ContentRepository>().catalog!;
    if (cat.worlds.isEmpty) {
      return const Scaffold(body: Center(child: Text('لا توجد عوالم بعد')));
    }
    final n = cat.worlds.length;
    if (index >= n) index = 0;
    final w = cat.worlds[index];
    final works = cat.worksOf(w.id);

    return Scaffold(
      backgroundColor: MidadColors.ink,
      body: Stack(children: [
        AmbientGlow(color: w.color, alignment: const Alignment(0, -0.2), size: 480, opacity: 0.32),
        const Positioned.fill(child: Starfield()),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).push(fadeRoute(const AboutScreen())),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset('assets/brand/logo.png', width: 44, height: 44),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 800),
                      style: MidadText.callig(size: 26, color: w.color),
                      child: const Text(AppConfig.appName),
                    ),
                    Text('اختر عالمك، واستمع لما يدور حوله', style: MidadText.ui(size: 12, color: Colors.white70)),
                  ]),
                ),
                GlassIconButton(
                  icon: Icons.bookmarks_outlined,
                  tooltip: 'مكتبتي',
                  onTap: () => Navigator.of(context).push(fadeRoute(const LibraryScreen())),
                ),
              ]),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: (d) {
                  final v = d.primaryVelocity ?? 0;
                  if (v > 250) _go(index + 1, n);
                  if (v < -250) _go(index - 1, n);
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 900),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.55, end: 1.0).animate(a),
                      child: RotationTransition(turns: Tween(begin: -0.07, end: 0.0).animate(a), child: child),
                    ),
                  ),
                  child: _Orbit(key: ValueKey(w.id), world: w, works: works),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(children: [
                GlassIconButton(icon: Icons.chevron_left_rounded, tooltip: 'العالم السابق', onTap: () => _go(index - 1, n)),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    transitionBuilder: (c, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(a), child: c),
                    ),
                    child: Column(key: ValueKey(w.id), children: [
                      Text(w.name, textAlign: TextAlign.center, style: MidadText.callig(size: 38, color: w.color).copyWith(shadows: [
                        Shadow(color: w.color.op(0.5), blurRadius: 24),
                      ])),
                      Text(w.tagline, textAlign: TextAlign.center, style: MidadText.ui(size: 13, color: Colors.white70)),
                    ]),
                  ),
                ),
                GlassIconButton(icon: Icons.chevron_right_rounded, tooltip: 'العالم التالي', onTap: () => _go(index + 1, n)),
              ]),
            ),
            const SizedBox(height: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: w.color.op(0.35), blurRadius: 26)]),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: w.color,
                  foregroundColor: MidadColors.ink,
                  minimumSize: const Size(0, 46),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: () => Navigator.of(context).push(fadeRoute(WorldScreen(world: w))),
                child: Text('ادخل العالم · ${arNum(works.length)} ${works.length > 10 || works.length < 3 ? 'عملًا' : 'أعمال'}',
                    style: MidadText.ui(size: 14, weight: FontWeight.w700, color: MidadColors.ink)),
              ),
            ),
            const SizedBox(height: 12),
            const MiniPlayer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Glass(
                radius: 28,
                opacity: 0.06,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: List.generate(n, (i) {
                    final x = cat.worlds[i];
                    final on = i == index;
                    return Expanded(
                      child: Semantics(
                        button: true,
                        selected: on,
                        label: x.name,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _go(i, n),
                          child: Column(children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              width: on ? 44 : 38,
                              height: on ? 44 : 38,
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: on ? x.color : Colors.white24, width: on ? 2 : 1),
                                boxShadow: on ? [BoxShadow(color: x.color.op(0.5), blurRadius: 16)] : null,
                              ),
                              child: CoverArt(art: x.art, shape: BoxShape.circle),
                            ),
                            const SizedBox(height: 5),
                            Text(x.short,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MidadText.ui(size: 10, weight: FontWeight.w600, color: on ? x.color : Colors.white70)),
                          ]),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Orbit extends StatefulWidget {
  final World world;
  final List<Work> works;
  const _Orbit({super.key, required this.world, required this.works});

  @override
  State<_Orbit> createState() => _OrbitState();
}

class _OrbitState extends State<_Orbit> with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  late final AnimationController _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();

  @override
  void dispose() {
    _spin.dispose();
    _float.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.world;
    final items = widget.works.take(6).toList();
    return LayoutBuilder(builder: (context, c) {
      final cx = c.maxWidth / 2;
      final cy = c.maxHeight / 2;
      final planet = math.min(c.maxWidth, c.maxHeight) * 0.36;
      final rx = math.min(c.maxWidth * 0.30, 130.0);
      final ry = c.maxHeight * 0.40;
      final pills = <Widget>[];
      for (var k = 0; k < items.length; k++) {
        final a = (k * (360 / math.max(items.length, 1))) * math.pi / 180;
        final x = cx + rx * math.sin(a);
        final y = cy - ry * math.cos(a);
        final work = items[k];
        pills.add(Positioned(
          left: x - 75,
          top: y - 24,
          width: 150,
          child: AnimatedBuilder(
            animation: Listenable.merge([_float, _enter]),
            builder: (_, child) {
              final start = 0.25 + k * 0.08;
              final t = ((_enter.value - start) / 0.35).clamp(0.0, 1.0);
              final e = Curves.easeOutBack.transform(t);
              final bob = math.sin(_float.value * math.pi * 2 + k * 1.1) * 5;
              return Opacity(
                opacity: t,
                child: Transform.translate(offset: Offset(0, bob + (1 - e) * 20), child: Transform.scale(scale: 0.7 + 0.3 * e, child: child)),
              );
            },
            child: Center(child: _Pill(work: work, color: w.color)),
          ),
        ));
      }
      return Stack(children: [
        Positioned.fill(
          child: CustomPaint(painter: _EllipsePainter(rx, ry)),
        ),
        Positioned(
          left: cx - planet * 0.78,
          top: cy - planet * 0.78,
          width: planet * 1.56,
          height: planet * 1.56,
          child: RotationTransition(turns: _spin, child: CustomPaint(painter: _DashRing(w.color))),
        ),
        Positioned(
          left: cx - planet / 2,
          top: cy - planet / 2,
          width: planet,
          height: planet,
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(fadeRoute(WorldScreen(world: w))),
            child: AnimatedBuilder(
              animation: _float,
              builder: (_, child) {
                final p = 0.5 + 0.5 * math.sin(_float.value * math.pi * 2);
                return Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                    BoxShadow(color: w.color.op(0.35 + 0.25 * p), blurRadius: 40 + 20 * p, spreadRadius: 4),
                  ]),
                  child: child,
                );
              },
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.op(0.35), width: 2)),
                child: Stack(fit: StackFit.expand, children: [
                  CoverArt(art: w.art, shape: BoxShape.circle),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.3, -0.4),
                        colors: [Colors.white.op(0.18), Colors.transparent, Colors.black.op(0.45)],
                        stops: const [0, 0.5, 1],
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
        ...pills,
      ]);
    });
  }
}

class _Pill extends StatelessWidget {
  final Work work;
  final Color color;
  const _Pill({required this.work, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(fadeRoute(WorkScreen(work: work))),
      child: Glass(
        radius: 18,
        opacity: 0.09,
        blur: 14,
        padding: const EdgeInsets.fromLTRB(12, 7, 10, 7),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color, blurRadius: 8)]),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(work.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: MidadText.ui(size: 12, weight: FontWeight.w700)),
              Text('${work.kind} · ${arNum(work.minutes)} د', style: MidadText.ui(size: 10, color: Colors.white70)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _EllipsePainter extends CustomPainter {
  final double rx, ry;
  _EllipsePainter(this.rx, this.ry);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawOval(Rect.fromCenter(center: c, width: rx * 2, height: ry * 2), Paint()
      ..color = Colors.white.op(0.12)
      ..style = PaintingStyle.stroke);
    canvas.drawOval(Rect.fromCenter(center: c, width: rx * 2.6, height: ry * 2.25), Paint()
      ..color = Colors.white.op(0.05)
      ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _EllipsePainter old) => old.rx != rx || old.ry != ry;
}

class _DashRing extends CustomPainter {
  final Color color;
  _DashRing(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 4;
    final p = Paint()
      ..color = color.op(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    const n = 72;
    for (var i = 0; i < n; i++) {
      final a = i * 2 * math.pi / n;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), a, 0.02, false, p);
    }
    canvas.drawCircle(c + Offset(0, -r), 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _DashRing old) => old.color != color;
}
