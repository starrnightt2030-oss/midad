import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../data/repository.dart';
import '../models.dart';
import '../state/library.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/cover_art.dart';

/// صانع الخواطر: يحوّل سطرًا إلى بطاقة جاهزة للمشاركة.
class QuoteScreen extends StatefulWidget {
  final String text;
  final Work work;
  const QuoteScreen({super.key, required this.text, required this.work});

  @override
  State<QuoteScreen> createState() => _QuoteScreenState();
}

class _QuoteScreenState extends State<QuoteScreen> {
  final _boundary = GlobalKey();
  int _t = 0;
  int _f = 0;
  bool _busy = false;

  static const _templates = ['ليل', 'ورق', 'لوحة'];

  @override
  Widget build(BuildContext context) {
    final color = context.read<ContentRepository>().catalog?.worldOf(widget.work)?.color ?? MidadColors.saffron;
    return Scaffold(
      backgroundColor: MidadColors.ink,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Row(children: [
              GlassIconButton(icon: Icons.arrow_back_rounded, tooltip: 'رجوع', onTap: () => Navigator.pop(context)),
              Expanded(child: Text('اصنع خاطرتك', textAlign: TextAlign.center, style: MidadText.title(size: 18))),
              const SizedBox(width: 44),
            ]),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: RepaintBoundary(
                    key: _boundary,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 450),
                      child: KeyedSubtree(key: ValueKey('$_t-$_f'), child: _card(color)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              for (var i = 0; i < _templates.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: SizedBox(width: double.infinity, child: Text(_templates[i], textAlign: TextAlign.center)),
                      selected: _t == i,
                      onSelected: (_) => setState(() => _t = i),
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Text('الخط', style: MidadText.ui(size: 12, color: Colors.white70)),
              const SizedBox(width: 12),
              ChoiceChip(label: const Text('نسخ'), selected: _f == 0, onSelected: (_) => setState(() => _f = 0)),
              const SizedBox(width: 8),
              ChoiceChip(label: const Text('كوفي'), selected: _f == 1, onSelected: (_) => setState(() => _f = 1)),
              const SizedBox(width: 8),
              ChoiceChip(label: const Text('رقعة'), selected: _f == 2, onSelected: (_) => setState(() => _f = 2)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52), foregroundColor: Colors.white, side: BorderSide(color: Colors.white.op(0.25))),
                  onPressed: () {
                    context.read<LibraryStore>().addQuote(SavedQuote(text: widget.text, workId: widget.work.id, workTitle: widget.work.title, at: DateTime.now()));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حُفظت في خواطري')));
                  },
                  child: const Text('حفظ'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 52), backgroundColor: color, foregroundColor: MidadColors.ink),
                  onPressed: _busy ? null : _share,
                  icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.ios_share_rounded),
                  label: const Text('مشاركة كصورة'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  TextStyle _font(double size, Color c) => switch (_f) {
        1 => MidadText.title(size: size * 0.9, color: c, height: 1.7),
        2 => MidadText.callig(size: size, color: c),
        _ => MidadText.book(size: size, weight: FontWeight.w700, color: c, height: 1.8),
      };

  Widget _card(Color color) {
    final brand = Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Expanded(child: Text('— ${widget.work.title}', style: MidadText.title(size: 14, color: _t == 1 ? const Color(0xFF8A5A12) : color))),
      Text(AppConfig.appName, style: MidadText.callig(size: 18, color: _t == 1 ? const Color(0xFF8A5A12) : Colors.white.op(0.6))),
    ]);
    switch (_t) {
      case 1:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: MidadColors.paper, borderRadius: BorderRadius.circular(26)),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 30, 22, 22),
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFC9A869)), borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              Text('❁', style: MidadText.book(size: 22, color: const Color(0xFFB8863A))),
              Expanded(child: Center(child: Text(widget.text, textAlign: TextAlign.center, style: _font(24, MidadColors.paperInk)))),
              brand,
            ]),
          ),
        );
      case 2:
        return ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(fit: StackFit.expand, children: [
            CoverArt(art: widget.work.art, url: widget.work.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.op(0.8), Colors.black.op(0.35)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 30, 26, 22),
              child: Column(children: [
                Expanded(child: Center(child: Text(widget.text, textAlign: TextAlign.center, style: _font(25, Colors.white)))),
                brand,
              ]),
            ),
          ]),
        );
      default:
        return Container(
          padding: const EdgeInsets.fromLTRB(26, 30, 26, 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.op(0.1)),
            gradient: RadialGradient(center: const Alignment(-0.7, -0.8), radius: 1.2, colors: [color.op(0.25), const Color(0xFF0E1424)]),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('«', style: MidadText.book(size: 70, color: color, height: 0.9)),
            Expanded(child: Align(alignment: AlignmentDirectional.centerStart, child: Text(widget.text, style: _font(25, Colors.white)))),
            brand,
          ]),
        );
    }
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final ro = _boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await ro.toImage(pixelRatio: 3);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/atheer_${DateTime.now().millisecondsSinceEpoch}.png');
      await f.writeAsBytes(bytes!.buffer.asUint8List());
      await Share.shareXFiles([XFile(f.path)], text: '«${widget.text}» — من ${widget.work.title} على تطبيق ${AppConfig.appName}');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّرت المشاركة')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
