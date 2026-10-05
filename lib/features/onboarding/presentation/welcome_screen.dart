import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/sketch_colors.dart';
import '../../../core/widgets/fade_slide_in.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFFF6F3EC,
                  ), // fixed light card, not SketchColors.paper -- stays legible either theme
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Image.asset(
                  'assets/images/sketch/app_logo_full.png',
                  width: 220,
                  filterQuality: FilterQuality.high,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Find people. Fill your team. Play now.',
                  style: TextStyle(color: SketchColors.inkFaint),
                ),
              ),
              const Spacer(),
              FadeSlideIn(
                delay: const Duration(milliseconds: 150),
                child: Image.asset(
                  'assets/images/sketch/onb2_people.png',
                  height: 220,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.sports_soccer,
                    size: 120,
                    color: SketchColors.inkFaint,
                  ),
                ),
              ),
              const Spacer(),
              FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: () => context.push('/onboarding'),
                      child: const Text('Get Started'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.push('/login'),
                      child: const Text('I already have an account'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
