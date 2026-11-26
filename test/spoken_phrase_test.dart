import 'package:atheer/models.dart';
import 'package:atheer/widgets/spoken_phrase.dart';
import 'package:flutter_test/flutter_test.dart';

/// القصة كلها في سطر واحد: يجب أن يظهر جزء قصير حول الكلمة المنطوقة فقط، ويتقدم مع الصوت.
void main() {
  final text = List.generate(60, (i) => i % 7 == 6 ? 'كلمة$i،' : 'كلمة$i').join(' ');
  final script = ChapterScript(lines: [ScriptLine(speaker: 'الراوي', text: text)], speakerColors: {})
    ..ensureTimings(targetSeconds: 120);
  final line = script.lines.single;

  test('العبارات قصيرة وتغطي السطر كله بالترتيب', () {
    final ph = phrasesOf(line);
    expect(ph.first.$1, 0);
    expect(ph.last.$2, 60);
    for (var i = 0; i < ph.length; i++) {
      expect(ph[i].$2 - ph[i].$1, inInclusiveRange(3, 9));
      if (i > 0) expect(ph[i].$1, ph[i - 1].$2);
    }
  });

  test('العبارة المعروضة تتبع الكلمة المنطوقة مع الوقت', () {
    var lastStart = -1;
    for (var sec = 0.0; sec < 120; sec += 3) {
      final w = script.wordAt(script.lineAt(sec), sec);
      final c = spokenChunk(line, w)!;
      expect(c.words.length, lessThanOrEqualTo(9));
      expect(c.start, greaterThanOrEqualTo(lastStart));
      if (w >= 0 && w < 60) expect(c.words[c.current], line.tokens[w]);
      lastStart = c.start;
    }
    expect(spokenChunk(line, 59)!.start, greaterThan(40));
  });

  test('التوقيت التقديري يتمدد على مدة الصوت بعد تحميله', () {
    final s = ChapterScript(lines: [
      for (var i = 0; i < 20; i++) ScriptLine(speaker: 'الراوي', text: 'جملة رقم $i فيها كلام عادي.'),
    ], speakerColors: {});
    s.ensureTimings(); // قبل معرفة مدة الصوت
    expect(s.estimated, isTrue);
    s.ensureTimings(targetSeconds: 300);
    expect(s.lines.last.end, closeTo(300, 5));
    expect(s.lines.last.words.last.end, closeTo(s.lines.last.end, 0.01));
  });

  test('التوقيتات الحقيقية لا تتغير', () {
    final s = ChapterScript(lines: [ScriptLine(speaker: 'الراوي', text: 'أ ب', start: 1, end: 2)], speakerColors: {});
    s.ensureTimings(targetSeconds: 300);
    expect(s.estimated, isFalse);
    expect(s.lines.single.end, 2);
  });
}
