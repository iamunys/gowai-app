import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

const _popularDestinations = [
  'Coorg',
  'Ooty',
  'Munnar',
  'Hampi',
  'Pondicherry',
  'Gokarna',
  'Wayanad',
];

/// Special text-input answer area shown for the destination question (Q1),
/// with a row of popular-destination suggestion chips below it.
class DestinationInput extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  const DestinationInput({
    super.key,
    required this.controller,
    required this.onSubmitted,
  });

  void _submit() {
    final value = controller.text.trim();
    if (value.isNotEmpty) onSubmitted(value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withAlpha(30),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 16),
                child: Icon(Icons.location_on_rounded,
                    color: AppColors.primary),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'e.g. Coorg, Ooty, Munnar...',
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    hintStyle: GoogleFonts.poppins(
                      color: AppColors.placeholder,
                    ),
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: AppColors.ink,
                  ),
                  textCapitalization: TextCapitalization.words,
                  onSubmitted: (_) => _submit(),
                ),
              ),
              GestureDetector(
                onTap: _submit,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _popularDestinations.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final place = _popularDestinations[i];
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  controller.text = place;
                  onSubmitted(place);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('📍', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 4),
                      Text(
                        place,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
