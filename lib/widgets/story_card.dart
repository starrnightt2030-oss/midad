import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../screens/work_screen.dart';
import '../state/library.dart';
import '../theme.dart';
import 'common.dart';
import 'cover_art.dart';

/// خلفية الشاشات: تدرّج الثيم + توهّج هادئ + نجوم خافتة.
class AtheerBackground extends StatelessWidget {
  final Widget child;
  final bool stars;
  const AtheerBackground({super.key, required this.child, this.stars = true});

  @override
  Widget build(BuildContext context) {
    final p = MidadColors.palette;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: p.background),
      child: Stack(children: [
        AmbientGlow(color: p.glow, alignment: const Alignment(0.9, -1.0), size: 380, opacity: 0.35),
        AmbientGlow(color: p.glow, alignment: const Alignment(-1.0, 0.4), size: 300, opacity: 0.18),
        if (stars) const Positioned.fill(child: Starfield(count: 26)),
        child,
      ]),
    );
  }
}

/// زر قلب دائري زجاجي (المفضلة).
class HeartButton extends StatelessWidget {
  final String workId;
  final double size;
  const HeartButton({super.key, required this.workId, this.size = 30});

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryStore>();
    final fav = lib.isFav(workId);
    return Semantics(
      button: true,
      label: fav ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
      child: GestureDetector(
        onTap: () => lib.toggleFav(workId),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              color: Colors.white.op(0.22),
              child: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  size: size * 0.55, color: fav ? MidadColors.accent : Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// بطاقة قصة بأسلوب التصميم الجديد: غلاف بزوايا دائرية، قلب، وعنوان في كبسولة زجاجية.
class StoryCard extends StatelessWidget {
  final Work work;
  final double width;
  final double height;
  const StoryCard({super.key, required this.work, this.width = 150, this.height = 170});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(fadeRoute(WorkScreen(work: work))),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: Colors.black.op(0.35), blurRadius: 18, offset: const Offset(0, 8))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(fit: StackFit.expand, children: [
              CoverArt(art: work.art, url: work.cover),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.op(0.45)],
                    stops: const [0.5, 1],
                  ),
                ),
              ),
              PositionedDirectional(top: 10, end: 10, child: HeartButton(workId: work.id)),
              if (work.premium)
                PositionedDirectional(
                  top: 10,
                  start: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black.op(0.45), borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.lock_rounded, size: 12, color: MidadColors.accent),
                      const SizedBox(width: 4),
                      Text('اشتراك', style: MidadText.ui(size: 10, weight: FontWeight.w700)),
                    ]),
                  ),
                ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Center(child: GlassPill(text: work.title)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// كبسولة زجاجية للنصوص فوق الصور.
class GlassPill extends StatelessWidget {
  final String text;
  const GlassPill({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.op(0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.op(0.15)),
          ),
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: MidadText.ui(size: 12, weight: FontWeight.w600)),
        ),
      ),
    );
  }
}

/// عنوان قسم مع «عرض الكل».
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const SectionHeader({super.key, required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
      child: Row(children: [
        Expanded(child: Text(title, style: MidadText.title(size: 17))),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text('عرض الكل', style: MidadText.ui(size: 12, color: Colors.white60)),
            ),
          ),
      ]),
    );
  }
}

/// زر رئيسي بتدرّج الثيم (مثل «ابدأ الآن»).
class AccentButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final double height;
  const AccentButton({super.key, required this.label, required this.onTap, this.icon, this.height = 54});

  @override
  Widget build(BuildContext context) {
    final p = MidadColors.palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          gradient: p.button,
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: [BoxShadow(color: p.accent.op(0.35), blurRadius: 22, offset: const Offset(0, 6))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, color: p.bg, size: 22), const SizedBox(width: 8)],
          Text(label, style: MidadText.ui(size: 15, weight: FontWeight.w700, color: p.bg)),
        ]),
      ),
    );
  }
}

/// شريحة اختيار (قسم، هدف...).
class ChoiceChipPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const ChoiceChipPill({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = MidadColors.palette;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? p.button : null,
          color: selected ? null : p.surfaceHigh.op(0.8),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: selected ? Colors.transparent : Colors.white.op(0.08)),
        ),
        child: Text(label,
            style: MidadText.ui(size: 13, weight: FontWeight.w600, color: selected ? p.bg : Colors.white.op(0.85))),
      ),
    );
  }
}
