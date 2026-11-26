import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';

import '../api.dart';
import '../scene_layer.dart';

// ألوان مشغّل تطبيق المستمع (AmbientColors) حتى تبدو المعاينة مثله.
const _navy = Color(0xFF080F1E);
const _gold = Color(0xFFC8AA78);
const _ivory = Color(0xFFE9E2D5);

BoxDecoration _panel({double radius = 20, double opacity = 0.42}) => BoxDecoration(
      color: _navy.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _ivory.withValues(alpha: 0.10)),
    );

/// سطر من نص الفصل مع توقيته (حقيقي من ضبط التوقيت، أو تقديري).
class _Line {
  final String speaker, text;
  double start, end;
  List<(double, double)> words;
  _Line(this.speaker, this.text, this.start, this.end, this.words);
  List<String> get tokens => text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
}

List<_Line> _parse(Map? script) {
  final out = <_Line>[];
  for (final e in ((script?['lines'] as List?) ?? const [])) {
    if (e is! Map) continue;
    final words = <(double, double)>[];
    if (e['words'] is List) {
      for (final w in (e['words'] as List)) {
        if (w is List && w.length >= 2) {
          words.add(((w[0] as num).toDouble(), (w[1] as num).toDouble()));
        } else if (w is Map && w['s'] != null && w['e'] != null) {
          words.add(((w['s'] as num).toDouble(), (w['e'] as num).toDouble()));
        }
      }
    }
    out.add(_Line('${e['speaker'] ?? 'الراوي'}', '${e['text'] ?? ''}', (e['start'] as num?)?.toDouble() ?? -1,
        (e['end'] as num?)?.toDouble() ?? -1, words));
  }
  return out;
}

/// نفس حساب تطبيق المستمع: لو مفيش توقيتات حقيقية نقدّرها من طول السطور ونضبطها على مدة الصوت.
bool _ensureTimings(List<_Line> lines, double? target) {
  final timed = lines.isNotEmpty && lines.every((l) => l.start >= 0 && l.end > l.start);
  if (!timed) {
    var t = 0.6;
    for (final l in lines) {
      final dur = (l.text.replaceAll(' ', '').length * 0.085).clamp(1.6, 30.0);
      l.start = t;
      l.end = t + dur;
      l.words = [];
      t = l.end + 0.7;
    }
    if (target != null && target > 1 && lines.isNotEmpty) {
      final k = target / (lines.last.end + 0.6);
      for (final l in lines) {
        l.start *= k;
        l.end *= k;
      }
    }
  }
  for (final l in lines) {
    final toks = l.tokens;
    if (l.words.length == toks.length) continue;
    final weights = toks.map((w) => w.length + 1.0).toList();
    final sum = weights.fold<double>(0, (a, b) => a + b);
    var t = l.start;
    l.words = [];
    for (final w in weights) {
      final d = sum == 0 ? 0.0 : (l.end - l.start) * w / sum;
      l.words.add((t, t + d));
      t += d;
    }
  }
  return timed;
}

int _lineAt(List<_Line> lines, double sec) {
  for (var i = lines.length - 1; i >= 0; i--) {
    if (sec >= lines[i].start - 0.05) return i;
  }
  return 0;
}

int _wordAt(_Line l, double sec) {
  if (sec < l.start) return -1;
  if (sec >= l.end) return l.words.length;
  for (var i = 0; i < l.words.length; i++) {
    if (sec < l.words[i].$2) return i;
  }
  return l.words.length;
}

final _stop = RegExp(r'[.!?؟،,؛;:…»"]$');

/// العبارة المنطوقة الآن (نفس تقسيم تطبيق المستمع: حتى ٩ كلمات أو عند علامة ترقيم).
(List<String>, int, int)? _chunk(_Line line, int word) {
  final toks = line.tokens;
  if (toks.isEmpty) return null;
  final ph = <(int, int)>[];
  var s = 0;
  for (var i = 0; i < toks.length; i++) {
    final n = i - s + 1;
    if (i == toks.length - 1 || n >= 9 || (n >= 4 && _stop.hasMatch(toks[i]))) {
      ph.add((s, i + 1));
      s = i + 1;
    }
  }
  if (ph.length > 1 && ph.last.$2 - ph.last.$1 < 3) {
    final b = ph.removeLast(), a = ph.removeLast();
    ph.add((a.$1, b.$2));
  }
  final w = word.clamp(0, toks.length - 1);
  final p = ph.firstWhere((r) => w >= r.$1 && w < r.$2, orElse: () => ph.last);
  final cur = word < 0 ? -1 : (word >= toks.length ? p.$2 - p.$1 : word - p.$1);
  return (toks.sublist(p.$1, p.$2), p.$1, cur);
}

String _fmt(Duration d) {
  final m = d.inMinutes, s = d.inSeconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// معاينة القصة كما سيراها المستمع: المشهد المتحرك فوق الغلاف، الصوت، والكلام المتزامن.
/// ترجع true لو ضغط «انشرها الآن».
class StoryPreviewPage extends StatefulWidget {
  final String title, narrator, category, cover, scene;
  final bool published;
  final List<Map<String, dynamic>> chapters;
  const StoryPreviewPage({
    super.key,
    required this.title,
    required this.narrator,
    required this.category,
    required this.cover,
    required this.scene,
    required this.published,
    required this.chapters,
  });

  @override
  State<StoryPreviewPage> createState() => _StoryPreviewPageState();
}

class _StoryPreviewPageState extends State<StoryPreviewPage> {
  final _player = AudioPlayer();
  final _subs = <StreamSubscription>[];
  Timer? _demo;
  int chapter = 0;
  List<_Line> lines = [];
  bool realTimings = false, hasAudio = false, loading = true, playing = false, fullText = false;
  String? audioError;
  Duration pos = Duration.zero, dur = Duration.zero;
  int li = 0, wi = -1;
  final _listCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _subs
      ..add(_player.positionStream.listen((p) {
        if (hasAudio) _tick(p);
      }))
      ..add(_player.durationStream.listen((d) {
        if (d != null && mounted) setState(() => dur = d);
      }))
      ..add(_player.playerStateStream.listen((s) {
        if (!hasAudio || !mounted) return;
        if (s.processingState == ProcessingState.completed) {
          _player.pause();
          _player.seek(Duration.zero);
        }
        setState(() => playing = s.playing && s.processingState != ProcessingState.completed);
      }));
    _open(0);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _demo?.cancel();
    _player.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  Future<String?> _audioUrl(Map<String, dynamic> ch) async {
    final a = (ch['audio'] as String? ?? '').trim();
    if (a.isNotEmpty) return a;
    final path = (ch['audio_path'] as String? ?? '').trim();
    if (path.isEmpty) return null;
    return db.storage.from('premium').createSignedUrl(path, 3600);
  }

  Future<void> _open(int i) async {
    _demo?.cancel();
    await _player.stop();
    final ch = widget.chapters[i];
    setState(() {
      chapter = i;
      loading = true;
      playing = false;
      audioError = null;
      pos = Duration.zero;
      dur = Duration.zero;
      li = 0;
      wi = -1;
      lines = _parse(ch['script'] as Map?);
    });
    double? total;
    hasAudio = false;
    try {
      final url = await _audioUrl(ch);
      if (url != null) {
        final d = await _player.setUrl(url);
        hasAudio = true;
        total = d == null ? null : d.inMilliseconds / 1000;
        if (d != null) dur = d;
      }
    } catch (e) {
      audioError = '$e';
    }
    realTimings = _ensureTimings(lines, total);
    if (!hasAudio && lines.isNotEmpty) dur = Duration(milliseconds: ((lines.last.end + 0.6) * 1000).round());
    if (mounted) setState(() => loading = false);
  }

  void _tick(Duration p) {
    if (!mounted) return;
    var nl = li, nw = wi;
    if (lines.isNotEmpty) {
      final sec = p.inMilliseconds / 1000;
      nl = _lineAt(lines, sec);
      nw = _wordAt(lines[nl], sec);
    }
    final lineChanged = nl != li;
    setState(() {
      pos = p;
      li = nl;
      wi = nw;
    });
    if (lineChanged && fullText) _scrollToLine();
  }

  void _scrollToLine() {
    if (!_listCtrl.hasClients) return;
    final target = (li * 64.0 - 160).clamp(0.0, _listCtrl.position.maxScrollExtent);
    _listCtrl.animateTo(target, duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
  }

  // بدون صوت: نشغّل ساعة وهمية حتى يمكن مراجعة تتابع الكلام.
  void _toggle() {
    if (hasAudio) {
      playing ? _player.pause() : _player.play();
      return;
    }
    if (lines.isEmpty) return;
    if (playing) {
      _demo?.cancel();
      setState(() => playing = false);
      return;
    }
    if (pos >= dur) _tick(Duration.zero);
    setState(() => playing = true);
    _demo = Timer.periodic(const Duration(milliseconds: 100), (t) {
      final next = pos + const Duration(milliseconds: 100);
      if (next >= dur) {
        t.cancel();
        setState(() => playing = false);
        _tick(dur);
        return;
      }
      _tick(next);
    });
  }

  void _seek(Duration d) {
    final c = d < Duration.zero ? Duration.zero : (dur > Duration.zero && d > dur ? dur : d);
    if (hasAudio) {
      _player.seek(c);
    }
    _tick(c);
  }

  void _seekLine(int i) {
    if (lines.isEmpty) return;
    final k = i.clamp(0, lines.length - 1);
    _seek(Duration(milliseconds: (lines[k].start * 1000).round()));
  }

  TextStyle get _book => GoogleFonts.amiri(fontSize: 21, color: _ivory, height: 1.8);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _navy,
        body: Stack(fit: StackFit.expand, children: [
          if (widget.cover.isNotEmpty)
            SlowZoom(child: Image.network(widget.cover, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox())),
          Positioned.fill(child: SceneLayer(scene: SceneLayer.resolve(widget.scene, ''), tint: const Color(0xFFB794F6))),
          IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 500),
              opacity: fullText ? 1 : 0.85,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: fullText
                        ? const [Color(0xCC080F1E), Color(0xE6080F1E)]
                        : const [Color(0x99080F1E), Color(0x00080F1E), Color(0x33080F1E), Color(0xF2080F1E)],
                    stops: fullText ? null : const [0, 0.2, 0.45, 1],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(children: [
                  _topBar(context),
                  _checks(),
                  Expanded(child: loading ? const Center(child: CircularProgressIndicator(color: _gold)) : (fullText ? _allText() : const SizedBox())),
                  if (!loading) _bottom(context),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    final ch = widget.chapters[chapter];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Row(children: [
        IconButton(tooltip: 'رجوع', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: _ivory)),
        Expanded(
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: _gold.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
              child: Text(widget.published ? 'معاينة · منشورة' : 'معاينة · لم تُنشر بعد',
                  style: const TextStyle(fontSize: 11, color: _gold, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 3),
            Text(ch['title'] as String? ?? '',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: _ivory, fontWeight: FontWeight.w700)),
          ]),
        ),
        IconButton(
          tooltip: fullText ? 'المشهد' : 'النص كاملًا',
          onPressed: () {
            setState(() => fullText = !fullText);
            if (fullText) WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLine());
          },
          icon: Icon(fullText ? Icons.landscape_outlined : Icons.subject_rounded, color: _ivory),
        ),
        if (widget.chapters.length > 1)
          PopupMenuButton<int>(
            tooltip: 'الفصول',
            icon: const Icon(Icons.format_list_bulleted_rounded, color: _ivory),
            onSelected: _open,
            itemBuilder: (_) => [
              for (final (i, c) in widget.chapters.indexed)
                CheckedPopupMenuItem(value: i, checked: i == chapter, child: Text('${i + 1}. ${c['title'] ?? ''}')),
            ],
          ),
      ]),
    );
  }

  /// تنبيهات مراجعة سريعة قبل النشر.
  Widget _checks() {
    if (loading) return const SizedBox();
    final notes = <(IconData, String, bool)>[
      if (widget.cover.isEmpty) (Icons.image_not_supported_outlined, 'بدون غلاف', false),
      if (lines.isEmpty) (Icons.notes_rounded, 'الفصل بدون نص', false),
      if (!hasAudio && audioError == null) (Icons.music_off_rounded, 'بدون صوت: الكلام يتحرك بتوقيت تقديري', false),
      if (audioError != null) (Icons.error_outline_rounded, 'تعذّر تشغيل الصوت', false),
      if (hasAudio && lines.isNotEmpty) realTimings ? (Icons.check_circle_rounded, 'الكلام متزامن مع الصوت', true) : (Icons.timer_outlined, 'التوقيت تقديري: اضبط التوقيت للمزامنة الدقيقة', false),
    ];
    if (notes.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
        for (final (icon, text, ok) in notes)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: _panel(radius: 20, opacity: 0.55),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 14, color: ok ? const Color(0xFF8FDCB0) : const Color(0xFFF0B35A)),
              const SizedBox(width: 6),
              Text(text, style: const TextStyle(fontSize: 11.5, color: _ivory)),
            ]),
          ),
      ]),
    );
  }

  Widget _allText() {
    return ListView.builder(
      controller: _listCtrl,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      itemCount: lines.length,
      itemBuilder: (_, i) {
        final l = lines[i];
        final now = i == li;
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _seekLine(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: now ? _panel(radius: 12, opacity: 0.5) : null,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (l.speaker != 'الراوي')
                Text(l.speaker, style: const TextStyle(fontSize: 11, color: _gold, fontWeight: FontWeight.w600)),
              Text(l.text,
                  style: _book.copyWith(fontSize: 18, color: now ? _ivory : _ivory.withValues(alpha: i < li ? 0.75 : 0.45))),
            ]),
          ),
        );
      },
    );
  }

  Widget _phrase() {
    if (lines.isEmpty) return const SizedBox();
    final line = lines[li.clamp(0, lines.length - 1)];
    final c = _chunk(line, wi);
    if (c == null) return const SizedBox();
    final (words, start, cur) = c;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: Text.rich(
        TextSpan(style: _book, children: [
          for (var i = 0; i < words.length; i++)
            TextSpan(
              text: i == 0 ? words[i] : ' ${words[i]}',
              style: TextStyle(color: i == cur ? _gold : (i < cur ? _ivory : _ivory.withValues(alpha: 0.55))),
            ),
        ]),
        key: ValueKey('$li:$start'),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _bottom(BuildContext context) {
    final max = dur.inMilliseconds <= 0 ? 1.0 : dur.inMilliseconds.toDouble();
    final speaker = lines.isEmpty ? '' : lines[li.clamp(0, lines.length - 1)].speaker;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          SizedBox(
            width: 58,
            height: 58,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: widget.cover.isEmpty
                  ? ColoredBox(color: _ivory.withValues(alpha: 0.08), child: const Icon(Icons.auto_stories_rounded, color: _gold))
                  : Image.network(widget.cover, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title.isEmpty ? 'بدون عنوان' : widget.title,
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 24, color: _ivory, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text([widget.category, if (widget.narrator.isNotEmpty) 'بصوت ${widget.narrator}'].where((x) => x.isNotEmpty).join(' · '),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: _gold)),
            ]),
          ),
        ]),
        if (!fullText && lines.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: _panel(radius: 18, opacity: 0.35),
            child: Column(children: [
              if (speaker != 'الراوي' && speaker.isNotEmpty)
                Text(speaker, style: const TextStyle(fontSize: 11, color: _gold, fontWeight: FontWeight.w600)),
              _phrase(),
            ]),
          ),
        ],
        const SizedBox(height: 10),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            activeTrackColor: _gold,
            inactiveTrackColor: _ivory.withValues(alpha: 0.18),
            thumbColor: _gold,
            overlayShape: SliderComponentShape.noOverlay,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: pos.inMilliseconds.clamp(0, max.toInt()).toDouble(),
            max: max,
            onChanged: (v) => _seek(Duration(milliseconds: v.round())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(children: [
            Text(_fmt(pos), style: TextStyle(fontSize: 11, color: _ivory.withValues(alpha: 0.7))),
            const Spacer(),
            Text(_fmt(dur), style: TextStyle(fontSize: 11, color: _ivory.withValues(alpha: 0.7))),
          ]),
        ),
        const SizedBox(height: 6),
        // الواجهة من اليمين لليسار: السابق على اليمين وسهمه لليمين.
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(tooltip: 'السطر السابق', onPressed: () => _seekLine(li - 1), icon: const Icon(Icons.skip_next_rounded, color: _ivory)),
          IconButton(
              tooltip: 'رجوع ١٠ ثوانٍ',
              iconSize: 30,
              onPressed: () => _seek(pos - const Duration(seconds: 10)),
              icon: const Icon(Icons.replay_10_rounded, color: _ivory)),
          const SizedBox(width: 8),
          SizedBox(
            width: 68,
            height: 68,
            child: IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: _gold, foregroundColor: _navy),
              onPressed: lines.isEmpty && !hasAudio ? null : _toggle,
              icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 38),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
              tooltip: 'تقديم ١٠ ثوانٍ',
              iconSize: 30,
              onPressed: () => _seek(pos + const Duration(seconds: 10)),
              icon: const Icon(Icons.forward_10_rounded, color: _ivory)),
          IconButton(tooltip: 'السطر التالي', onPressed: () => _seekLine(li + 1), icon: const Icon(Icons.skip_previous_rounded, color: _ivory)),
        ]),
        if (!widget.published) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: _navy, minimumSize: const Size(0, 50)),
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.publish_rounded),
              label: const Text('تمام، انشرها في التطبيق', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ]),
    );
  }
}
