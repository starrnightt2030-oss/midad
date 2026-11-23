import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repository.dart';
import '../state/library.dart';
import '../state/player.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'live_read_screen.dart';
import 'quote_screen.dart';

/// وضع الصفحة: ورق دافئ، والسطر المسموع مظلّل ويتابعه التمرير.
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _keys = <int, GlobalKey>{};
  int _lastLine = -1;
  bool _follow = true;

  GlobalKey _key(int i) => _keys.putIfAbsent(i, () => GlobalKey());

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerController>();
    final lib = context.watch<LibraryStore>();
    final cat = context.watch<ContentRepository>().catalog;
    final w = p.work;
    final s = p.script;
    if (w == null) return const Scaffold();
    final accent = Color.lerp(cat?.worldOf(w)?.color ?? MidadColors.saffron, MidadColors.paperInk, 0.35)!;

    if (_follow && p.playing && p.lineIndex != _lastLine) {
      _lastLine = p.lineIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keys[p.lineIndex]?.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx, alignment: 0.35, duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic);
        }
      });
    }

    return Scaffold(
      backgroundColor: MidadColors.paper,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Row(children: [
              IconButton(tooltip: 'رجوع', color: MidadColors.paperInk, onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded)),
              Expanded(
                child: Column(children: [
                  Text(w.title, style: MidadText.ui(size: 11, color: const Color(0xFF6E6255))),
                  Text(p.chapter?.title ?? '', style: MidadText.ui(size: 14, weight: FontWeight.w700, color: MidadColors.paperInk)),
                ]),
              ),
              IconButton(
                tooltip: 'تصغير الخط',
                color: MidadColors.paperInk,
                onPressed: () => lib.setFontScale(lib.fontScale - 0.1),
                icon: const Icon(Icons.text_decrease_rounded),
              ),
              IconButton(
                tooltip: 'تكبير الخط',
                color: MidadColors.paperInk,
                onPressed: () => lib.setFontScale(lib.fontScale + 0.1),
                icon: const Icon(Icons.text_increase_rounded),
              ),
            ]),
          ),
          Expanded(
            child: s == null
                ? const Center(child: CircularProgressIndicator())
                : NotificationListener<UserScrollNotification>(
                    onNotification: (_) {
                      _follow = false;
                      Future.delayed(const Duration(seconds: 6), () => _follow = true);
                      return false;
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(26, 18, 26, 120),
                      children: [
                        const Center(child: _Ornament()),
                        const SizedBox(height: 10),
                        Text(p.chapter?.title ?? '', textAlign: TextAlign.center, style: MidadText.book(size: 28 * lib.fontScale, weight: FontWeight.w700, color: MidadColors.paperInk)),
                        const SizedBox(height: 22),
                        for (var i = 0; i < s.lines.length; i++)
                          Padding(
                            key: _key(i),
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GestureDetector(
                              onTap: () => p.seekToLine(i),
                              onLongPress: () => Navigator.of(context).push(fadeRoute(QuoteScreen(text: s.lines[i].text, work: w))),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 400),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: i == p.lineIndex && (p.playing || p.position > Duration.zero) ? const Color(0xFFEBCB8B) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text.rich(
                                  TextSpan(children: [
                                    if (s.lines[i].speaker != 'الراوي')
                                      TextSpan(
                                        text: '${s.lines[i].speaker}: ',
                                        style: MidadText.book(size: 15 * lib.fontScale, weight: FontWeight.w700, color: accent),
                                      ),
                                    TextSpan(text: s.lines[i].text),
                                  ]),
                                  textAlign: TextAlign.justify,
                                  style: MidadText.book(size: 20 * lib.fontScale, color: MidadColors.paperInk, height: 2),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Center(child: Text('اضغط على أي سطر لسماعه، واضغط مطوّلًا لتصنع منه خاطرة', style: MidadText.ui(size: 11, color: const Color(0xFF6E6255)))),
                      ],
                    ),
                  ),
          ),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
          decoration: BoxDecoration(color: const Color(0xFF1A1D27), borderRadius: BorderRadius.circular(28), boxShadow: [
            BoxShadow(color: MidadColors.paperInk.op(0.35), blurRadius: 24, offset: const Offset(0, 10)),
          ]),
          child: Row(children: [
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: MidadColors.saffron, foregroundColor: MidadColors.ink),
              tooltip: p.playing ? 'إيقاف مؤقت' : 'استمع',
              onPressed: p.toggle,
              icon: Icon(p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.playing ? 'يقرأ الآن' : 'استمع وأنت تقرأ', style: MidadText.ui(size: 12, weight: FontWeight.w600)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(value: p.progress, minHeight: 3, color: MidadColors.saffron, backgroundColor: Colors.white12),
                ),
              ]),
            ),
            IconButton(
              tooltip: 'الوضع السينمائي',
              onPressed: () => Navigator.of(context).pushReplacement(fadeRoute(const LiveReadScreen())),
              icon: const Icon(Icons.movie_filter_outlined),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Ornament extends StatelessWidget {
  const _Ornament();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(80, 16), painter: _OrnPainter());
  }
}

class _OrnPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFB8863A)
      ..style = PaintingStyle.stroke;
    final cy = size.height / 2;
    canvas.drawLine(Offset(0, cy), Offset(size.width / 2 - 10, cy), p);
    canvas.drawLine(Offset(size.width / 2 + 10, cy), Offset(size.width, cy), p);
    final d = Path()
      ..moveTo(size.width / 2, 1)
      ..lineTo(size.width / 2 + 7, cy)
      ..lineTo(size.width / 2, size.height - 1)
      ..lineTo(size.width / 2 - 7, cy)
      ..close();
    canvas.drawPath(d, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
