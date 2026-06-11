import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

/// Small purple "G" avatar representing Gowai in the chat flow.
class GowaiAvatar extends StatelessWidget {
  final bool pulsing;

  const GowaiAvatar({super.key, this.pulsing = false});

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: Text(
        'G',
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );

    if (!pulsing) return avatar;

    return avatar
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.08, 1.08),
          duration: 800.ms,
          curve: Curves.easeInOut,
        );
  }
}

/// Left-aligned bubble representing a question asked by Gowai.
///
/// When [animateText] is true, the question types out letter-by-letter and
/// [onTypingComplete] fires once the animation finishes. When false, the
/// full question text is shown immediately (used for chat history).
class BotQuestionBubble extends StatelessWidget {
  final String question;
  final bool animateText;
  final VoidCallback? onTypingComplete;
  final double opacity;

  const BotQuestionBubble({
    super.key,
    required this.question,
    this.animateText = false,
    this.onTypingComplete,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = GoogleFonts.poppins(
      fontSize: 14,
      color: AppColors.ink,
    );

    return Opacity(
      opacity: opacity,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GowaiAvatar(pulsing: animateText),
            const SizedBox(width: 8),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: animateText
                      ? AnimatedTextKit(
                          isRepeatingAnimation: false,
                          totalRepeatCount: 1,
                          onFinished: onTypingComplete,
                          animatedTexts: [
                            TyperAnimatedText(
                              question,
                              textStyle: textStyle,
                              speed: const Duration(milliseconds: 30),
                            ),
                          ],
                        )
                      : Text(question, style: textStyle),
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .slideX(begin: -0.15, duration: 500.ms, curve: Curves.easeOutBack)
        .fadeIn(duration: 400.ms);
  }
}

/// Right-aligned bubble representing the user's answer to a question.
///
/// Tapping the bubble allows the user to go back and edit that answer.
class UserAnswerBubble extends StatelessWidget {
  final String answer;
  final VoidCallback? onTap;
  final double opacity;

  const UserAnswerBubble({
    super.key,
    required this.answer,
    this.onTap,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(4),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          answer,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.check_rounded,
                          size: 16, color: Colors.white)
                          .animate()
                          .scale(
                            begin: const Offset(0, 0),
                            end: const Offset(1, 1),
                            duration: 250.ms,
                            curve: Curves.elasticOut,
                          ),
                    ],
                  ),
                ),
              ),
            ),
            if (onTap != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 4),
                child: Text(
                  'Tap to change',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: AppColors.placeholder,
                  ),
                ),
              ),
          ],
        ),
      ),
    )
        .animate()
        .slideX(begin: 0.15, duration: 400.ms, curve: Curves.easeOut)
        .fadeIn(duration: 350.ms);
  }
}
