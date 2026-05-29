import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flags_around_the_world/core/constants.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D47A1), // deep blue
              Color(0xFF1565C0),
              Color(0xFF1976D2),
              Color(0xFF42A5F5), // sky blue
            ],
            stops: [0.0, 0.3, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Globe + floating flags
              _GlobeHero(rotationController: _rotationController),

              const SizedBox(height: 32),

              // Title
              const Text(
                'Flags Around\nthe World',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Place every flag on the map.\nLearn every country.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1.5,
                ),
              ),

              const Spacer(flex: 3),

              // Start button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => context.go('/'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1565C0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 4,
                    ),
                    child: const Text(
                      'START ADVENTURE',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Privacy footer
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () async {
                        final uri = Uri.parse(AppConstants.privacyPolicyUrl);
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      },
                      child: Text(
                        'Privacy Policy',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      '·',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '© 2025 Otis & Brooke',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlobeHero extends StatelessWidget {
  final AnimationController rotationController;

  const _GlobeHero({required this.rotationController});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.2),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
          ),
          // Globe background circle
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.3),
                colors: [
                  Colors.blue.shade300,
                  const Color(0xFF1565C0),
                  const Color(0xFF0D2E6B),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(4, 8),
                ),
              ],
            ),
          ),
          // Rotating globe icon
          AnimatedBuilder(
            animation: rotationController,
            builder: (_, __) => Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(rotationController.value * 2 * math.pi),
              child: const Icon(
                Icons.public,
                size: 100,
                color: Colors.white,
              ),
            ),
          ),
          // Orbiting flag dots
          ..._buildOrbitingDots(),
        ],
      ),
    );
  }

  List<Widget> _buildOrbitingDots() {
    final colors = [
      Colors.red,
      Colors.yellow,
      Colors.green,
      Colors.white,
      Colors.orange,
      Colors.cyan,
    ];
    return List.generate(6, (i) {
      final baseAngle = (i / 6) * 2 * math.pi;
      const radius = 90.0;
      return AnimatedBuilder(
        animation: rotationController,
        builder: (_, __) {
          final angle = baseAngle + rotationController.value * 2 * math.pi;
          final x = 100 + radius * math.cos(angle) - 6;
          final y = 100 + radius * math.sin(angle) - 6;
          return Positioned(
            left: x,
            top: y,
            child: Container(
              width: 12,
              height: 8,
              decoration: BoxDecoration(
                color: colors[i],
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: colors[i].withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }
}
