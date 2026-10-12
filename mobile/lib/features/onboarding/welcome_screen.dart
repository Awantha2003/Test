import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.brandDark, AppColors.brand]),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.shield_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                Text('Rakawala', style: t.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              ]),
              const Spacer(),
              Text("Know they're safe.\nEvery step of the way.",
                  style: t.textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.15)),
              const SizedBox(height: 16),
              Text('Live location, class-arrival alerts and one-tap SOS, built for Sri Lankan families.',
                  style: t.textTheme.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.85))),
              const SizedBox(height: 28),
              const _Bullet(icon: Icons.location_on_rounded, text: 'See where your children are, live'),
              const _Bullet(icon: Icons.menu_book_rounded, text: 'Get told when they reach tuition class'),
              const _Bullet(icon: Icons.sos_rounded, text: 'SOS by button or secret voice word'),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.brandDark),
                onPressed: () => context.push('/auth/sign-up'),
                child: const Text("I'm a parent / guardian"),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                onPressed: () => context.push('/child/pair'),
                child: const Text("This is my child's phone"),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => context.push('/auth/sign-in'),
                  child: const Text('Already have an account? Sign in', style: TextStyle(color: Colors.white)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15))),
        ]),
      );
}
