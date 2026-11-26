import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/library.dart';
import '../theme.dart';
import '../widgets/cover_art.dart';
import '../widgets/story_card.dart';

/// شاشة الترحيب: تظهر مرة واحدة عند أول تشغيل.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String goal = 'sleep';

  static const goals = {'sleep': 'نوم هادئ', 'relax': 'استرخاء', 'reflect': 'تأمّل'};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MidadColors.ink,
      body: AtheerBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(gradient: MidadColors.palette.button, borderRadius: BorderRadius.circular(20)),
                child: Text('مرحبًا بك في أثير', style: MidadText.ui(size: 12, weight: FontWeight.w700, color: MidadColors.ink)),
              ),
              const SizedBox(height: 18),
              Text('عقلٌ هادئ ينتظرك', style: MidadText.title(size: 32)),
              const SizedBox(height: 8),
              Text('حكايات وكلمات تُروى بهدوء، لتسترخي وتنام على صوتٍ دافئ.',
                  style: MidadText.ui(size: 15, color: Colors.white70, height: 1.6)),
              const SizedBox(height: 22),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 0.78,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(36),
                        boxShadow: [BoxShadow(color: MidadColors.glow.op(0.45), blurRadius: 50)],
                      ),
                      child: const CoverArt(art: 'lantern', radius: BorderRadius.all(Radius.circular(36))),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text('ما الذي تبحث عنه؟', style: MidadText.ui(size: 13, color: Colors.white60)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in goals.entries)
                  ChoiceChipPill(label: e.value, selected: goal == e.key, onTap: () => setState(() => goal = e.key)),
              ]),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: AccentButton(label: 'ابدأ الآن', onTap: () => context.read<LibraryStore>().finishOnboarding(goal)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
