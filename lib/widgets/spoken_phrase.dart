import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/player.dart';

/// جملة قصيرة من السطر الحالي حول الكلمة المنطوقة الآن.
/// السطر الطويل (أو القصة كلها في سطر واحد) يُقسَّم إلى عبارات عند علامات الترقيم
/// أو كل [maxWords] كلمة، فلا يظهر على الشاشة إلا الجزء الذي يُقال الآن.
class SpokenChunk {
  final List<String> words;
  final int start; // موضع أول كلمة في السطر
  final int current; // الكلمة المنطوقة داخل العبارة (-1 قبل البداية)
  const SpokenChunk(this.words, this.start, this.current);
}

final _cache = Expando<List<(int, int)>>('phrases');
final _stop = RegExp(r'[.!?؟،,؛;:…»"]$');

List<(int, int)> phrasesOf(ScriptLine line, {int maxWords = 9, int minWords = 4}) {
  final hit = _cache[line];
  if (hit != null) return hit;
  final toks = line.tokens;
  final out = <(int, int)>[];
  var s = 0;
  for (var i = 0; i < toks.length; i++) {
    final n = i - s + 1;
    final last = i == toks.length - 1;
    if (last || n >= maxWords || (n >= minWords && _stop.hasMatch(toks[i]))) {
      out.add((s, i + 1));
      s = i + 1;
    }
  }
  // لا تترك عبارة أخيرة من كلمة أو اثنتين وحدها.
  if (out.length > 1 && out.last.$2 - out.last.$1 < 3) {
    final b = out.removeLast();
    final a = out.removeLast();
    out.add((a.$1, b.$2));
  }
  _cache[line] = out;
  return out;
}

SpokenChunk? spokenChunk(ScriptLine line, int wordIndex) {
  final toks = line.tokens;
  if (toks.isEmpty) return null;
  final ph = phrasesOf(line);
  final w = wordIndex.clamp(0, toks.length - 1);
  final p = ph.firstWhere((r) => w >= r.$1 && w < r.$2, orElse: () => ph.last);
  final cur = wordIndex < 0 ? -1 : (wordIndex >= toks.length ? p.$2 - p.$1 : wordIndex - p.$1);
  return SpokenChunk(toks.sublist(p.$1, p.$2), p.$1, cur);
}

/// يعرض العبارة المنطوقة الآن: ما قيل بلون كامل، والكلمة الحالية مميزة، والباقي أخفت.
class SpokenPhrase extends StatelessWidget {
  final TextStyle style;
  final Color highlight;
  final int? maxLines;
  final Duration fade;
  const SpokenPhrase({super.key, required this.style, required this.highlight, this.maxLines, this.fade = const Duration(milliseconds: 450)});

  @override
  Widget build(BuildContext context) {
    final (line, word, li) = context.select<PlayerController, (ScriptLine?, int, int)>((p) {
      final s = p.script;
      if (s == null || s.lines.isEmpty) return (null, -1, 0);
      final i = p.lineIndex.clamp(0, s.lines.length - 1);
      return (s.lines[i], p.wordIndex, i);
    });
    if (line == null) return const SizedBox.shrink();
    final c = spokenChunk(line, word);
    if (c == null) return const SizedBox.shrink();
    final base = style.color ?? Colors.white;
    final spans = <InlineSpan>[];
    for (var i = 0; i < c.words.length; i++) {
      final color = i == c.current ? highlight : (i < c.current ? base : base.withValues(alpha: base.a * 0.55));
      spans.add(TextSpan(text: i == 0 ? c.words[i] : ' ${c.words[i]}', style: TextStyle(color: color)));
    }
    return AnimatedSwitcher(
      duration: fade,
      child: Text.rich(
        TextSpan(style: style, children: spans),
        key: ValueKey('$li:${c.start}'),
        textAlign: TextAlign.center,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
      ),
    );
  }
}
