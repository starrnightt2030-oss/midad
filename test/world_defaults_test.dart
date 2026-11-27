import 'package:atheer/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('القسم الأساسي يكمّل الوصف واللون الناقصين', () {
    final w = World.fromJson({'id': 'tranquility', 'name': 'طمأنينة', 'color': '#5ED3E0'});
    expect(w.description, contains('السكينة'));
    expect(w.tagline, 'هنا يجد قلبك بعض السلام');
    expect(w.bundledImage, 'assets/categories/tranquility.webp');
  });

  test('القسم القديم بنفس الاسم ياخد صورة القسم الأساسي', () {
    final w = World.fromJson({'id': 'w_old', 'name': '. بين القلوب', 'tagline': 'عبارتي'});
    expect(w.bundledImage, 'assets/categories/between_hearts.webp');
    expect(w.tagline, 'عبارتي'); // بيانات القاعدة لها الأولوية
  });

  test('قسم جديد مالوش أساسي', () {
    final w = World.fromJson({'id': 'night', 'name': 'ليالي'});
    expect(w.description, '');
    expect(w.bundledImage, 'assets/categories/night.webp');
  });
}
