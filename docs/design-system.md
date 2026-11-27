# AtheerDesignSystem

نظام التصميم الموحّد لأثير. كل شاشة جديدة تستورد ملفًا واحدًا:

```dart
import '../design/atheer_design_system.dart';
```

## الرموز (`lib/design/tokens.dart`)

| المجموعة | الاسم | ملاحظات |
|---|---|---|
| Colors | `AtheerColors` | Midnight `#090F19`، Deep Ocean `#182C40`، Serenity Green `#315B50`، Champagne Gold `#D9BE91`، Soft Ivory `#F0E8DB`. `accent`/`background`/`surface` تتبع ثيم المستخدم. |
| Typography | `AtheerType` | Alexandria للعناوين، IBM Plex Sans Arabic للنصوص، Amiri للحِكم. مضمّنة في `assets/fonts` (رخصة OFL) وتعمل بدون إنترنت. |
| Spacing | `AtheerSpacing` | شبكة 4، `gutter` = 22. |
| Radius | `AtheerRadius` | xs 8 → xl 32، `pill`. |
| Elevation | `AtheerElevation` | low / mid / high + `glow()` للزر الرئيسي فقط. |
| Gradients | `AtheerGradients` | خلفية، زر، ذهبي، تظليل الصور، `tint(color)` لشخصية القسم. |
| Opacity | `AtheerOpacity` | مستويات الزجاج والتظليل. |
| Icon sizes | `AtheerIconSize` | xs 14 → hero 56. |
| Breakpoints | `AtheerBreakpoints` | compact < 600 ≤ medium < 900 ≤ expanded. |

## الحركة (`lib/design/motion.dart`)

`AtheerMotion`: المدد (fast 180، normal 260، slow 350، cinematic 600)، منحنيات عضوية،
انتقالات `fadeThrough` و`rise`، اهتزاز خفيف، واحترام «تقليل الحركة» (من النظام أو `AtheerMotion.reduceMotion`).
`AtheerReveal` للظهور المتتابع، و`AtheerPressable` لإحساس الضغط.

## المكونات (`lib/design/components/`)

AtheerGlassCard · AtheerPrimaryButton · AtheerSecondaryButton · AtheerIconButton · AtheerStoryCard ·
AtheerCategoryCard · AtheerHeroBanner · AtheerMiniPlayer · AtheerBottomNavigation · AtheerSectionHeader ·
AtheerSearchBar · AtheerBottomSheet · AtheerSkeleton · AtheerEmptyState · AtheerErrorState · AtheerBadge · AtheerProgressLine

## لقطات

```
FONTS_DIR=$PWD/assets/fonts DS_FRAMES=/tmp/ds flutter test test/design_system_test.dart
```
