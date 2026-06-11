import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';

/// Titled prose card used by the policy screens (privacy, terms).
/// Was previously duplicated as a private `_Section` in both files.
class LegalSection extends StatelessWidget {
  final String title;
  final String body;

  const LegalSection({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: textTheme.titleMedium),
            const SizedBox(height: 10),
            Text(body, style: textTheme.bodyMedium?.copyWith(height: 1.7)),
          ],
        ),
      ),
    );
  }
}

/// "Last updated: <date>" pill shown at the top of policy screens.
class LastUpdatedBadge extends StatelessWidget {
  final String date;

  const LastUpdatedBadge(this.date, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        'Last updated: $date',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}
