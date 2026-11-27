import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repository.dart';
import '../models.dart';
import '../theme.dart';

/// صورة القسم: البديلة اللي رفعها الأدمن، وإلا المضمّنة في التطبيق، وإلا تدرّج بألوان القسم.
class WorldArt extends StatelessWidget {
  final World world;

  /// عرض فك الصورة بالبكسل (لتوفير الذاكرة في البطاقات الصغيرة).
  final int? decodeWidth;
  const WorldArt({super.key, required this.world, this.decodeWidth});

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [world.color.op(0.85), world.color2],
        ),
      ),
    );
    Widget fade(BuildContext _, Widget img, int? frame, bool sync) =>
        sync ? img : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 450), child: img);

    final cover = world.cover;
    Widget img;
    if (cover != null) {
      ContentRepository? repo;
      try {
        repo = Provider.of<ContentRepository>(context, listen: false);
      } catch (_) {}
      final r = repo?.resolve(cover) ?? (path: cover, remote: cover.startsWith('http'));
      img = r.remote
          ? Image.network(r.path,
              fit: BoxFit.cover, cacheWidth: decodeWidth, frameBuilder: fade, errorBuilder: (_, __, ___) => _bundled(fade, fallback))
          : Image.asset(r.path,
              fit: BoxFit.cover, cacheWidth: decodeWidth, frameBuilder: fade, errorBuilder: (_, __, ___) => _bundled(fade, fallback));
    } else {
      img = _bundled(fade, fallback);
    }
    return Stack(fit: StackFit.expand, children: [fallback, img]);
  }

  Widget _bundled(ImageFrameBuilder fade, Widget fallback) => Image.asset(
        world.bundledImage,
        fit: BoxFit.cover,
        cacheWidth: decodeWidth,
        frameBuilder: fade,
        errorBuilder: (_, __, ___) => fallback,
      );
}

/// القسم ظاهر في «عوالم أثير»؟ المخفي لا، والفاضي حسب إعداد الأدمن.
bool worldShown(Catalog cat, World w) => w.visible && (w.emptyMode != 'hide' || cat.worksOf(w.id).isNotEmpty);
