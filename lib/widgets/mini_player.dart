import 'package:flutter/material.dart';

import '../design/components/mini_player.dart';

/// المشغّل المصغّر: صار جزءًا من نظام التصميم ([AtheerMiniPlayer]).
/// يبقى هذا الاسم حتى تعمل الشاشات القديمة بدون تعديل.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) => const AtheerMiniPlayer();
}
