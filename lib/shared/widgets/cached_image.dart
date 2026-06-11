import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/app_colors.dart';

/// Single disk cache shared by every [CachedImage] in the app.
///
/// Entries go stale after 7 days and the cache holds at most 200 objects,
/// so disk usage stays bounded no matter how many trips a user browses.
/// (flutter_cache_manager's DefaultCacheManager is not configurable at
/// runtime — the supported pattern is a custom-keyed manager like this one,
/// passed to CachedNetworkImage.)
class AppImageCacheManager {
  AppImageCacheManager._();

  static const _key = 'gowaiImageCache';

  static final CacheManager instance = CacheManager(
    Config(
      _key,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 200,
    ),
  );
}

/// App-standard network image: shimmer while loading, graceful fallback on
/// error or missing URL, and memory-bounded decoding via [memCacheWidth] /
/// [memCacheHeight] so thumbnails never hold full-resolution bitmaps.
///
/// Use this everywhere a remote image is shown — cards, lists, avatars,
/// destination thumbnails — instead of Image.network / raw CachedNetworkImage.
class CachedImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius borderRadius;

  /// Decode target in physical pixels. Set to roughly the displayed size
  /// times the device pixel ratio; leave null only for full-screen images.
  final int? memCacheWidth;
  final int? memCacheHeight;

  /// Shown when [url] is null/empty or fails to load. Defaults to a muted
  /// image-off icon on a tinted background.
  final Widget? errorWidget;

  const CachedImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
    this.memCacheWidth,
    this.memCacheHeight,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = errorWidget ?? _DefaultFallback(width: width, height: height);

    final child = (url == null || url!.isEmpty)
        ? fallback
        : CachedNetworkImage(
            imageUrl: url!,
            cacheManager: AppImageCacheManager.instance,
            width: width,
            height: height,
            fit: fit,
            memCacheWidth: memCacheWidth,
            memCacheHeight: memCacheHeight,
            placeholder: (_, __) =>
                _ShimmerPlaceholder(width: width, height: height),
            errorWidget: (_, __, ___) => fallback,
          );

    if (borderRadius == BorderRadius.zero) return child;
    return ClipRRect(borderRadius: borderRadius, child: child);
  }
}

class _ShimmerPlaceholder extends StatelessWidget {
  final double? width;
  final double? height;
  const _ShimmerPlaceholder({this.width, this.height});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.border,
      highlightColor: AppColors.background,
      child: Container(
        width: width ?? double.infinity,
        height: height ?? double.infinity,
        color: AppColors.border,
      ),
    );
  }
}

class _DefaultFallback extends StatelessWidget {
  final double? width;
  final double? height;
  const _DefaultFallback({this.width, this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      color: AppColors.primary.withAlpha(20),
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 32,
          color: AppColors.primary.withAlpha(100),
        ),
      ),
    );
  }
}
