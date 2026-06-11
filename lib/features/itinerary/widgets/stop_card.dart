import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/trip_stop.dart';
import '../../../shared/widgets/cached_image.dart';

/// Maps a stop's category to a representative icon. Shared with
/// [stop_details_sheet.dart].
IconData categoryIcon(String category) {
  switch (category) {
    case 'viewpoint':
      return Icons.landscape;
    case 'waterfall':
      return Icons.water;
    case 'trekking':
      return Icons.hiking;
    case 'food':
      return Icons.restaurant;
    case 'culture':
      return Icons.museum;
    case 'estate':
      return Icons.nature;
    case 'beach':
      return Icons.beach_access;
    case 'market':
      return Icons.storefront;
    case 'temple':
      return Icons.temple_hindu;
    default:
      return Icons.place;
  }
}

class StopCard extends StatelessWidget {
  final TripStop stop;
  final bool isSelected;
  final VoidCallback onTap;

  /// When provided, shows a map icon button in the top-right corner of the
  /// card that calls this instead of [onTap] — used to open the full map
  /// view for this stop.
  final VoidCallback? onMapTap;

  const StopCard({
    super.key,
    required this.stop,
    required this.isSelected,
    required this.onTap,
    this.onMapTap,
  });

  IconData get _categoryIcon => categoryIcon(stop.category);

  Future<void> _openInMaps() async {
    final query = stop.address ??
        (stop.latLng != null
            ? '${stop.latLng!.latitude},${stop.latLng!.longitude}'
            : stop.name);
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 260,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.primary.withAlpha(50)
                  : AppColors.cardShadow,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image fills the leftover vertical space so the card never
            // overflows regardless of the list's available height.
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(14)),
                    child: CachedImage(
                      url: stop.photoUrl,
                      width: double.infinity,
                      height: double.infinity,
                      memCacheWidth: 520,
                      errorWidget: _PlaceholderImage(category: stop.category),
                    ),
                  ),
                  if (onMapTap != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: onMapTap,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.surface.withAlpha(220),
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.cardShadow,
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.map_outlined,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _StopBadge(number: stop.stopNumber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          stop.name,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(_categoryIcon, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        stop.time,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${stop.durationMinutes}min',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (stop.entryFeeInr > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '₹${stop.entryFeeInr}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stop.tip,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _openInMaps,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.map_outlined,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Open in Maps',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StopBadge extends StatelessWidget {
  final int number;
  const _StopBadge({required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$number',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _PlaceholderImage extends StatelessWidget {
  final String category;
  const _PlaceholderImage({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.primary.withAlpha(20),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 40,
          color: AppColors.primary.withAlpha(100),
        ),
      ),
    );
  }
}
