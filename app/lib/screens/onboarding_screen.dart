import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'auth_screens.dart';
import 'main_shell.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _page = 0;

  static const _pages = [
    ('🥬', 'Fresh from the Mandi', 'Every morning we pick the freshest fruits & vegetables straight from the mandi.', Color(0xFFE8F5E9)),
    ('⚖️', 'Buy by kg, gram or piece', '250 g, 500 g, 1 kg, dozens or bunches — buy exactly what your kitchen needs.', Color(0xFFFFF3E0)),
    ('🚚', 'Delivered to your doorstep', 'Choose a delivery slot and get mandi prices at home. Pay cash on delivery.', Color(0xFFFCE4EC)),
  ];

  Future<void> _finish() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('onboarding_seen', true);
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => context.read<AuthProvider>().isLoggedIn ? const MainShell() : const LoginScreen(gate: true)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _finish, child: const Text('Skip'))),
          Expanded(
            child: PageView.builder(
              controller: _pc,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) {
                final (emoji, title, body, color) = _pages[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    TweenAnimationBuilder<double>(
                      key: ValueKey(i),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.elasticOut,
                      builder: (_, v, child) => Transform.scale(scale: v, child: child),
                      child: Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text(emoji, style: const TextStyle(fontSize: 120)),
                      ),
                    ),
                    const SizedBox(height: 48),
                    Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Text(body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: AppColors.textMuted, height: 1.5)),
                  ]),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _pages.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _page == i ? 26 : 8,
                height: 8,
                decoration: BoxDecoration(color: _page == i ? AppColors.primary : AppColors.border, borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: ElevatedButton(
              onPressed: () => _page == _pages.length - 1 ? _finish() : _pc.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic),
              child: Text(_page == _pages.length - 1 ? 'Start Shopping' : 'Next'),
            ),
          ),
        ]),
      ),
    );
  }
}
