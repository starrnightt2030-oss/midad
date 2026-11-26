import 'package:flutter/material.dart';

/// ألوان الهوية للمشاهد الحية وشاشة التشغيل السينمائية.
class AmbientColors {
  static const midnightNavy = Color(0xFF080F1E);
  static const calmBlue = Color(0xFF192C40);
  static const naturalTeal = Color(0xFF345653);
  static const warmGold = Color(0xFFC8AA78);
  static const softIvory = Color(0xFFE9E2D5);

  /// لوح شفاف داكن بدون BackdropFilter (التمويه فوق مشهد متحرك مكلف جدًا على المعالج).
  static BoxDecoration panel({double radius = 20, double opacity = 0.42}) => BoxDecoration(
        color: midnightNavy.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: softIvory.withValues(alpha: 0.10)),
      );
}
