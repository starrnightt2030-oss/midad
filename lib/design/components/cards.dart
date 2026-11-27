import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../state/library.dart';
import '../../theme.dart';
import '../../widgets/common.dart' show arNum;
import '../../widgets/cover_art.dart';
import '../motion.dart';
import '../tokens.dart';

/// بطاقة قصة بأسلوب أغلفة الكتب: غلاف نظيف، والعنوان والمدة تحته (تحريري، بلا زحمة فوق الصورة).
///
/// [progress] يعرض شريط تقدم رفيع (لـ«أكمل الاستماع»).
/// [heroTag] اختياري: يُمرَّر فقط حين يكون الغلاف فريدًا في الشاشة.
class AtheerStoryCard extends StatelessWidget {
  final Work work;
  final double width;
  final double aspectRatio;
  final double? progress;
  final String? subtitle;
  final Object? heroTag;
  final VoidCallback? onTap;
  final bool showFavorite;

  const AtheerStoryCard({
    super.key,
    required this.work,
    this.width = 148,
    this.aspectRatio = 3 / 4,
    this.progress,
    this.subtitle,
    this.heroTag,
    this.onTap,
    this.showFavorite = true,
  });

  @override
  Widget build(BuildContext context) {
    final r = AtheerRadius.tile;
    Widget cover = ClipRRect(
      borderRadius: r,
      child: Stack(fit: StackFit.expand, children: [
        CoverArt(art: work.art, url: work.cover),
        // لمعة خفيفة من الأعلى تعطي عمقًا بدون حدود.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white.op(0.06), Colors.transparent, AtheerColors.midnight.op(0.28)],
              stops: const [0, 0.4, 1],
            ),
          ),
        ),
        if (work.premium) const PositionedDirectional(top: 8, start: 8, child: AtheerBadge(icon: Icons.lock_rounded, label: 'اشتراك')),
        if (showFavorite) PositionedDirectional(top: 6, end: 6, child: _Fav(workId: work.id)),
        if (progress != null)
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: AtheerProgressLine(value: progress!),
          ),
      ]),
    );
    if (heroTag != null) cover = Hero(tag: heroTag!, child: cover);
    final meta = subtitle ?? (work.minutes > 0 ? '${arNum(work.minutes)} دقيقة' : work.kind);
    return Semantics(
      button: onTap != null,
      label: work.title,
      child: AtheerPressable(
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            AspectRatio(
              aspectRatio: aspectRatio,
              child: DecoratedBox(decoration: BoxDecoration(borderRadius: r, boxShadow: AtheerElevation.low), child: cover),
            ),
            const SizedBox(height: AtheerSpacing.sm + 2),
            Text(work.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AtheerType.label()),
            if (meta.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: AtheerType.bodySmall()),
            ],
          ]),
        ),
      ),
    );
  }
}

class _Fav extends StatelessWidget {
  final String workId;
  const _Fav({required this.workId});

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryStore>();
    final fav = lib.isFav(workId);
    return Semantics(
      button: true,
      label: fav ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
      excludeSemantics: true,
      child: AtheerPressable(
        onTap: () => lib.toggleFav(workId),
        scale: 0.85,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AtheerColors.midnight.op(0.42)),
              child: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 16, color: fav ? AtheerColors.accent : Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// شارة صغيرة فوق الصور.
class AtheerBadge extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color? color;
  const AtheerBadge({super.key, this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AtheerColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: AtheerColors.midnight.op(0.55), borderRadius: BorderRadius.circular(AtheerRadius.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 11, color: c), const SizedBox(width: 4)],
        Text(label, style: AtheerType.labelSmall(color: AtheerColors.textPrimary)),
      ]),
    );
  }
}

/// شريط تقدم رفيع بلون مميّز.
class AtheerProgressLine extends StatelessWidget {
  final double value;
  final double height;
  final Color? color;
  const AtheerProgressLine({super.key, required this.value, this.height = 3, this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
<<<<<<< HEAD
        child: LayoutBuilder(
          builder: (_, c) => Stack(children: [
            Positioned.fill(child: ColoredBox(color: Colors.white.op(0.22))),
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              width: c.maxWidth * value.clamp(0.0, 1.0),
              child: ColoredBox(color: color ?? AtheerColors.accent),
            ),
          ]),
        ),
=======
        child: Stack(children: [
          Positioned.fill(child: ColoredBox(color: Colors.white.op(0.22))),
          FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: value.clamp(0.0, 1.0),
            child: ColoredBox(color: color ?? AtheerColors.accent),
          ),
        ]),
>>>>>>> 14230554f15b2c391163dd03e4b147df5b650159
      ),
    );
  }
}

/// بطاقة قسم (عالم) لشبكة Bento السينمائية.
///
/// [image] صورة القسم الأصلية (asset أو رابط). [color] لون شخصية القسم ويُستخدم
/// في تدرّج خفيف فوق الصورة. [heroTag] يربط البطاقة بغلاف صفحة القسم.
class AtheerCategoryCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int? count;
  final String? image;

  /// بديل لـ [image] عند الحاجة لمزوّد صورة جاهز (ذاكرة مؤقتة، ملف منزّل...).
  final ImageProvider? imageProvider;
<<<<<<< HEAD

  /// بديل جاهز للخلفية كلها (مثلًا WorldArt) يتقدّم على [image] و[imageProvider].
  final Widget? art;
=======
>>>>>>> 14230554f15b2c391163dd03e4b147df5b650159
  final Color color;
  final Object? heroTag;
  final VoidCallback? onTap;
  final bool large;

  const AtheerCategoryCard({
    super.key,
    required this.title,
    required this.color,
    this.subtitle,
    this.count,
    this.image,
    this.imageProvider,
<<<<<<< HEAD
    this.art,
=======
>>>>>>> 14230554f15b2c391163dd03e4b147df5b650159
    this.heroTag,
    this.onTap,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = AtheerRadius.card;
<<<<<<< HEAD
    Widget bg = art ??
        (imageProvider != null
            ? Image(
                image: imageProvider!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => DecoratedBox(decoration: BoxDecoration(gradient: AtheerGradients.tint(color))))
            : image == null
                ? DecoratedBox(decoration: BoxDecoration(gradient: AtheerGradients.tint(color)))
                : _image(image!));
=======
    Widget bg = imageProvider != null
        ? Image(
            image: imageProvider!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => DecoratedBox(decoration: BoxDecoration(gradient: AtheerGradients.tint(color))))
        : image == null
            ? DecoratedBox(decoration: BoxDecoration(gradient: AtheerGradients.tint(color)))
            : _image(image!);
>>>>>>> 14230554f15b2c391163dd03e4b147df5b650159
    if (heroTag != null) bg = Hero(tag: heroTag!, child: bg);
    return Semantics(
      button: true,
      label: count == null ? title : '$title، ${arNum(count!)} محتوى',
      excludeSemantics: true,
      child: AtheerPressable(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: r,
          child: Stack(fit: StackFit.expand, children: [
            ColoredBox(color: color.darken(0.3)),
            bg,
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, color.darken(0.35).op(0.45), AtheerColors.midnight.op(0.86)],
                  stops: const [0.3, 0.68, 1],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(large ? AtheerSpacing.xl : AtheerSpacing.md + 2),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                if (count != null && count! > 0)
                  Text('${arNum(count!)} ${count == 1 ? 'محتوى' : 'محتويات'}', style: AtheerType.labelSmall(color: AtheerColors.textSecondary)),
                const SizedBox(height: 2),
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: large ? AtheerType.h2() : AtheerType.h3()),
                if (large && subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: AtheerType.bodySmall(color: AtheerColors.textSecondary)),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _image(String src) {
    final remote = src.startsWith('http');
    final err = (BuildContext _, Object __, StackTrace? ___) => DecoratedBox(decoration: BoxDecoration(gradient: AtheerGradients.tint(color)));
    return remote ? Image.network(src, fit: BoxFit.cover, errorBuilder: err, gaplessPlayback: true) : Image.asset(src, fit: BoxFit.cover, errorBuilder: err);
  }
}
