import 'package:atheer/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// التوقيتات الحقيقية (من ضبط التوقيت) يجب ألا تُرمى أبدًا، حتى لو سطر واحد بلا توقيت.
void main() {
  ScriptLine timed(String text, double a, double b) {
    final toks = text.split(' ');
    final step = (b - a) / toks.length;
    return ScriptLine(
      speaker: 'الراوي',
      text: text,
      start: a,
      end: b,
      words: [for (var i = 0; i < toks.length; i++) WordTiming(a + i * step, a + (i + 1) * step)],
    );
  }

  test('سطر ناقص التوقيت لا يلغي توقيتات باقي السطور', () {
    final s = ChapterScript(lines: [
      timed('أول سطر مضبوط', 1.0, 4.0),
      ScriptLine(speaker: 'الراوي', text: 'سطر أضيف بعد الضبط'),
      timed('آخر سطر مضبوط تماما', 100.0, 110.0),
    ], speakerColors: {})
      ..ensureTimings(targetSeconds: 120);
    expect(s.estimated, isFalse);
    expect(s.lines.first.start, 1.0);
    expect(s.lines.last.start, 100.0);
    expect(s.lines.last.words.first.start, 100.0);
    expect(s.lines[1].start, 4.0);
    expect(s.lines[1].end, closeTo(100.0, 1e-9));
    expect(s.lineAt(105), 2);
    expect(s.wordAt(2, 106), 2);
  });

  test('بدون أي توقيت حقيقي يبقى التقدير على مدة الصوت', () {
    final s = ChapterScript(lines: [ScriptLine(speaker: 'الراوي', text: 'نص بلا ضبط')], speakerColors: {})
      ..ensureTimings(targetSeconds: 30);
    expect(s.estimated, isTrue);
  });
}
