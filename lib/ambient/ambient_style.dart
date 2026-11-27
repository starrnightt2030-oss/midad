import 'package:flutter/material.dart';

/// ألوان الهوية للمشاهد الحية وشاشة التشغيل السينمائية (نفس قيم AtheerColors).
class AmbientColors {
  static const midnightNavy = Color(0xFF090F19);
  static const calmBlue = Color(0xFF182C40);
  static const naturalTeal = Color(0xFF315B50);
  static const warmGold = Color(0xFFD9BE91);
  static const softIvory = Color(0xFFF0E8DB);

  /// لوح شفاف داكن بدون BackdropFilter (التمويه فوق مشهد متحرك مكلف جدًا على المعالج).
  static BoxDecoration panel({double radius = 20, double opacity = 0.42}) => BoxDecoration(
        color: midnightNavy.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: softIvory.withValues(alpha: 0.10)),
      );
}
