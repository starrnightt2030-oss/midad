import 'package:flutter/material.dart';

import '../../theme.dart';
import '../motion.dart';
import '../tokens.dart';

/// مشهد Hero سينمائي كبير: خلفية (صورة أو مشهد حي)، سطر علوي صغير، عنوان، ووصف، وأزرار.
///
/// الخلفية تأتي من [background] حتى يمكن تمرير غلاف قصة أو مشهد حي أو صورة قسم.
class AtheerHeroBanner extends StatelessWidget {
  final Widget background;
  final String? overline;
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final double height;
  final VoidCallback? onTap;
  final Color? tint;

  const AtheerHeroBanner({
    super.key,
    required this.background,
    required this.title,
    this.overline,
    this.subtitle,
    this.actions = const [],
    this.height = 380,
    this.onTap,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(AtheerRadius.xl);
    return Semantics(
      container: true,
      label: title,
      child: AtheerPressable(
        onTap: onTap,
        scale: 0.985,
        child: Container(
          height: height,
          decoration: BoxDecoration(borderRadius: r, boxShadow: AtheerElevation.mid),
          child: ClipRRect(
            borderRadius: r,
            child: Stack(fit: StackFit.expand, children: [
              RepaintBoundary(child: background),
              if (tint != null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [tint!.op(0.0), tint!.op(0.18)],
                    ),
                  ),
                ),
              DecoratedBox(decoration: BoxDecoration(gradient: AtheerGradients.scrimBottom())),
              Padding(
                padding: const EdgeInsets.all(AtheerSpacing.xxl),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (overline != null) ...[
                    Row(children: [
                      Container(width: 18, height: 1.2, color: AtheerColors.accent),
                      const SizedBox(width: AtheerSpacing.sm),
                      Flexible(child: Text(overline!, style: AtheerType.overline())),
                    ]),
                    const SizedBox(height: AtheerSpacing.sm + 2),
                  ],
                  // النصوص مرنة: على الشاشات الصغيرة تتقلص بدل أن تدفع الأزرار خارج البطاقة.
                  Flexible(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AtheerType.h1())),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: AtheerSpacing.sm),
                    Flexible(
                      child: Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: AtheerType.bodyMedium(color: AtheerColors.softIvory.op(0.8))),
                    ),
                  ],
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: AtheerSpacing.xl),
                    Wrap(spacing: AtheerSpacing.md, runSpacing: AtheerSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: actions),
                  ],
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
