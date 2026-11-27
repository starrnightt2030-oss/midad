import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../theme.dart';
import '../motion.dart';
import '../tokens.dart';

class AtheerNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const AtheerNavItem({required this.icon, required this.activeIcon, required this.label});
}

/// شريط تنقّل سفلي عائم بزجاج خفيف ومؤشر اختيار متحرك.
/// يحترم اتجاه RTL تلقائيًا (أول عنصر على اليمين).
class AtheerBottomNavigation extends StatelessWidget {
  final List<AtheerNavItem> items;
  final int index;
  final ValueChanged<int> onTap;

  const AtheerBottomNavigation({super.key, required this.items, required this.index, required this.onTap});

  static const height = 66.0;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(AtheerSpacing.lg, 0, AtheerSpacing.lg, bottom > 0 ? bottom : AtheerSpacing.md),
      child: Container(
        height: height,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(AtheerRadius.pill), boxShadow: AtheerElevation.mid),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AtheerRadius.pill),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AtheerRadius.pill),
                color: AtheerColors.background.op(0.72),
                border: Border.all(color: Colors.white.op(AtheerOpacity.glassBorder), width: 0.8),
              ),
              child: LayoutBuilder(builder: (context, c) {
                final w = c.maxWidth / items.length;
                final rtl = Directionality.of(context) == TextDirection.rtl;
                final start = (rtl ? (items.length - 1 - index) : index) * w;
                return Stack(children: [
                  // المؤشر المتحرك.
                  AnimatedPositioned(
                    duration: AtheerMotion.of(context, AtheerMotion.slow),
                    curve: AtheerMotion.emphasized,
                    left: start + 6,
                    top: 6,
                    bottom: 6,
                    width: w - 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AtheerRadius.pill),
                        color: AtheerColors.accent.op(0.14),
                      ),
                    ),
                  ),
                  Row(children: [
                    for (var i = 0; i < items.length; i++) Expanded(child: _NavButton(item: items[i], selected: i == index, onTap: () => onTap(i))),
                  ]),
                ]);
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final AtheerNavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _NavButton({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = selected ? AtheerColors.accent : AtheerColors.textTertiary;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: AtheerPressable(
        onTap: onTap,
        scale: 0.94,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedSwitcher(
            duration: AtheerMotion.fast,
            child: Icon(selected ? item.activeIcon : item.icon, key: ValueKey(selected), size: AtheerIconSize.md, color: c),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: AtheerMotion.fast,
            style: AtheerType.labelSmall(color: selected ? AtheerColors.textPrimary : AtheerColors.textTertiary)
                .copyWith(fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
            child: Text(item.label, maxLines: 1, overflow: TextOverflow.fade, softWrap: false),
          ),
        ]),
      ),
    );
  }
}

/// عنوان قسم تحريري: سطر علوي اختياري، عنوان، وصف، و«عرض الكل».
class AtheerSectionHeader extends StatelessWidget {
  final String title;
  final String? overline;
  final String? subtitle;
  final String actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const AtheerSectionHeader({
    super.key,
    required this.title,
    this.overline,
    this.subtitle,
    this.onAction,
    this.actionLabel = 'عرض الكل',
    this.padding = const EdgeInsets.fromLTRB(AtheerSpacing.gutter, AtheerSpacing.section, AtheerSpacing.gutter, AtheerSpacing.md + 2),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (overline != null) ...[Text(overline!, style: AtheerType.overline()), const SizedBox(height: 4)],
            Semantics(header: true, child: Text(title, style: AtheerType.h2())),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AtheerType.bodySmall()),
            ],
          ]),
        ),
        if (onAction != null)
          Semantics(
            button: true,
            label: '$actionLabel: $title',
            excludeSemantics: true,
            child: AtheerPressable(
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AtheerSpacing.sm, horizontal: AtheerSpacing.xs),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(actionLabel, style: AtheerType.labelSmall(color: AtheerColors.accent)),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_left_rounded, size: AtheerIconSize.sm, color: AtheerColors.accent),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

/// شريط بحث زجاجي. لو [onTap] موجود يعمل كزر يفتح شاشة البحث، وإلا حقل كتابة.
class AtheerSearchBar extends StatelessWidget {
  final String hint;
  final VoidCallback? onTap;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final Widget? trailing;

  const AtheerSearchBar({
    super.key,
    this.hint = 'ابحث عن قصة، حكمة، أو قسم',
    this.onTap,
    this.controller,
    this.onChanged,
    this.autofocus = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final field = onTap != null
        ? Text(hint, style: AtheerType.bodyMedium(color: AtheerColors.textTertiary), maxLines: 1, overflow: TextOverflow.ellipsis)
        : TextField(
            controller: controller,
            onChanged: onChanged,
            autofocus: autofocus,
            cursorColor: AtheerColors.accent,
            style: AtheerType.bodyLarge(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: AtheerType.bodyMedium(color: AtheerColors.textTertiary),
            ),
          );
    final bar = Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: AtheerSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white.op(AtheerOpacity.glassFill),
        borderRadius: BorderRadius.circular(AtheerRadius.pill),
        border: Border.all(color: Colors.white.op(AtheerOpacity.hairline)),
      ),
      child: Row(children: [
        Icon(Icons.search_rounded, size: AtheerIconSize.md, color: AtheerColors.textSecondary),
        const SizedBox(width: AtheerSpacing.md),
        Expanded(child: field),
        if (trailing != null) trailing!,
      ]),
    );
    if (onTap == null) return bar;
    return Semantics(button: true, label: hint, excludeSemantics: true, child: AtheerPressable(onTap: onTap, scale: 0.99, child: bar));
  }
}
