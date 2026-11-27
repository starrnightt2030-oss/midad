import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../theme.dart';
import '../motion.dart';
import '../tokens.dart';

/// الزر الرئيسي: تدرّج اللون المميّز، نص داكن واضح، وتوهّج خفيف.
class AtheerPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expanded;
  final double height;

  const AtheerPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expanded = false,
    this.height = 54,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final fg = AtheerColors.background;
    final content = Row(mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
      if (loading)
        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: fg))
      else if (icon != null)
        Icon(icon, color: fg, size: AtheerIconSize.md),
      if (loading || icon != null) const SizedBox(width: AtheerSpacing.sm),
      Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AtheerType.button(color: fg))),
    ]);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: AtheerPressable(
        onTap: enabled ? onPressed : null,
        child: AnimatedOpacity(
          duration: AtheerMotion.fast,
          opacity: enabled ? 1 : AtheerOpacity.disabled + 0.2,
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: AtheerSpacing.xxl),
            decoration: BoxDecoration(
              gradient: AtheerGradients.accent,
              borderRadius: BorderRadius.circular(height / 2),
              boxShadow: enabled ? AtheerElevation.glow() : null,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// زر ثانوي شفاف بحدّ ناعم.
class AtheerSecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;

  const AtheerSecondaryButton({super.key, required this.label, required this.onPressed, this.icon, this.height = 48});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: AtheerPressable(
        onTap: onPressed,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: AtheerSpacing.xl),
          decoration: BoxDecoration(
            color: Colors.white.op(AtheerOpacity.glassFill),
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(color: Colors.white.op(AtheerOpacity.glassBorder)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: AtheerIconSize.sm, color: AtheerColors.textPrimary), const SizedBox(width: AtheerSpacing.sm)],
            Text(label, style: AtheerType.label()),
          ]),
        ),
      ),
    );
  }
}

enum AtheerIconButtonStyle { glass, tonal, plain, accent }

/// زر أيقونة دائري. مساحة اللمس لا تقل عن 48 حتى لو كان الشكل أصغر.
class AtheerIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final AtheerIconButtonStyle style;
  final Color? color;
  final bool selected;

  const AtheerIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 44,
    this.style = AtheerIconButtonStyle.glass,
    this.color,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AtheerColors.accent;
    final fg = color ??
        switch (style) {
          AtheerIconButtonStyle.accent => AtheerColors.background,
          _ => selected ? accent : AtheerColors.textPrimary,
        };
    Widget shape = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: switch (style) {
        AtheerIconButtonStyle.glass => BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.op(selected ? 0.16 : 0.08),
            border: Border.all(color: Colors.white.op(AtheerOpacity.glassBorder), width: 0.8),
          ),
        AtheerIconButtonStyle.tonal => BoxDecoration(shape: BoxShape.circle, color: accent.op(selected ? 0.24 : 0.14)),
        AtheerIconButtonStyle.accent => BoxDecoration(shape: BoxShape.circle, gradient: AtheerGradients.accent, boxShadow: AtheerElevation.glow()),
        AtheerIconButtonStyle.plain => const BoxDecoration(shape: BoxShape.circle),
      },
      child: Icon(icon, size: size * 0.48, color: fg),
    );
    if (style == AtheerIconButtonStyle.glass) {
      shape = ClipOval(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), child: shape));
    }
    final hit = size < 48 ? 48.0 : size;
    return Semantics(
      button: true,
      selected: selected,
      label: tooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: AtheerPressable(
          onTap: onPressed,
          scale: 0.92,
          child: SizedBox(width: hit, height: hit, child: Center(child: shape)),
        ),
      ),
    );
  }
}

/// أيقونة تقديم/تأخير ١٥ ثانية (سهم دائري ورقم بداخله).
class AtheerSkipIcon extends StatelessWidget {
  final bool forward;
  final double size;
  final Color? color;
  final int seconds;
  const AtheerSkipIcon({super.key, required this.forward, this.size = 30, this.color, this.seconds = 15});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AtheerColors.textPrimary;
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    final label = '$seconds'.split('').map((d) => digits[int.parse(d)]).join();
    // «للأمام» في اتجاه عقارب الساعة، و«للخلف» عكسها، في كل اتجاهات الكتابة.
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        Transform.flip(
          flipX: forward,
          child: Icon(Icons.replay_rounded, size: size, color: c),
        ),
        Padding(
          padding: EdgeInsets.only(top: size * 0.12),
          child: Text(label,
              style: TextStyle(fontFamily: AtheerType.family(AtheerType.body), fontSize: size * 0.3, fontWeight: FontWeight.w700, color: c, height: 1)),
        ),
      ]),
    );
  }
}
