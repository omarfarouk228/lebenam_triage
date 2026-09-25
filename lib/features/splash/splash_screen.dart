import 'package:flutter/material.dart';

import '../../core/brand/lebenam_logo.dart';
import '../home/home_screen.dart';

/// Animated splash: the Lébénam logo draws itself, then fades to home.
///
/// The native launch screen is a plain background of the same colour, so the
/// hand-off to this screen is seamless.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().then((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, _, _) => const HomeScreen(),
          transitionsBuilder: (_, animation, _, child) => FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tagline = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 1, curve: Curves.easeOut),
    );

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LebenamLogo(width: 176, progress: _controller),
            const SizedBox(height: 28),
            FadeTransition(
              opacity: tagline,
              child: Text(
                'TRIAGE',
                style: textTheme.labelMedium?.copyWith(
                  letterSpacing: 6,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
