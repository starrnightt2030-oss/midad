import 'dart:ui' show Color, Offset, Rect, Size;

/// أنواع المؤثرات التي يفهمها الشيدر (نفس الأرقام في shaders/ambient_scene.frag).
enum AmbientEffect {
  none(0),
  ripple(1),
  flow(2),
  drift(3),
  glow(4),
  mist(5),
  sway(6),
  aurora(7),
  twinkle(8),
  waves(9),
  rays(10);

  final int code;
  const AmbientEffect(this.code);

  static AmbientEffect parse(String? s) =>
      AmbientEffect.values.firstWhere((e) => e.name == s, orElse: () => AmbientEffect.none);
}

/// مؤثر موضعي واحد: يعمل داخل قناة من قناع المشهد فقط.
class AmbientLayer {
  final AmbientEffect effect;

  /// 0 = R، 1 = G، 2 = B.
  final int channel;
  final double speed;
  final double amount;
  final double scale;
  final Offset dir;

  const AmbientLayer({
    required this.effect,
    required this.channel,
    this.speed = 1,
    this.amount = 0.004,
    this.scale = 1,
    this.dir = const Offset(1, 0),
  });

  factory AmbientLayer.fromJson(Map<String, dynamic> j) {
    final d = (j['dir'] as List?)?.cast<num>();
    return AmbientLayer(
      effect: AmbientEffect.parse(j['effect'] as String?),
      channel: switch (j['channel']) { 'g' => 1, 'b' => 2, _ => 0 },
      speed: (j['speed'] as num?)?.toDouble() ?? 1,
      amount: (j['amount'] as num?)?.toDouble() ?? 0.004,
      scale: (j['scale'] as num?)?.toDouble() ?? 1,
      dir: d == null || d.length < 2 ? const Offset(1, 0) : Offset(d[0].toDouble(), d[1].toDouble()),
    );
  }
}

/// أنواع الجسيمات الإجرائية التي ترسم فوق الصورة.
enum ParticleKind { rain, glassDrops, snow, embers, steam, fireflies, petals, motes, spray, bubbles }

/// باعث جسيمات داخل مستطيل بإحداثيات الصورة النسبية (0..1).
class ParticleEmitter {
  final ParticleKind kind;
  final Rect area;
  final int count;
  final Color color;
  final double size;
  final double speed;

  const ParticleEmitter({
    required this.kind,
    required this.area,
    this.count = 20,
    this.color = const Color(0xFFFFFFFF),
    this.size = 1,
    this.speed = 1,
  });

  factory ParticleEmitter.fromJson(Map<String, dynamic> j) {
    final a = ((j['area'] as List?) ?? const [0, 0, 1, 1]).cast<num>();
    return ParticleEmitter(
      kind: ParticleKind.values.firstWhere((k) => k.name == j['type'], orElse: () => ParticleKind.motes),
      area: Rect.fromLTRB(a[0].toDouble(), a[1].toDouble(), a[2].toDouble(), a[3].toDouble()),
      count: (j['count'] as num?)?.toInt() ?? 20,
      color: _hex(j['color'] as String?) ?? const Color(0xFFFFFFFF),
      size: (j['size'] as num?)?.toDouble() ?? 1,
      speed: (j['speed'] as num?)?.toDouble() ?? 1,
    );
  }
}

Color? _hex(String? s) {
  if (s == null) return null;
  var h = s.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(v);
}

/// تصنيفات مكتبة «أجواء أثير».
class AmbientCategory {
  final String id;
  final String name;
  const AmbientCategory(this.id, this.name);

  static const all = [
    AmbientCategory('sleep', 'النوم والسكينة'),
    AmbientCategory('nature', 'الطبيعة'),
    AmbientCategory('rain_winter', 'المطر والشتاء'),
    AmbientCategory('spiritual', 'الأجواء الروحانية'),
    AmbientCategory('meditation', 'التأمل والاسترخاء'),
    AmbientCategory('hope', 'الأمل وتنمية الذات'),
    AmbientCategory('fantasy', 'خيال'),
  ];
}

/// تعريف مشهد حي كما في assets/ambient/<id>/scene.json.
class AmbientScene {
  final String id;
  final String title;
  final List<String> categories;
  final String asset;
  final String? mask;
  final String thumb;
  final Size size;

  /// individual = صورة أصلية عالية الدقة، collage_preview = نسخة مؤقتة صغيرة.
  final String sourceQuality;
  final bool masksReady;

  /// نقطة المحاذاة عند قص الصورة لملء الشاشة.
  final Offset focus;
  final Color tint;
  final List<AmbientLayer> layers;
  final List<ParticleEmitter> particles;

  /// صوت محيطي مقترح (rain, ocean, forest, fireplace, wind, stream).
  final String? sound;

  /// كلمات المشاهد القديمة (rain, sea, night...) التي يناسبها هذا المشهد في الاختيار التلقائي.
  final List<String> moods;

  const AmbientScene({
    required this.id,
    required this.title,
    required this.categories,
    required this.asset,
    required this.thumb,
    required this.size,
    this.mask,
    this.sourceQuality = 'individual',
    this.masksReady = false,
    this.focus = const Offset(0.5, 0.5),
    this.tint = const Color(0xFF192C40),
    this.layers = const [],
    this.particles = const [],
    this.sound,
    this.moods = const [],
  });

  bool get lowRes => sourceQuality != 'individual';

  factory AmbientScene.fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String;
    final base = 'assets/ambient/$id';
    final f = (j['focus'] as List?)?.cast<num>();
    return AmbientScene(
      id: id,
      title: (j['title'] ?? id) as String,
      categories: ((j['categories'] as List?) ?? const []).cast<String>(),
      asset: (j['asset'] ?? '$base/background.webp') as String,
      mask: j['masks_ready'] == true ? (j['mask'] ?? '$base/mask.webp') as String : null,
      thumb: (j['thumb'] ?? '$base/thumb.webp') as String,
      size: Size((j['width'] as num?)?.toDouble() ?? 941, (j['height'] as num?)?.toDouble() ?? 1672),
      sourceQuality: (j['source_quality'] ?? 'individual') as String,
      masksReady: j['masks_ready'] == true,
      focus: f == null || f.length < 2 ? const Offset(0.5, 0.5) : Offset(f[0].toDouble(), f[1].toDouble()),
      tint: _hex(j['tint'] as String?) ?? const Color(0xFF192C40),
      layers: ((j['layers'] as List?) ?? const [])
          .map((e) => AmbientLayer.fromJson(e as Map<String, dynamic>))
          .where((l) => l.effect != AmbientEffect.none)
          .take(4)
          .toList(),
      particles: ((j['particles'] as List?) ?? const []).map((e) => ParticleEmitter.fromJson(e as Map<String, dynamic>)).toList(),
      sound: j['sound'] as String?,
      moods: ((j['moods'] as List?) ?? const []).cast<String>(),
    );
  }
}

/// تحويل BoxFit.cover الموحّد: نفس الحساب في الشيدر وفي الجسيمات،
/// فتبقى الجسيمات والأقنعة فوق نفس بكسلات الصورة على أي مقاس شاشة.
class CoverTransform {
  final double scale;
  final Offset offset;
  const CoverTransform(this.scale, this.offset);

  factory CoverTransform.of(Size view, Size image, Offset focus) {
    final s = view.width / image.width > view.height / image.height ? view.width / image.width : view.height / image.height;
    final shown = Size(image.width * s, image.height * s);
    return CoverTransform(s, Offset((view.width - shown.width) * focus.dx, (view.height - shown.height) * focus.dy));
  }

  /// من إحداثيات الصورة النسبية (0..1) إلى بكسل الشاشة.
  Offset map(Offset uv, Size image) => Offset(offset.dx + uv.dx * image.width * scale, offset.dy + uv.dy * image.height * scale);
}
