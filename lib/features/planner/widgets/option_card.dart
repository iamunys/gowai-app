import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

/// Definition of a single answer option shown as a chip-card.
class PlannerOption {
  final String emoji;
  final String label;
  final String subtitle;

  const PlannerOption(this.emoji, this.label, this.subtitle);
}

/// A 2-column grid of [OptionCard]s with a staggered entrance animation.
class OptionGrid extends StatelessWidget {
  final List<PlannerOption> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  const OptionGrid({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.6,
      children: List.generate(options.length, (i) {
        final option = options[i];
        return OptionCard(
          option: option,
          selected: selected == option.label,
          onTap: () => onSelected(option.label),
        )
            .animate()
            .slideY(
              begin: 0.3,
              duration: 350.ms,
              delay: (i * 80).ms,
              curve: Curves.easeOut,
            )
            .fadeIn(duration: 300.ms, delay: (i * 80).ms);
      }),
    );
  }
}

/// A single answer "chip card" with emoji, label and subtitle.
///
/// Provides a satisfying tap animation (scale bounce + haptic feedback) and
/// animates its selected state (border/background/scale).
class OptionCard extends StatefulWidget {
  final PlannerOption option;
  final bool selected;
  final VoidCallback onTap;

  const OptionCard({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  State<OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<OptionCard> {
  double _scale = 1.0;

  void _handleTap() {
    HapticFeedback.lightImpact();
    setState(() => _scale = 0.95);
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _scale = 1.0);
    });
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final option = widget.option;

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedScale(
        scale: selected ? (_scale * 1.02) : _scale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? AppColors.primary.withAlpha(40)
                    : Colors.black.withAlpha(10),
                blurRadius: selected ? 12 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Text(option.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.placeholder,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
