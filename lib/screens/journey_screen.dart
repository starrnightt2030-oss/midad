import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ambient/ambient_scene_engine.dart';
import '../config.dart';
import '../data/repository.dart';
import '../data/updates.dart';
import '../design/atheer_design_system.dart';
import '../state/account.dart';
import '../state/library.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'about_screen.dart';
import 'account_screen.dart';
import 'ambient_gallery_screen.dart';

/// «رحلتي مع أثير»: إحصائيات حقيقية من هذا الجهاز بلا منافسة ولا ضغط،
/// ثم الحساب والإعدادات والتخصيص.
class JourneyScreen extends StatelessWidget {
  const JourneyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryStore>();
    final cat = context.watch<ContentRepository>().catalog;
    final acc = context.watch<AccountStore>();
    final themes = context.watch<ThemeController>();
    final sel = context.watch<AmbientSceneSelector>();

    final total = lib.totalSeconds;
    final topWorlds = (lib.worldSeconds.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .map((e) => (world: cat?.worldById(e.key), secs: e.value))
        .where((e) => e.world != null)
        .take(3)
        .toList();
    final now = DateTime.now();
    final week = [
      for (var i = 6; i >= 0; i--)
        (day: now.subtract(Duration(days: i)), mins: (lib.dailySeconds[LibraryStore.dayKey(now.subtract(Duration(days: i)))] ?? 0) / 60),
    ];

    return CustomScrollView(slivers: [
      SliverSafeArea(
        bottom: false,
        sliver: SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AtheerSpacing.gutter, AtheerSpacing.xl, AtheerSpacing.gutter, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('رحلتي مع أثير', style: AtheerType.h1()),
              const SizedBox(height: AtheerSpacing.xs),
              Text('خطواتك الهادئة مع الكلمات. بلا أرقام تطاردك.', style: AtheerType.bodyMedium()),
            ]),
          ),
        ),
      ),
      // الإحصائيات.
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AtheerSpacing.gutter, AtheerSpacing.xl, AtheerSpacing.gutter, 0),
          child: total == 0 && lib.completed.isEmpty
              ? AtheerGlassCard(
                  blur: false,
                  child: Row(children: [
                    Icon(Icons.spa_outlined, color: AtheerColors.accent, size: AtheerIconSize.xl),
                    const SizedBox(width: AtheerSpacing.lg),
                    Expanded(child: Text('رحلتك تبدأ مع أول حكاية تسمعها. سنحفظ هنا وقت استماعك والقصص التي أتممتها.', style: AtheerType.bodyMedium())),
                  ]),
                )
              : Column(children: [
                  Row(children: [
                    Expanded(child: _Stat(icon: Icons.headphones_rounded, value: _duration(total), label: 'وقت الاستماع')),
                    const SizedBox(width: AtheerSpacing.md),
                    Expanded(child: _Stat(icon: Icons.task_alt_rounded, value: arNum(lib.completed.length), label: 'قصص مكتملة')),
                    const SizedBox(width: AtheerSpacing.md),
                    Expanded(child: _Stat(icon: Icons.auto_stories_outlined, value: arNum(lib.history.length), label: 'قصص سمعتها')),
                  ]),
                  const SizedBox(height: AtheerSpacing.md),
                  AtheerGlassCard(
                    blur: false,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('آخر سبعة أيام', style: AtheerType.label()),
                      const SizedBox(height: AtheerSpacing.lg),
                      SizedBox(height: 110, child: _WeekBars(week: week)),
                    ]),
                  ),
                  if (topWorlds.isNotEmpty) ...[
                    const SizedBox(height: AtheerSpacing.md),
                    AtheerGlassCard(
                      blur: false,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('عوالمك المفضلة', style: AtheerType.label()),
                        const SizedBox(height: AtheerSpacing.md),
                        for (final w in topWorlds)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AtheerSpacing.sm),
                            child: Row(children: [
                              Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: w.world!.color)),
                              const SizedBox(width: AtheerSpacing.sm),
                              Expanded(child: Text(w.world!.name, style: AtheerType.bodyMedium(color: AtheerColors.textPrimary))),
                              Text(_duration(w.secs), style: AtheerType.bodySmall()),
                            ]),
                          ),
                      ]),
                    ),
                  ],
                ]),
        ),
      ),
      // الحساب.
      const SliverToBoxAdapter(child: AtheerSectionHeader(title: 'الحساب')),
      SliverToBoxAdapter(
        child: _Group(children: [
          _Item(
            icon: acc.premium ? Icons.workspace_premium_rounded : Icons.person_outline_rounded,
            title: acc.signedIn ? (acc.email ?? 'حسابي') : 'تسجيل الدخول',
            subtitle: acc.premium ? 'مشترك' : (acc.signedIn ? 'غير مشترك — اعرف طريقة الاشتراك' : 'احفظ اشتراكك على حسابك'),
            onTap: () => Navigator.of(context).push(AtheerMotion.fadeThrough(const AccountScreen())),
          ),
        ]),
      ),
      // التخصيص.
      const SliverToBoxAdapter(child: AtheerSectionHeader(title: 'التخصيص')),
      SliverToBoxAdapter(
        child: _Group(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AtheerSpacing.lg, AtheerSpacing.md, AtheerSpacing.lg, 0),
            child: Row(children: [
              Icon(Icons.format_size_rounded, size: AtheerIconSize.md, color: AtheerColors.textSecondary),
              const SizedBox(width: AtheerSpacing.md),
              Expanded(child: Text('حجم خط القراءة', style: AtheerType.label())),
              Text('${arNum((lib.fontScale * 100).round())}٪', style: AtheerType.bodySmall()),
            ]),
          ),
          Slider(value: lib.fontScale, min: 0.8, max: 1.5, divisions: 7, onChanged: lib.setFontScale),
          _Switch(
            icon: Icons.motion_photos_off_outlined,
            title: 'تقليل الحركة',
            subtitle: 'انتقالات أهدأ بدون حركة زائدة',
            value: lib.reduceMotion,
            onChanged: lib.setReduceMotion,
          ),
          _Switch(
            icon: Icons.battery_saver_rounded,
            title: 'توفير البطارية',
            subtitle: 'مشاهد اقتصادية وحركة أقل',
            value: lib.batterySaver,
            onChanged: (v) {
              lib.setBatterySaver(v);
              if (v && (sel.quality == AmbientQuality.cinematic || sel.quality == AmbientQuality.balanced)) sel.setQuality(AmbientQuality.eco);
            },
          ),
          _Switch(
            icon: Icons.nights_stay_outlined,
            title: 'الوضع الليلي',
            subtitle: 'تعتيم هادئ للواجهة بعد العاشرة مساءً',
            value: lib.nightDim,
            onChanged: lib.setNightDim,
          ),
          _Switch(
            icon: Icons.music_note_rounded,
            title: 'صوت شاشة البداية',
            value: lib.introSound,
            onChanged: lib.setIntroSound,
          ),
          _Item(
            icon: Icons.landscape_rounded,
            title: 'جودة المشاهد والحركة',
            subtitle: sel.quality.label,
            onTap: () => Navigator.of(context).push(AtheerMotion.fadeThrough(const AmbientGalleryScreen())),
          ),
        ]),
      ),
      // تفضيلات المحتوى.
      const SliverToBoxAdapter(child: AtheerSectionHeader(title: 'ماذا تحب أن تسمع؟', subtitle: 'يساعدنا في ترتيب الرئيسية لك')),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AtheerSpacing.gutter),
          child: Wrap(spacing: AtheerSpacing.sm, runSpacing: AtheerSpacing.sm, children: [
            for (final g in const [('sleep', 'نومًا هادئًا'), ('relax', 'استرخاء'), ('reflect', 'تأمّلًا ومعنى')])
              _Pill(label: g.$2, selected: lib.goal == g.$1, onTap: () => lib.finishOnboarding(g.$1)),
          ]),
        ),
      ),
      // الألوان.
      const SliverToBoxAdapter(child: AtheerSectionHeader(title: 'ألوان التطبيق')),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AtheerSpacing.gutter),
        sliver: SliverGrid.count(
          crossAxisCount: AtheerBreakpoints.columns(context),
          mainAxisSpacing: AtheerSpacing.md,
          crossAxisSpacing: AtheerSpacing.md,
          childAspectRatio: 1.55,
          children: [
            for (final p in AtheerPalettes.all) _ThemeTile(palette: p, selected: themes.palette.id == p.id, onTap: () => themes.set(p)),
          ],
        ),
      ),
      // عن التطبيق.
      const SliverToBoxAdapter(child: AtheerSectionHeader(title: 'التطبيق')),
      SliverToBoxAdapter(
        child: _Group(children: [
          _Item(icon: Icons.system_update_rounded, title: 'التحقق من التحديثات', onTap: () => UpdateService.checkAndPrompt(context, manual: true)),
          _Item(
            icon: Icons.info_outline_rounded,
            title: 'عن ${AppConfig.appName}',
            onTap: () => Navigator.of(context).push(AtheerMotion.fadeThrough(const AboutScreen())),
          ),
        ]),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: AtheerSpacing.xxxl)),
    ]);
  }

  static String _duration(int secs) {
    final m = secs ~/ 60;
    if (m < 60) return '${arNum(m)} د';
    final h = m ~/ 60;
    final r = m % 60;
    return r == 0 ? '${arNum(h)} س' : '${arNum(h)} س ${arNum(r)} د';
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _Stat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return AtheerGlassCard(
      blur: false,
      padding: const EdgeInsets.symmetric(horizontal: AtheerSpacing.md, vertical: AtheerSpacing.lg),
      child: Column(children: [
        Icon(icon, color: AtheerColors.accent, size: AtheerIconSize.md),
        const SizedBox(height: AtheerSpacing.sm),
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: AtheerType.h3())),
        const SizedBox(height: 2),
        Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: AtheerType.bodySmall()),
      ]),
    );
  }
}

/// أعمدة هادئة لدقائق الاستماع في آخر سبعة أيام.
class _WeekBars extends StatelessWidget {
  final List<({DateTime day, double mins})> week;
  const _WeekBars({required this.week});

  static const _days = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
  static const _short = ['إثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت', 'أحد'];

  @override
  Widget build(BuildContext context) {
    final max = week.fold<double>(1, (m, e) => e.mins > m ? e.mins : m);
    return Semantics(
      label: week.map((e) => '${_days[e.day.weekday - 1]}: ${arNum(e.mins.round())} دقيقة').join('، '),
      child: ExcludeSemantics(
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final e in week)
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Flexible(
                  child: FractionallySizedBox(
                    heightFactor: (e.mins / max).clamp(0.04, 1.0),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: e.mins > 0
                            ? LinearGradient(
                                begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [AtheerColors.accent.op(0.45), AtheerColors.accent])
                            : null,
                        color: e.mins > 0 ? null : Colors.white.op(0.08),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(_short[e.day.weekday - 1], style: AtheerType.labelSmall(color: AtheerColors.textTertiary)),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AtheerSpacing.gutter),
        child: AtheerGlassCard(
          blur: false,
          padding: const EdgeInsets.symmetric(vertical: AtheerSpacing.xs),
          child: Material(type: MaterialType.transparency, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)),
        ),
      );
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  const _Item({required this.icon, required this.title, this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: AtheerColors.textSecondary),
        title: Text(title, style: AtheerType.label()),
        subtitle: subtitle == null ? null : Text(subtitle!, style: AtheerType.bodySmall()),
        trailing: Icon(Icons.chevron_left_rounded, color: AtheerColors.textTertiary),
        onTap: onTap,
      );
}

class _Switch extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Switch({required this.icon, required this.title, this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AtheerColors.accent,
        secondary: Icon(icon, color: AtheerColors.textSecondary),
        title: Text(title, style: AtheerType.label()),
        subtitle: subtitle == null ? null : Text(subtitle!, style: AtheerType.bodySmall()),
      );
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Pill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
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
              gradient: selected ? AtheerGradients.accent : null,
              color: selected ? null : Colors.white.op(AtheerOpacity.glassFill),
              borderRadius: BorderRadius.circular(AtheerRadius.pill),
              border: Border.all(color: selected ? Colors.transparent : Colors.white.op(AtheerOpacity.hairline)),
            ),
            child: Text(label, style: AtheerType.label(color: selected ? AtheerColors.background : AtheerColors.textPrimary)),
          ),
        ),
      );
}

class _ThemeTile extends StatelessWidget {
  final AtheerPalette palette;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeTile({required this.palette, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'ألوان ${palette.name}',
      excludeSemantics: true,
      child: AtheerPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AtheerMotion.normal,
          decoration: BoxDecoration(
            gradient: palette.background,
            borderRadius: BorderRadius.circular(AtheerRadius.lg - 4),
            border: Border.all(color: selected ? palette.accent : Colors.white.op(AtheerOpacity.hairline), width: selected ? 2 : 1),
          ),
          padding: const EdgeInsets.all(AtheerSpacing.md + 2),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 22, height: 22, decoration: BoxDecoration(shape: BoxShape.circle, gradient: palette.button)),
              const SizedBox(width: 6),
              Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: palette.glow)),
              const Spacer(),
              if (selected) Icon(Icons.check_circle_rounded, color: palette.accent, size: 20),
            ]),
            const Spacer(),
            Text(palette.name, style: AtheerType.label()),
          ]),
        ),
      ),
    );
  }
}
