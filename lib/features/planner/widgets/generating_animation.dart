import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

/// Full-screen "generating your trip" state shown while Claude AI is
/// crafting the itinerary. Cycles through playful status messages and an
/// animated dot progress indicator.
class GeneratingAnimation extends StatefulWidget {
  final String destination;

  const GeneratingAnimation({super.key, this.destination = ''});

  @override
  State<GeneratingAnimation> createState() => _GeneratingAnimationState();
}

class _GeneratingAnimationState extends State<GeneratingAnimation> {
  int _msgIndex = 0;
  int _dotIndex = 0;

  Timer? _msgTimer;
  Timer? _dotTimer;

  static const _messages = [
    'Reading your vibe... ✨',
    'Consulting the AI travel gods... 🤖',
    'Plotting the perfect route... 🗺️',
    'Finding hidden gems... 💎',
    'Almost ready for your adventure... 🚀',
  ];

  @override
  void initState() {
    super.initState();
    _msgTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        setState(() => _msgIndex = (_msgIndex + 1) % _messages.length);
      }
    });
    _dotTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (mounted) {
        setState(() => _dotIndex = (_dotIndex + 1) % 5);
      }
    });
  }

  @override
  void dispose() {
    _msgTimer?.cancel();
    _dotTimer?.cancel();
    super.dispose();
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: Text(
                  _messages[_msgIndex],
                  key: ValueKey(_msgIndex),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (widget.destination.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Crafting your perfect day in ${widget.destination}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.muted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final active = _dotIndex == i;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color:
                          active ? AppColors.primary : AppColors.primaryTrack,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}
