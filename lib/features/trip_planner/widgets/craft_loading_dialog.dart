import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';

/// Cinematic full-screen loading experience for AI itinerary synthesis.
class CraftLoadingDialog extends StatefulWidget {
  final String destination;

  const CraftLoadingDialog({
    super.key,
    required this.destination,
  });

  @override
  State<CraftLoadingDialog> createState() => _CraftLoadingDialogState();
}

class _CraftLoadingDialogState extends State<CraftLoadingDialog>
    with TickerProviderStateMixin {
  late AnimationController _spinController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  int _stepIndex = 0;
  Timer? _stepTimer;

  static const List<String> _stages = [
    'Scanning city hotspots & landmarks...',
    'Curating local culinary gems...',
    'Optimizing transit & schedule balance...',
    'Finalizing your personalized journey...',
  ];

  static const List<String> _travelTips = [
    'Tip: Mornings are best for visiting quiet temples and monuments.',
    'Tip: Local street food tours are recommended before 8 PM.',
    'Tip: Keep a buffer of 15 minutes between sights for unexpected discoveries.',
    'Tip: Stay hydrated and carry cash for heritage site ticket counters.',
  ];

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _stepTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (mounted) {
        setState(() {
          if (_stepIndex < _stages.length - 1) {
            _stepIndex++;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _spinController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cityName =
        widget.destination.isNotEmpty ? widget.destination : 'India';

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF09143C),
                Color(0xFF0F2361),
                Color(0xFF1A3685),
              ],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppTokens.xl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(),

                  // Cosmic Orbit Ring & Compass Center
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer Pulsing Glow
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: Container(
                                width: 130,
                                height: 130,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.accent.withValues(alpha: 0.2),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.accent.withValues(alpha: 0.15),
                                      blurRadius: 24,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        // Spinning Dashed Orbit
                        RotationTransition(
                          turns: _spinController,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Inner Center Compass Icon
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Icon(
                            Icons.explore_rounded,
                            size: 34,
                            color: AppColors.accentLight,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Headline
                  Text(
                    'Crafting Your $cityName Journey',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Animated Step Status
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _stages[_stepIndex],
                      key: ValueKey<int>(_stepIndex),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Animated Step Indicators (Dots + Progress line)
                  SizedBox(
                    width: 200,
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppTokens.radiusPill),
                          child: LinearProgressIndicator(
                            value: (_stepIndex + 1) / _stages.length,
                            minHeight: 5,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.accent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Step ${_stepIndex + 1} of ${_stages.length}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Bottom Travel Tip Card
                  Container(
                    margin: const EdgeInsets.only(top: AppTokens.md, bottom: AppTokens.lg),
                    padding: const EdgeInsets.all(AppTokens.md),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lightbulb_outline,
                          color: AppColors.accentLight,
                          size: 20,
                        ),
                        const SizedBox(width: AppTokens.sm),
                        Expanded(
                          child: Text(
                            _travelTips[_stepIndex % _travelTips.length],
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.3,
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
        ),
      ),
    ),
        ),
      ),
    );
  }
}
