import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ambient/ambient_scene_engine.dart';
import '../data/repository.dart';
import '../design/atheer_design_system.dart';
import '../models.dart';
import '../state/library.dart';
import '../state/player.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'actions.dart';
import 'ambient_gallery_screen.dart';
import 'sleep_screen.dart';
import 'work_screen.dart';

/// عوالم الهدوء والنوم بالترتيب: أولها الأنسب لما قبل النوم.
const _calmWorlds = ['bedtime_stories', 'tranquility', 'spiritual_nourishment', 'quran_stories', 'nostalgic_tales'];

/// «سكينة»: تجربة ما قبل النوم والاسترخاء. ألوان ليلية منخفضة السطوع، أدوات قليلة،
/// قصص هادئة، مؤقت نوم مع خفوت اختياري، وشاشة سوداء والصوت مستمر.
class SakinaScreen extends StatelessWidget {
  const SakinaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cat = context.watch<ContentRepository>().catalog!;
    final lib = context.watch<LibraryStore>();
    final player = context.watch<PlayerController>();
    final calm = <Work>[
      for (final id in _calmWorlds) ...cat.worksOf(id),
    ].fold<List<Work>>([], (l, w) => l.any((x) => x.id == w.id) ? l : (l..add(w)));
    final short = calm.where((w) => w.minutes > 0 && w.minutes <= 12).toList();
    final first = calm.isEmpty ? null : calm.first;

    return Stack(children: [
      // سماء ليلية أعمق من باقي التطبيق.
      const Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0B1626), AtheerColors.midnight, Color(0xFF05080E)],
            ),
          ),
        ),
      ),
      CustomScrollView(slivers: [
        SliverSafeArea(
          bottom: false,
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AtheerSpacing.gutter, AtheerSpacing.xl, AtheerSpacing.gutter, 0),
              child: AtheerReveal(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.nightlight_round, size: AtheerIconSize.sm, color: AtheerColors.accent.op(0.8)),
                    const SizedBox(width: AtheerSpacing.sm),
                    Text('سكينة', style: AtheerType.overline(color: AtheerColors.accent.op(0.8))),
                  ]),
                  const SizedBox(height: AtheerSpacing.sm),
                  Text('اهدأ… ودع الكلمات تحملك إلى النوم', style: AtheerType.h1(color: AtheerColors.softIvory.op(0.9))),
                ]),
              ),
            ),
          ),
        ),
        // ابدأ النوم: أهدأ قصة + مؤقت + المشهد.
        if (first != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AtheerSpacing.gutter, AtheerSpacing.xxl, AtheerSpacing.gutter, 0),
              child: _SleepStart(work: first),
            ),
          ),
        // مؤقت النوم وإعداداته.
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AtheerSpacing.gutter, AtheerSpacing.lg, AtheerSpacing.gutter, 0),
            child: AtheerGlassCard(
              blur: false,
              fill: 0.04,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(player.sleepAt != null ? Icons.bedtime_rounded : Icons.bedtime_outlined, color: AtheerColors.accent, size: AtheerIconSize.md),
                  const SizedBox(width: AtheerSpacing.sm),
                  Expanded(child: Text('مؤقت النوم', style: AtheerType.h3())),
                  if (player.sleepAt != null)
                    TextButton(
                      onPressed: () => player.setSleep(null),
                      child: Text('إيقاف (${arNum(player.sleepAt!.difference(DateTime.now()).inMinutes + 1)} د)',
                          style: AtheerType.label(color: AtheerColors.accent)),
                    ),
                ]),
                const SizedBox(height: AtheerSpacing.md),
                Wrap(spacing: AtheerSpacing.sm, runSpacing: AtheerSpacing.sm, children: [
                  for (final m in const [15, 30, 45, 60])
                    _Pill(
                      label: '${arNum(m)} دقيقة',
                      selected: lib.sleepMinutes == m,
                      onTap: () {
                        lib.setSleepMinutes(m);
                        if (player.work != null) player.setSleep(m);
                      },
                    ),
                ]),
                const SizedBox(height: AtheerSpacing.sm),
                _Toggle(
                  label: 'خفوت الصوت تدريجيًا',
                  hint: 'ينخفض الصوت بهدوء قبل التوقف',
                  value: lib.sleepFade,
                  onChanged: lib.setSleepFade,
                ),
              ]),
            ),
          ),
        ),
        // أدوات قليلة: شاشة سوداء، والأجواء.
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AtheerSpacing.gutter, AtheerSpacing.md, AtheerSpacing.gutter, 0),
            child: Row(children: [
              Expanded(
                child: _Tile(
                  icon: Icons.dark_mode_rounded,
                  title: 'شاشة سوداء',
                  subtitle: 'الصوت مستمر',
                  onTap: () => Navigator.of(context).push(AtheerMotion.fadeThrough(const SleepScreen())),
                ),
              ),
              const SizedBox(width: AtheerSpacing.md),
              Expanded(
                child: _Tile(
                  icon: Icons.landscape_rounded,
                  title: 'أجواء أثير',
                  subtitle: 'مشاهد وأصوات طبيعية',
                  onTap: () => Navigator.of(context).push(AtheerMotion.fadeThrough(const AmbientGalleryScreen())),
                ),
              ),
            ]),
          ),
        ),
        if (short.isNotEmpty) ..._shelf(context, 'قصص قصيرة هادئة', short, 'أقل من ربع ساعة'),
        if (calm.isNotEmpty) ..._shelf(context, 'كل القصص الهادئة', calm, null),
        if (calm.isEmpty)
          const SliverToBoxAdapter(
            child: AtheerEmptyState(
              icon: Icons.nightlight_round,
              title: 'قريبًا تصل قصص النوم',
              message: 'نُعدّ لك حكايات هادئة لآخر اليوم.',
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: AtheerSpacing.xxxl)),
      ]),
    ]);
  }

  List<Widget> _shelf(BuildContext context, String title, List<Work> works, String? subtitle) => [
        SliverToBoxAdapter(child: AtheerSectionHeader(title: title, subtitle: subtitle)),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 262,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AtheerSpacing.gutter),
              itemCount: works.length,
              separatorBuilder: (_, __) => const SizedBox(width: AtheerSpacing.md + 2),
              itemBuilder: (_, i) => AtheerStoryCard(
                work: works[i],
                onTap: () => Navigator.of(context).push(AtheerMotion.fadeThrough(WorkScreen(work: works[i]))),
              ),
            ),
          ),
        ),
      ];
}

/// «ابدأ النوم»: يشغّل أهدأ قصة، يضبط المؤقت، ويختار وضع النوم للمشهد.
class _SleepStart extends StatelessWidget {
  final Work work;
  const _SleepStart({required this.work});

  @override
  Widget build(BuildContext context) {
    final lib = context.read<LibraryStore>();
    return AtheerGlassCard(
      blur: false,
      fill: 0.05,
      padding: const EdgeInsets.all(AtheerSpacing.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('جاهز للنوم؟', style: AtheerType.h2()),
        const SizedBox(height: AtheerSpacing.xs),
        Text('نبدأ «${work.title}» بمؤقت ${arNum(context.watch<LibraryStore>().sleepMinutes)} دقيقة، والشاشة تخفت حتى السواد.', style: AtheerType.bodyMedium()),
        const SizedBox(height: AtheerSpacing.lg),
        AtheerPrimaryButton(
          label: 'ابدأ النوم',
          icon: Icons.bedtime_rounded,
          expanded: true,
          onPressed: () {
            context.read<AmbientSceneSelector>().setQuality(AmbientQuality.sleep);
            listenTo(context, work, chapter: lib.lastChapter[work.id] ?? 0);
            context.read<PlayerController>().setSleep(lib.sleepMinutes);
          },
        ),
      ]),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _Tile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      excludeSemantics: true,
      child: AtheerGlassCard(
        blur: false,
        fill: 0.04,
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: AtheerColors.accent, size: AtheerIconSize.lg),
          const SizedBox(height: AtheerSpacing.md),
          Text(title, style: AtheerType.label()),
          const SizedBox(height: 2),
          Text(subtitle, style: AtheerType.bodySmall()),
        ]),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Pill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: AtheerPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AtheerMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: AtheerSpacing.lg, vertical: AtheerSpacing.sm + 2),
          decoration: BoxDecoration(
            color: selected ? AtheerColors.accent.op(0.18) : Colors.white.op(AtheerOpacity.glassFill),
            borderRadius: BorderRadius.circular(AtheerRadius.pill),
            border: Border.all(color: selected ? AtheerColors.accent.op(0.6) : Colors.white.op(AtheerOpacity.hairline)),
          ),
          child: Text(label, style: AtheerType.label(color: selected ? AtheerColors.accent : AtheerColors.textSecondary)),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final String? hint;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Toggle({required this.label, this.hint, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: AtheerType.label()),
            if (hint != null) Text(hint!, style: AtheerType.bodySmall()),
          ]),
        ),
        Switch(value: value, onChanged: onChanged, activeThumbColor: AtheerColors.accent),
      ]),
    );
  }
}
