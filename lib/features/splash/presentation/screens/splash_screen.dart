import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/routing/routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _iconAnimationController;
  late AnimationController _bgAnimationController;
  late Animation<double> _iconScale;
  late Animation<double> _iconOpacity;

  double _loadingProgress = 0.0;
  String _diagnosticLog = 'LOADING OFFLINE ENGINE...';
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();

    // 1. Icon Pulsing & Spring Scale Animation
    _iconAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _iconScale = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconAnimationController,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );

    _iconOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconAnimationController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _iconAnimationController.forward();

    // Background continuous animation ticker
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(() {
        setState(() {});
      });
    _bgAnimationController.repeat();

    // 2. Crawling Retro Progress Bar Animation
    _startProgressAnimation();
  }

  void _startProgressAnimation() {
    const duration = Duration(milliseconds: 60);
    _progressTimer = Timer.periodic(duration, (timer) {
      if (!mounted) return;

      setState(() {
        _loadingProgress += 0.025;

        // Dynamic cyber diagnostics logging
        if (_loadingProgress >= 1.0) {
          _loadingProgress = 1.0;
          _diagnosticLog = 'ULTRAMP3 ENGINE READY!';
          _progressTimer?.cancel();

          // Wait a brief moment for user to feel the readiness, then route!
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) {
              context.go(AppRoutes.home);
            }
          });
        } else if (_loadingProgress > 0.8) {
          _diagnosticLog = 'INDEXING COMPLETED: ENGINE ONLINE';
        } else if (_loadingProgress > 0.55) {
          _diagnosticLog = 'CATALOGING SYSTEM DIRECTORIES...';
        } else if (_loadingProgress > 0.3) {
          _diagnosticLog = 'SYNAPSE SHADERS INITIALIZED';
        } else if (_loadingProgress > 0.1) {
          _diagnosticLog = 'CONNECTING HIVE LOCAL CACHE...';
        }
      });
    });
  }

  @override
  void dispose() {
    _iconAnimationController.dispose();
    _bgAnimationController.dispose();
    _progressTimer?.cancel();
    super.dispose();
  }

  Widget _buildLogoStack() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.neonGreen.withOpacity(0.18),
                blurRadius: 40,
                spreadRadius: 8,
              ),
            ],
          ),
        ),

        // Spring scaling App Icon
        AnimatedBuilder(
          animation: _iconAnimationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _iconScale.value,
              child: Opacity(
                opacity: _iconOpacity.value,
                child: child,
              ),
            );
          },
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Image.asset(
                'assets/icons/app_icon.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitles() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'ULTRAMP3',
          style: GoogleFonts.orbitron(
            color: AppColors.neonGreen,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 4.0,
            shadows: [
              Shadow(
                color: AppColors.neonGreen.withOpacity(0.4),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        Text(
          'REBORN',
          style: GoogleFonts.rajdhani(
            color: AppColors.electricCyan,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 6.0,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBarContainer() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.obsidianDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.glassBorder,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'INDEXING STORAGE',
                style: GoogleFonts.orbitron(
                  color: AppColors.neonGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 9.5,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                '${(_loadingProgress * 100).toInt()}%',
                style: GoogleFonts.orbitron(
                  color: AppColors.neonGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Neon Digital S60 LED bar
          Container(
            height: 12,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: AppColors.neonGreen.withOpacity(0.2),
                width: 0.8,
              ),
            ),
            padding: const EdgeInsets.all(1.5),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: _loadingProgress,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.neonGreen,
                    borderRadius: BorderRadius.circular(1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neonGreen.withOpacity(0.6),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Diagnostics terminal print log
          Container(
            height: 28,
            alignment: Alignment.center,
            child: Text(
              _diagnosticLog,
              style: GoogleFonts.shareTechMono(
                color: AppColors.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppColors.voidBlack,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              Color(0xFF141224),
              AppColors.voidBlack,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Animated background CustomPaint
            Positioned.fill(
              child: CustomPaint(
                painter: _SplashBackgroundPainter(
                  progress: _loadingProgress,
                  animationTime: _bgAnimationController.value * 2 * math.pi,
                ),
              ),
            ),

            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: isLandscape ? 16.0 : 32.0,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: isLandscape
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Scale down logo slightly in landscape
                                Transform.scale(
                                  scale: 0.75,
                                  child: _buildLogoStack(),
                                ),
                                const SizedBox(height: 8),
                                _buildTitles(),
                              ],
                            ),
                            _buildProgressBarContainer(),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Spacer(flex: 3),
                            _buildLogoStack(),
                            const SizedBox(height: 24),
                            _buildTitles(),
                            const Spacer(flex: 2),
                            _buildProgressBarContainer(),
                            const Spacer(flex: 1),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashBackgroundPainter extends CustomPainter {
  final double progress;
  final double animationTime;

  _SplashBackgroundPainter(
      {required this.progress, required this.animationTime});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Draw galaxy particles
    final math.Random random =
        math.Random(42); // deterministic seed for stable particles
    final Paint particlePaint = Paint()..style = PaintingStyle.fill;

    // Scale speed and particle count based on progress
    final double speedFactor = 1.0 + progress * 4.0;

    for (int i = 0; i < 40; i++) {
      // Base positions
      final double baseAngle = random.nextDouble() * 2 * math.pi;
      final double baseRadius = 30 + random.nextDouble() * math.max(w, h) * 0.6;

      // Animate radius outwards
      final double driftRadius =
          (baseRadius + (animationTime * 12.0 * speedFactor)) %
              (math.max(w, h) * 0.7);

      // Calculate coordinates centered in the screen
      final double dx = w / 2 + math.cos(baseAngle) * driftRadius;
      final double dy = h / 2 + math.sin(baseAngle) * driftRadius;

      // Draw particle with opacity fading near edges
      final double edgeOpacity =
          (1.0 - (driftRadius / (math.max(w, h) * 0.7))).clamp(0.0, 1.0);
      final double particleSize = 1.0 + random.nextDouble() * 2.5;

      // Green/cyan glow
      final Color pColor =
          i % 2 == 0 ? AppColors.neonGreen : AppColors.electricCyan;
      particlePaint.color = pColor.withOpacity(0.18 * edgeOpacity);

      canvas.drawCircle(Offset(dx, dy), particleSize, particlePaint);
    }

    // Draw active oscilloscope waves
    final Paint wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final double midY = h / 2;
    final int samplePoints = 50;

    // Draw 3 layers of glowing retro oscilloscope waves
    for (int layer = 0; layer < 3; layer++) {
      final wavePath = Path();
      wavePath.moveTo(0, midY);

      final double amplitude = (15.0 + layer * 8.0) * (0.3 + progress * 0.7);
      final double frequency = 0.015 + layer * 0.01;
      final double phaseShift = phaseShiftValue(layer);

      for (int x = 0; x <= samplePoints; x++) {
        final double pct = x / samplePoints;
        final double dx = pct * w;
        final double dy = midY +
            math.sin(pct * w * frequency - phaseShift) *
                amplitude *
                math.sin(pct * math.pi);
        wavePath.lineTo(dx, dy);
      }

      // Color from neon green to electric cyan with low opacity for background aura
      final Color waveColor =
          layer % 2 == 0 ? AppColors.neonGreen : AppColors.electricCyan;
      wavePaint.color = waveColor.withOpacity(0.12 - (layer * 0.03));

      canvas.drawPath(wavePath, wavePaint);
    }
  }

  double phaseShiftValue(int layer) {
    return animationTime * (2.5 + layer * 1.5);
  }

  @override
  bool shouldRepaint(covariant _SplashBackgroundPainter oldDelegate) {
    return oldDelegate.animationTime != animationTime ||
        oldDelegate.progress != progress;
  }
}
