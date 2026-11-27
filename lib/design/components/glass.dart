import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../theme.dart';
import '../motion.dart';
import '../tokens.dart';

/// بطاقة زجاجية خفيفة (Liquid Glass بأسلوب هادئ).
///
/// [blur] = false يرسم سطحًا شفافًا بدون تضبيب، وهو الأفضل داخل القوائم الطويلة
/// لتوفير البطارية. التضبيب يُستخدم فقط فوق الصور والمشاهد الحية.
class AtheerGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? radius;
  final bool blur;
  final double sigma;
  final double fill;
  final Color? tint;
  final bool border;
  final VoidCallback? onTap;

  const AtheerGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AtheerSpacing.lg),
    this.radius,
    this.blur = true,
    this.sigma = 20,
    this.fill = AtheerOpacity.glassFill,
    this.tint,
    this.border = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = radius ?? AtheerRadius.card;
    final c = tint ?? Colors.white;
    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.op(fill + 0.04), c.op(fill)],
        ),
        border: border ? Border.all(color: Colors.white.op(AtheerOpacity.glassBorder), width: 0.8) : null,
      ),
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );
    if (blur) {
      body = ClipRRect(
        borderRadius: r,
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma), child: body),
      );
    }
    if (onTap != null) body = AtheerPressable(onTap: onTap, child: body);
    return body;
  }
}
