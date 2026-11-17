import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/store_provider.dart';
import '../theme/app_theme.dart';
import 'main_shell.dart';
import 'onboarding_screen.dart';

/// Animated splash: truck drives in, veggies drop & bounce, brand letters pop in.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _main = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..forward();
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  static const _veggies = ['🥕', '🍅', '🥦', '🍎', '🍌', '🥭', '🍇', '🌽', '🍆', '🥬', '🍋', '🍉'];
  final _rnd = Random(7);
  late final List<_Drop> _drops = List.generate(14, (i) => _Drop(_veggies[i % _veggies.length], _rnd.nextDouble(), .05 + _rnd.nextDouble() * .35, 22 + _rnd.nextDouble() * 16));

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final auth = context.read<AuthProvider>();
    final store = context.read<StoreProvider>();
    final cart = context.read<CartProvider>();
    final results = await Future.wait([
      Future.delayed(const Duration(milliseconds: 3400)),
      auth.init().then((_) => Future.wait([cart.load(), store.loadWishlist()])),
      store.loadHome(),
      SharedPreferences.getInstance(),
    ]);
    if (!mounted) return;
    final sp = results[3] as SharedPreferences;
    final seen = sp.getBool('onboarding_seen') ?? false;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (_, __, ___) => seen ? const MainShell() : const OnboardingScreen(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  void dispose() {
    _main.dispose();
    _loop.dispose();
    super.dispose();
  }

  Animation<double> _iv(double a, double b, [Curve c = Curves.easeOut]) => CurvedAnimation(parent: _main, curve: Interval(a, b, curve: c));

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final truckW = min(size.width * .82, 360.0);
    final truckIn = _iv(0.0, 0.45, Curves.easeOutBack);
    final ring = _iv(0.0, 0.6, Curves.easeOutCubic);
    final tagline = _iv(0.72, 0.95);

    return Scaffold(
      backgroundColor: AppColors.splashBg,
      body: AnimatedBuilder(
        animation: Listenable.merge([_main, _loop]),
        builder: (context, _) {
          final bob = sin(_loop.value * 2 * pi) * 2.5;
          return Stack(children: [
            // expanding soft green rings
            Center(
              child: Transform.scale(
                scale: .3 + ring.value * 1.4,
                child: Opacity(
                  opacity: (1 - ring.value) * .6 + .15,
                  child: Container(
                    width: size.width,
                    height: size.width,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [AppColors.soft, AppColors.soft.withOpacity(0)]),
                    ),
                  ),
                ),
              ),
            ),
            // falling veggies
            ..._drops.map((d) {
              final t = ((_main.value - d.delay) / .45).clamp(0.0, 1.0);
              final y = Curves.bounceOut.transform(t);
              final top = -60 + y * (size.height * (.12 + d.x * .1));
              return Positioned(
                left: d.x * (size.width - 40),
                top: top,
                child: Opacity(
                  opacity: t == 0 ? 0 : (1 - _iv(.85, 1).value * .5),
                  child: Transform.rotate(angle: (1 - y) * 2 + d.x, child: Text(d.emoji, style: TextStyle(fontSize: d.size))),
                ),
              );
            }),
            Align(
              alignment: const Alignment(0, -.1),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // truck driving in
                Transform.translate(
                  offset: Offset((1 - truckIn.value) * -size.width, bob * (_main.value > .45 ? 1 : 0)),
                  child: Stack(clipBehavior: Clip.none, children: [
                    Image.asset('assets/images/truck.png', width: truckW),
                    // exhaust puffs
                    for (var i = 0; i < 3; i++)
                      Positioned(
                        right: -10 - ((_loop.value + i / 3) % 1) * 40,
                        bottom: 18 + ((_loop.value + i / 3) % 1) * 12,
                        child: Opacity(
                          opacity: (1 - ((_loop.value + i / 3) % 1)) * .7 * truckIn.value.clamp(0, 1),
                          child: Container(
                            width: 10 + ((_loop.value + i / 3) % 1) * 16,
                            height: 10 + ((_loop.value + i / 3) % 1) * 16,
                            decoration: const BoxDecoration(color: Color(0xFFDADADA), shape: BoxShape.circle),
                          ),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 14),
                // brand letters
                Row(mainAxisSize: MainAxisSize.min, children: [
                  ..._letters('MANDI', AppColors.accent, 0.42),
                  const SizedBox(width: 12),
                  ..._letters('AT HOME', const Color(0xFF222222), 0.52),
                ]),
                const SizedBox(height: 10),
                FadeTransition(
                  opacity: tagline,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, .6), end: Offset.zero).animate(tagline),
                    child: Text('Fresh from the mandi, straight to your home',
                        style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                  ),
                ),
              ]),
            ),
            // loader dots
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: tagline,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final v = sin((_loop.value * 2 * pi) - i * .8);
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 9,
                      height: 9,
                      transform: Matrix4.translationValues(0, v * -5, 0),
                      decoration: BoxDecoration(color: [AppColors.primary, AppColors.accent, AppColors.yellow][i], shape: BoxShape.circle),
                    );
                  }),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }

  List<Widget> _letters(String word, Color color, double start) {
    return List.generate(word.length, (i) {
      final a = _iv((start + i * .025).clamp(0, 1), (start + i * .025 + .18).clamp(0, 1), Curves.elasticOut);
      final o = _iv((start + i * .025).clamp(0, 1), (start + i * .025 + .06).clamp(0, 1));
      return Opacity(
        opacity: o.value,
        child: Transform.translate(
          offset: Offset(0, (1 - a.value) * 30),
          child: Transform.scale(
            scale: .4 + a.value * .6,
            child: Text(word[i], style: GoogleFonts.fredoka(fontSize: 34, fontWeight: FontWeight.w700, color: color, letterSpacing: 1.5)),
          ),
        ),
      );
    });
  }
}

class _Drop {
  final String emoji;
  final double x, delay, size;
  _Drop(this.emoji, this.x, this.delay, this.size);
}
