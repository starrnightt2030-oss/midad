import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// نظام الحركة الموحّد لأثير (AtheerMotionSystem).
///
/// حركات هادئة وطبيعية: الحركات العادية بين 180 و350ms، والانتقالات السينمائية
/// أطول قليلًا. كل شيء يحترم إعداد «تقليل الحركة» في النظام وفي التطبيق.
class AtheerMotion {
  AtheerMotion._();

  // المُدد.
  static const instant = Duration(milliseconds: 120);
  static const fast = Duration(milliseconds: 180);
  static const normal = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 350);
  static const cinematic = Duration(milliseconds: 600);
  static const ambient = Duration(milliseconds: 1200);

  /// تأخير بين العناصر المتتالية (Staggered).
  static const stagger = Duration(milliseconds: 50);

  // المنحنيات (عضوية وناعمة).
  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve organic = Cubic(0.33, 0.0, 0.15, 1.0);
  static const Curve exit = Curves.easeInCubic;
  static const Curve gentle = Curves.easeInOutSine;

  /// تقليل الحركة من داخل التطبيق (يُضبط من الإعدادات لاحقًا).
  static final reduceMotion = ValueNotifier<bool>(false);

  /// هل يجب تقليل الحركة الآن؟ (النظام أو التطبيق).
  static bool reduced(BuildContext context) => reduceMotion.value || (MediaQuery.maybeOf(context)?.disableAnimations ?? false);

  /// المدة الفعلية بعد احترام تقليل الحركة.
  static Duration of(BuildContext context, Duration d) => reduced(context) ? Duration.zero : d;

  /// مسافة الإزاحة الفعلية (صفر عند تقليل الحركة).
  static double offset(BuildContext context, double px) => reduced(context) ? 0 : px;

  // اهتزاز خفيف.
  static void tap() => HapticFeedback.selectionClick();
  static void confirm() => HapticFeedback.lightImpact();

  /// انتقال صفحات: تلاشي متقاطع مع ارتفاع خفيف.
  static Route<T> fadeThrough<T>(Widget page, {RouteSettings? settings}) => PageRouteBuilder<T>(
        settings: settings,
        transitionDuration: cinematic,
        reverseTransitionDuration: slow,
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (context, a, __, child) {
          if (reduced(context)) return FadeTransition(opacity: a, child: child);
          final c = CurvedAnimation(parent: a, curve: organic, reverseCurve: exit);
          return FadeTransition(
            opacity: c,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(c),
              child: child,
            ),
          );
        },
      );

  /// انتقال من الأسفل (المشغّل والأوراق).
  static Route<T> rise<T>(Widget page, {RouteSettings? settings}) => PageRouteBuilder<T>(
        settings: settings,
        transitionDuration: const Duration(milliseconds: 480),
        reverseTransitionDuration: slow,
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (context, a, __, child) {
          if (reduced(context)) return FadeTransition(opacity: a, child: child);
          final c = CurvedAnimation(parent: a, curve: emphasized, reverseCurve: exit);
          return SlideTransition(position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(c), child: child);
        },
      );
}

/// يظهر العنصر بتلاشي وارتفاع خفيف، مع تأخير حسب ترتيبه (Staggered).
class AtheerReveal extends StatefulWidget {
  final Widget child;
  final int index;
  final double rise;
  final Duration duration;

  const AtheerReveal({super.key, required this.child, this.index = 0, this.rise = 14, this.duration = AtheerMotion.slow});

  @override
  State<AtheerReveal> createState() => _AtheerRevealState();
}

class _AtheerRevealState extends State<AtheerReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    final delay = AtheerMotion.stagger * widget.index.clamp(0, 8);
    Future.delayed(delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AtheerMotion.reduced(context)) _c.value = 1;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(parent: _c, curve: AtheerMotion.organic);
    return AnimatedBuilder(
      animation: a,
      child: widget.child,
      builder: (_, child) => Opacity(
        opacity: a.value,
        child: Transform.translate(offset: Offset(0, widget.rise * (1 - a.value)), child: child),
      ),
    );
  }
}

/// تصغير بسيط عند الضغط (إحساس ملموس بدون مبالغة).
class AtheerPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;

  const AtheerPressable({super.key, required this.child, this.onTap, this.onLongPress, this.scale = 0.97, this.haptic = true});

  @override
  State<AtheerPressable> createState() => _AtheerPressableState();
}

class _AtheerPressableState extends State<AtheerPressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) AtheerMotion.tap();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down && !AtheerMotion.reduced(context) ? widget.scale : 1,
        duration: AtheerMotion.fast,
        curve: AtheerMotion.standard,
        child: widget.child,
      ),
    );
  }
}
