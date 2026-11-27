import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../design/atheer_design_system.dart';
import '../state/player.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// شاشة سوداء للنوم: الصوت يستمر كما هو، والشاشة سوداء تمامًا.
/// لمسة واحدة تُظهر أدوات قليلة باهتة لثوانٍ، ثم تعود سوداء.
class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  bool _show = true;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _arm();
  }

  void _arm() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _show = false);
    });
  }

  @override
  void dispose() {
    _hide?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerController>();
    final dim = Colors.white.op(0.38);
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _show = true);
          _arm();
        },
        child: AnimatedOpacity(
          opacity: _show ? 1 : 0,
          duration: _show ? AtheerMotion.slow : const Duration(seconds: 2),
          child: IgnorePointer(
            ignoring: !_show,
            child: SafeArea(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (p.work != null) Text(p.work!.title, style: AtheerType.label(color: dim)),
                  if (p.sleepAt != null) ...[
                    const SizedBox(height: AtheerSpacing.xs),
                    Text('يتوقف بعد ${arNum(p.sleepAt!.difference(DateTime.now()).inMinutes + 1)} دقيقة', style: AtheerType.bodySmall(color: dim)),
                  ],
                  const SizedBox(height: AtheerSpacing.xl),
                  if (p.work != null)
                    IconButton(
                      tooltip: p.playing ? 'إيقاف مؤقت' : 'تشغيل',
                      iconSize: 44,
                      color: dim,
                      onPressed: () {
                        p.toggle();
                        _arm();
                      },
                      icon: Icon(p.playing ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded),
                    ),
                  const SizedBox(height: AtheerSpacing.xl),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('خروج', style: AtheerType.label(color: dim)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
