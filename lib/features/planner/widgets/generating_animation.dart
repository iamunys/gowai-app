import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../../../core/constants/app_colors.dart';

class GeneratingAnimation extends StatefulWidget {
  final Color color;

  const GeneratingAnimation({
    super.key,
    this.color = AppColors.primary,
  });

  @override
  State<GeneratingAnimation> createState() => _GeneratingAnimationState();
}

class _GeneratingAnimationState extends State<GeneratingAnimation> {
  int _msgIndex = 0;

  static const _messages = [
    'Gowai is crafting your perfect day...',
    'Finding the best spots for you...',
    'Mapping out your route...',
    'Adding local tips and secrets...',
    'Almost there! Finishing touches...',
  ];

  @override
  void initState() {
    super.initState();
    _cycleMessages();
  }

  void _cycleMessages() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _msgIndex = (_msgIndex + 1) % _messages.length);
        _cycleMessages();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Container(
        color: AppColors.background,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/lottie/loader.json',
                width: 150,
                height: 150,
                fit: BoxFit.contain,
                delegates: LottieDelegates(
                  values: [
                    ValueDelegate.color(const [
                      '**',
                      'Fill 1',
                      '**',
                    ], value: widget.color),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  _messages[_msgIndex],
                  key: ValueKey(_msgIndex),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 300.ms),
      ),
    );
  }
}
