import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ambient/ambient_scene_engine.dart';
import '../ambient/ambient_style.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// مكتبة «أجواء أثير»: تصفح المشاهد الحية حسب التصنيف، معاينة، مفضلة، واختيار يدوي أو تلقائي.
class AmbientGalleryScreen extends StatefulWidget {
  const AmbientGalleryScreen({super.key});

  @override
  State<AmbientGalleryScreen> createState() => _AmbientGalleryScreenState();
}

class _AmbientGalleryScreenState extends State<AmbientGalleryScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final sel = context.watch<AmbientSceneSelector>();
    final all = sel.registry.scenes;
    final scenes = switch (_filter) {
      'all' => all.where((s) => !s.categories.contains('fantasy')).toList(),
      'favs' => all.where((s) => sel.isFav(s.id)).toList(),
      _ => sel.registry.inCategory(_filter),
    };
    return Scaffold(
      backgroundColor: AmbientColors.midnightNavy,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(children: [
                IconButton(tooltip: 'رجوع', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_forward_rounded)),
                Expanded(child: Text('أجواء أثير', style: MidadText.title(size: 24, color: AmbientColors.softIvory))),
                IconButton(
                  tooltip: 'جودة المشاهد',
                  onPressed: () => showAmbientQualitySheet(context),
                  icon: const Icon(Icons.tune_rounded, color: AmbientColors.warmGold),
                ),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
              child: Text('خلفيات حية هادئة ترافق الاستماع', style: MidadText.ui(size: 13, color: AmbientColors.softIvory.withValues(alpha: 0.7))),
            ),
          ),
          SliverToBoxAdapter(child: _ModeSwitch(sel: sel)),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 46,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
                _chip('الكل', 'all'),
                _chip('المفضلة', 'favs', icon: Icons.favorite_rounded),
                for (final c in AmbientCategory.all) _chip(c.name, c.id),
              ]),
            ),
          ),
          if (!sel.registry.loaded)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (scenes.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(_filter == 'favs' ? 'اضغط القلب على أي مشهد ليظهر هنا' : 'لا توجد مشاهد هنا بعد',
                    style: MidadText.ui(color: Colors.white60)),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.62),
                delegate: SliverChildBuilderDelegate((context, i) => _SceneCard(scene: scenes[i]), childCount: scenes.length),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _chip(String label, String id, {IconData? icon}) {
    final on = _filter == id;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        avatar: icon == null ? null : Icon(icon, size: 16, color: on ? AmbientColors.midnightNavy : AmbientColors.warmGold),
        label: Text(label),
        selected: on,
        showCheckmark: false,
        selectedColor: AmbientColors.warmGold,
        backgroundColor: AmbientColors.calmBlue,
        labelStyle: MidadText.ui(size: 13, weight: FontWeight.w600, color: on ? AmbientColors.midnightNavy : AmbientColors.softIvory),
        side: BorderSide.none,
        onSelected: (_) => setState(() => _filter = id),
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  final AmbientSceneSelector sel;
  const _ModeSwitch({required this.sel});

  @override
  Widget build(BuildContext context) {
    final chosen = sel.manualId == null ? null : sel.registry[sel.manualId!];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: AmbientColors.panel(radius: 16, opacity: 0.0).copyWith(color: AmbientColors.calmBlue),
        child: Row(children: [
          _seg(context, 'تلقائي', 'حسب جو القصة', !sel.manual, sel.setAuto),
          _seg(context, 'يدوي', chosen?.title ?? 'اختر مشهدًا', sel.manual, () {
            if (chosen != null) sel.choose(chosen.id);
          }),
        ]),
      ),
    );
  }

  Widget _seg(BuildContext context, String title, String sub, bool on, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: on ? AmbientColors.naturalTeal : Colors.transparent, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Text(title, style: MidadText.ui(weight: FontWeight.w700, color: AmbientColors.softIvory)),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: MidadText.ui(size: 11, color: Colors.white60)),
            ]),
          ),
        ),
      );
}

class _SceneCard extends StatelessWidget {
  final AmbientScene scene;
  const _SceneCard({required this.scene});

  @override
  Widget build(BuildContext context) {
    final sel = context.watch<AmbientSceneSelector>();
    final active = sel.manual && sel.manualId == scene.id;
    final fav = sel.isFav(scene.id);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(fadeRoute(AmbientPreviewScreen(scene: scene))),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AmbientColors.warmGold : Colors.white12, width: active ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          // الصورة المصغرة فقط (ليست الخلفية الكاملة) حتى لا تمتلئ الذاكرة.
          Image.asset(scene.thumb, fit: BoxFit.cover, cacheWidth: (200 * dpr).round(), gaplessPlayback: true),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xDD080F1E)], stops: [0.5, 1]),
            ),
          ),
          PositionedDirectional(
            top: 4,
            end: 4,
            child: IconButton(
              tooltip: fav ? 'إزالة من المفضلة' : 'أضف للمفضلة',
              onPressed: () => sel.toggleFav(scene.id),
              icon: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: fav ? AmbientColors.warmGold : Colors.white),
            ),
          ),
          if (scene.lowRes)
            PositionedDirectional(
              top: 12,
              start: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: AmbientColors.panel(radius: 10, opacity: 0.6),
                child: Text('نسخة مؤقتة', style: MidadText.ui(size: 10, color: AmbientColors.softIvory)),
              ),
            ),
          PositionedDirectional(
            start: 12,
            end: 12,
            bottom: 12,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(scene.title, style: MidadText.ui(size: 15, weight: FontWeight.w700, color: AmbientColors.softIvory)),
              if (active) Text('المشهد المختار', style: MidadText.ui(size: 11, color: AmbientColors.warmGold)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// معاينة مشهد حي بملء الشاشة قبل اختياره.
class AmbientPreviewScreen extends StatelessWidget {
  final AmbientScene scene;
  const AmbientPreviewScreen({super.key, required this.scene});

  @override
  Widget build(BuildContext context) {
    final sel = context.watch<AmbientSceneSelector>();
    final fav = sel.isFav(scene.id);
    final active = sel.manual && sel.manualId == scene.id;
    final cats = AmbientCategory.all.where((c) => scene.categories.contains(c.id)).map((c) => c.name).join(' · ');
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        AmbientSceneView(scene: scene, quality: sel.quality),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66080F1E), Colors.transparent, Colors.transparent, Color(0xE6080F1E)],
                stops: [0, 0.18, 0.6, 1],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(children: [
            Row(children: [
              IconButton(tooltip: 'رجوع', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_forward_rounded)),
              const Spacer(),
              IconButton(
                tooltip: fav ? 'إزالة من المفضلة' : 'أضف للمفضلة',
                onPressed: () => sel.toggleFav(scene.id),
                icon: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: fav ? AmbientColors.warmGold : null),
              ),
            ]),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(scene.title, style: MidadText.title(size: 28, color: AmbientColors.softIvory)),
                const SizedBox(height: 4),
                Text(cats, style: MidadText.ui(size: 13, color: AmbientColors.warmGold)),
                if (scene.lowRes) ...[
                  const SizedBox(height: 8),
                  Text('هذه نسخة مؤقتة منخفضة الدقة وسيتم استبدالها بالصورة الأصلية.',
                      style: MidadText.ui(size: 12, color: Colors.white60)),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AmbientColors.warmGold,
                    foregroundColor: AmbientColors.midnightNavy,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: active
                      ? null
                      : () {
                          sel.choose(scene.id);
                          Navigator.pop(context);
                        },
                  icon: Icon(active ? Icons.check_rounded : Icons.wallpaper_rounded),
                  label: Text(active ? 'هذا هو مشهدك الحالي' : 'استخدم هذا المشهد', style: MidadText.ui(weight: FontWeight.w700, color: AmbientColors.midnightNavy)),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// ورقة اختيار وضع الجودة.
Future<void> showAmbientQualitySheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AmbientColors.calmBlue,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => Consumer<AmbientSceneSelector>(
      builder: (context, sel, _) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(8, 16, 8, 12), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('جودة المشاهد الحية', style: MidadText.title(size: 18, color: AmbientColors.softIvory)),
          ),
          if (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('«تقليل الحركة» مفعّل في جهازك، فالخلفيات ستظهر ثابتة.', style: MidadText.ui(size: 12, color: AmbientColors.warmGold)),
            ),
          for (final q in AmbientQuality.values)
            ListTile(
              leading: Icon(sel.quality == q ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: sel.quality == q ? AmbientColors.warmGold : Colors.white54),
              title: Text(q.label, style: MidadText.ui(weight: FontWeight.w700, color: AmbientColors.softIvory)),
              subtitle: Text(q.hint, style: MidadText.ui(size: 12, color: Colors.white60)),
              onTap: () => sel.setQuality(q),
            ),
          SwitchListTile(
            value: sel.autoAdapt,
            onChanged: sel.setAutoAdapt,
            activeThumbColor: AmbientColors.warmGold,
            title: Text('خفض الجودة تلقائيًا عند الحاجة', style: MidadText.ui(weight: FontWeight.w600, color: AmbientColors.softIvory)),
            subtitle: Text('لو كان الجهاز يجهد، تقل المؤثرات للحفاظ على السلاسة', style: MidadText.ui(size: 12, color: Colors.white60)),
          ),
        ]),
      ),
    ),
  );
}
