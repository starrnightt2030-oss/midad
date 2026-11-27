import 'package:flutter/material.dart';

import '../../theme.dart';
import '../motion.dart';
import '../tokens.dart';
import 'buttons.dart';

/// هيكل تحميل بلمعة هادئة (بدل مؤشر الدوران). يتوقف عن الحركة عند تقليل الحركة.
class AtheerSkeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? radius;
  final bool circle;

  const AtheerSkeleton({super.key, this.width, this.height, this.radius, this.circle = false});

  /// سطر نص وهمي أثناء التحميل.
  const AtheerSkeleton.line({super.key, this.width, this.height = 12})
      : radius = const BorderRadius.all(Radius.circular(6)),
        circle = false;

  @override
  State<AtheerSkeleton> createState() => _AtheerSkeletonState();
}

class _AtheerSkeletonState extends State<AtheerSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AtheerMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Colors.white.op(0.06);
    final hi = Colors.white.op(0.12);
    return Semantics(
      label: 'جارِ التحميل',
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final t = _c.value * 2 - 0.5;
            return Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: widget.circle ? null : (widget.radius ?? AtheerRadius.tile),
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [base, hi, base],
                  stops: [(t - 0.3).clamp(0.0, 1.0), t.clamp(0.0, 1.0), (t + 0.3).clamp(0.0, 1.0)],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// حالة فارغة هادئة: أيقونة في هالة، عنوان، وصف، وزر اختياري.
class AtheerEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AtheerEmptyState({super.key, required this.icon, required this.title, this.message, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AtheerSpacing.huge, vertical: AtheerSpacing.xxxl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [AtheerColors.accent.op(0.20), AtheerColors.accent.op(0.0)]),
            ),
            child: Icon(icon, size: AtheerIconSize.xl, color: AtheerColors.accent),
          ),
          const SizedBox(height: AtheerSpacing.lg),
          Text(title, textAlign: TextAlign.center, style: AtheerType.h3()),
          if (message != null) ...[
            const SizedBox(height: AtheerSpacing.sm),
            Text(message!, textAlign: TextAlign.center, style: AtheerType.bodyMedium()),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AtheerSpacing.xxl),
            AtheerSecondaryButton(label: actionLabel!, onPressed: onAction),
          ],
        ]),
      ),
    );
  }
}

/// حالة خطأ بلطف، مع زر «إعادة المحاولة».
class AtheerErrorState extends StatelessWidget {
  final String title;
  final String? message;
  final VoidCallback? onRetry;

  const AtheerErrorState({super.key, this.title = 'تعذّر التحميل', this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AtheerEmptyState(
      icon: Icons.cloud_off_rounded,
      title: title,
      message: message ?? 'تأكد من اتصالك بالإنترنت ثم حاول مرة أخرى.',
      actionLabel: onRetry == null ? null : 'إعادة المحاولة',
      onAction: onRetry,
    );
  }
}

/// ورقة سفلية بنفس الهوية: مقبض، عنوان اختياري، ومحتوى.
class AtheerBottomSheet extends StatelessWidget {
  final String? title;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AtheerBottomSheet({
    super.key,
    this.title,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(AtheerSpacing.gutter, 0, AtheerSpacing.gutter, AtheerSpacing.xxl),
  });

  /// يفتح ورقة سفلية بحركة ناعمة.
  static Future<T?> show<T>(BuildContext context, {String? title, required WidgetBuilder builder, bool scrollable = true}) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: scrollable,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AtheerColors.midnight.op(AtheerOpacity.scrim),
      sheetAnimationStyle: AnimationStyle(
          duration: AtheerMotion.of(context, const Duration(milliseconds: 420)),
          reverseDuration: AtheerMotion.of(context, AtheerMotion.normal),
          curve: AtheerMotion.emphasized),
      builder: (c) => AtheerBottomSheet(title: title, child: builder(c)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: AtheerRadius.sheet,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AtheerColors.surfaceHigh, AtheerColors.background],
        ),
        border: Border(top: BorderSide(color: Colors.white.op(AtheerOpacity.glassBorder))),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: AtheerSpacing.md, bottom: AtheerSpacing.lg),
              width: 38,
              height: 4,
              decoration: BoxDecoration(color: Colors.white.op(0.22), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(AtheerSpacing.gutter, 0, AtheerSpacing.gutter, AtheerSpacing.lg),
              child: Semantics(header: true, child: Text(title!, style: AtheerType.h3())),
            ),
          Flexible(child: Padding(padding: padding, child: child)),
        ]),
      ),
    );
  }
}
