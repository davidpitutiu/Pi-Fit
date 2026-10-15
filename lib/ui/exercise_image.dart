import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../domain/models.dart';

/// Local imagery is available offline. The complete external catalog loads its
/// remaining photographs on demand and caches them on Android and iOS.
class ExerciseImage extends StatelessWidget {
  const ExerciseImage({
    super.key,
    required this.exercise,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.imageIndex = 0,
  });

  final Exercise exercise;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final int imageIndex;

  @override
  Widget build(BuildContext context) {
    final second = imageIndex == 1;
    final asset = second && exercise.secondaryImageAsset.isNotEmpty
        ? exercise.secondaryImageAsset
        : exercise.imageAsset;
    final url = second && exercise.secondaryImageUrl.isNotEmpty
        ? exercise.secondaryImageUrl
        : exercise.imageUrl;
    final available = asset.isNotEmpty || url.isNotEmpty;
    final targetWidth = width == null || !width!.isFinite
        ? 1080
        : (width! * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(
            80,
            1080,
          );
    Widget picture;
    if (asset.isNotEmpty) {
      picture = Image.asset(
        asset,
        fit: fit,
        cacheWidth: targetWidth,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => const _ExerciseImagePlaceholder(),
      );
    } else if (url.isNotEmpty) {
      picture = CachedNetworkImage(
        imageUrl: url,
        cacheKey: url,
        fit: fit,
        memCacheWidth: targetWidth,
        maxWidthDiskCache: 1200,
        fadeInDuration: const Duration(milliseconds: 160),
        placeholder: (_, _) => const _ExerciseImagePlaceholder(
          icon: Icons.cloud_download_outlined,
          message: 'Se încarcă imaginea',
        ),
        errorWidget: (_, _, _) => const _ExerciseImagePlaceholder(
          icon: Icons.cloud_off_rounded,
          message: 'Imagine indisponibilă',
          detail: 'Verifică accesul la internet.',
        ),
      );
    } else {
      picture = const _ExerciseImagePlaceholder();
    }
    return Semantics(
      image: true,
      excludeSemantics: true,
      label: available
          ? '${exercise.name}. Poziția ${imageIndex + 1}.'
          : '${exercise.name}. Imagine indisponibilă.',
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(20),
        child: SizedBox(
          width: width,
          height: height,
          child: ColoredBox(color: const Color(0xFF101719), child: picture),
        ),
      ),
    );
  }
}

/// An explicitly neutral placeholder, rather than a guessed exercise pose.
class _ExerciseImagePlaceholder extends StatelessWidget {
  const _ExerciseImagePlaceholder({
    this.icon = Icons.image_outlined,
    this.message = 'Fotografie indisponibilă',
    this.detail,
  });

  final IconData icon;
  final String message;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xFF84928C) : const Color(0xFF748279);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF202C29), Color(0xFF17201E)]
              : const [Color(0xFFEDF2EF), Color(0xFFDFE7E2)],
        ),
      ),
      child: LayoutBuilder(
        builder: (_, constraints) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ink.withValues(alpha: .25)),
                ),
                child: Icon(icon, color: ink, size: 24),
              ),
              if (constraints.maxWidth > 140) ...[
                const SizedBox(height: 10),
                Text(message, style: TextStyle(fontSize: 11, color: ink)),
                if (detail != null && constraints.maxHeight > 120) ...[
                  const SizedBox(height: 5),
                  Text(detail!, style: TextStyle(fontSize: 10, color: ink)),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
