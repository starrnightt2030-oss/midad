import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'ambient_asset_manager.dart';
import 'ambient_particle_system.dart';
import 'ambient_performance_manager.dart';
import 'ambient_scene.dart';
import 'ambient_scene_controller.dart';
import 'ambient_shader_manager.dart';

/// يعرض مشهدًا حيًا بملء المساحة: صورة + مؤثرات شيدر موضعية داخل الأقنعة + جسيمات.
///
/// - يرسم عبر CustomPainter مربوط بساعة المشهد، فلا يُعاد بناء أي Widget مع كل إطار.
/// - يتوقف عند إخفاء الشاشة (TickerMode) أو خروج التطبيق للخلفية، والصوت لا يتأثر.
/// - لو تعذّر الشيدر أو القناع يعرض الصورة ثابتة (مع الجسيمات إن سمح الوضع).
class AmbientSceneView extends StatefulWidget {
  final AmbientScene scene;
  final AmbientQuality quality;

  /// يتغير لإعادة ضبط تعتيم وضع النوم (مثلًا عند لمس الشاشة).
  final int wakeEpoch;

  /// مدة التعتيم التدريجي في وضع النوم.
  final Duration sleepFade;

  const AmbientSceneView({
    super.key,
    required this.scene,
    this.quality = AmbientQuality.balanced,
    this.wakeEpoch = 0,
    this.sleepFade = const Duration(minutes: 3),
  });

  @override
  State<AmbientSceneView> createState() => _AmbientSceneViewState();
}

class _AmbientSceneViewState extends State<AmbientSceneView> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AmbientSceneController _clock = AmbientSceneController(this);
  final _perf = AmbientPerformanceManager.instance;
  ui.Image? _image;
  ui.Image? _mask;
  ui.FragmentShader? _shader;
  AmbientParticleSystem? _particles;
  int _loadToken = 0;
  double _sleepStart = 0;
  AmbientQuality _effective = AmbientQuality.balanced;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _perf.watch();
    _perf.addListener(_onPerf);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_image == null && _loadToken == 0) _load();
    _apply();
  }

  @override
  void didUpdateWidget(covariant AmbientSceneView old) {
    super.didUpdateWidget(old);
    if (old.scene.id != widget.scene.id) {
      _clock.resetTime();
      _load();
    }
    if (old.wakeEpoch != widget.wakeEpoch || old.quality != widget.quality) _sleepStart = _clock.time;
    _apply();
  }

  void _onPerf() {
    if (mounted) setState(_apply);
  }

  /// يحسب الوضع الفعلي ويضبط معدل الإطارات.
  void _apply() {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _effective = _perf.effective(widget.quality, reduceMotion: reduce);
    final b = AmbientPerformanceManager.budgetFor(_effective);
    _clock.fps = b.fps;
    if (b.animated && _image != null) {
      _clock.start();
    } else {
      _clock.stop();
    }
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    final scene = widget.scene;
    final view = View.of(context);
    final maxW = (view.physicalSize.width.clamp(360.0, 1440.0)).round();
    final results = await Future.wait([
      AmbientAssetManager.instance.acquire(scene.asset, maxWidth: maxW),
      if (scene.mask != null) AmbientAssetManager.instance.acquire(scene.mask!) else Future<ui.Image?>.value(null),
      AmbientShaderManager.instance.program(),
    ]);
    final img = results[0] as ui.Image?, mask = results[1] as ui.Image?;
    final program = results[2] as ui.FragmentProgram?;
    if (!mounted || token != _loadToken) {
      img?.dispose();
      mask?.dispose();
      return;
    }
    _disposeImages();
    _image = img;
    _mask = mask;
    _shader ??= program?.fragmentShader();
    _particles = AmbientParticleSystem(scene.particles);
    _sleepStart = _clock.time;
    setState(_apply);
  }

  void _disposeImages() {
    _image?.dispose();
    _mask?.dispose();
    _image = null;
    _mask = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _clock.paused = state != AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _perf.removeListener(_onPerf);
    _perf.unwatch();
    _clock.dispose();
    _shader?.dispose();
    _disposeImages();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final budget = AmbientPerformanceManager.budgetFor(_effective);
    return RepaintBoundary(
      child: CustomPaint(
        isComplex: true,
        willChange: budget.animated,
        painter: _AmbientPainter(
          scene: widget.scene,
          image: _image,
          mask: _mask,
          shader: _mask == null ? null : _shader,
          particles: _particles,
          clock: _clock,
          budget: budget,
          sleep: _effective == AmbientQuality.sleep,
          sleepStart: _sleepStart,
          sleepSeconds: widget.sleepFade.inMilliseconds / 1000,
          onAsleep: () => _clock.stop(),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  final AmbientScene scene;
  final ui.Image? image;
  final ui.Image? mask;
  final ui.FragmentShader? shader;
  final AmbientParticleSystem? particles;
  final AmbientSceneController clock;
  final AmbientBudget budget;
  final bool sleep;
  final double sleepStart;
  final double sleepSeconds;
  final VoidCallback onAsleep;

  _AmbientPainter({
    required this.scene,
    required this.image,
    required this.mask,
    required this.shader,
    required this.particles,
    required this.clock,
    required this.budget,
    required this.sleep,
    required this.sleepStart,
    required this.sleepSeconds,
    required this.onAsleep,
  }) : super(repaint: clock);

  static final Paint _imagePaint = Paint()..filterQuality = FilterQuality.medium;
  static final Paint _shaderPaint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final img = image;
    if (img == null) {
      canvas.drawRect(rect, Paint()..color = scene.tint);
      return;
    }
    final t = clock.time;
    var dim = 1.0;
    if (sleep) {
      dim = (1 - (t - sleepStart) / sleepSeconds).clamp(0.0, 1.0);
      dim = dim * dim;
      if (dim <= 0.001) {
        canvas.drawRect(rect, Paint()..color = const Color(0xFF000000));
        WidgetsBinding.instance.addPostFrameCallback((_) => onAsleep());
        return;
      }
    }
    final imgSize = Size(img.width.toDouble(), img.height.toDouble());
    final tf = CoverTransform.of(size, imgSize, scene.focus);
    final sh = shader;
    if (sh != null && mask != null && budget.shaderLevel > 0) {
      _setUniforms(sh, size, imgSize, t, dim);
      sh.setImageSampler(0, img, filterQuality: FilterQuality.medium);
      sh.setImageSampler(1, mask!, filterQuality: FilterQuality.low);
      _shaderPaint.shader = sh;
      canvas.drawRect(rect, _shaderPaint);
    } else {
      final dst = Rect.fromLTWH(tf.offset.dx, tf.offset.dy, imgSize.width * tf.scale, imgSize.height * tf.scale);
      canvas.drawImageRect(img, Offset.zero & imgSize, dst, _imagePaint);
      if (dim < 1) canvas.drawRect(rect, Paint()..color = Color.fromRGBO(0, 0, 0, 1 - dim));
    }
    if (budget.animated && budget.particles > 0) {
      // الجسيمات معرّفة بإحداثيات الصورة الأصلية، نحوّلها بنفس تحويل الصورة.
      final ptf = CoverTransform.of(size, scene.size, scene.focus);
      canvas.save();
      canvas.clipRect(rect);
      particles?.paint(canvas, size, scene, ptf, t, budget.particles, dim);
      canvas.restore();
    }
  }

  void _setUniforms(ui.FragmentShader sh, Size size, Size img, double t, double dim) {
    var i = 0;
    void f(double v) => sh.setFloat(i++, v);
    f(size.width);
    f(size.height);
    f(img.width);
    f(img.height);
    f(scene.focus.dx);
    f(scene.focus.dy);
    f(t);
    f(budget.shaderLevel);
    f(dim);
    final l = scene.layers;
    AmbientLayer? at(int k) => k < l.length ? l[k] : null;
    for (var k = 0; k < 4; k++) {
      f((at(k)?.effect.code ?? 0).toDouble());
    }
    for (var k = 0; k < 4; k++) {
      f(at(k)?.speed ?? 0);
    }
    for (var k = 0; k < 4; k++) {
      f(at(k)?.amount ?? 0);
    }
    for (var k = 0; k < 4; k++) {
      f(at(k)?.scale ?? 1);
    }
    for (var k = 0; k < 4; k++) {
      f(at(k)?.dir.dx ?? 0);
    }
    for (var k = 0; k < 4; k++) {
      f(at(k)?.dir.dy ?? 0);
    }
    for (var k = 0; k < 4; k++) {
      final ch = at(k)?.channel ?? -1;
      for (var c = 0; c < 4; c++) {
        f(c == ch ? 1 : 0);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter old) =>
      old.image != image || old.mask != mask || old.shader != shader || old.budget != budget || old.scene != scene || old.sleepStart != sleepStart || old.sleep != sleep;
}
