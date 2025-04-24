import 'dart:typed_data'; // Needed for video thumbnail data

import 'package:flutter/material.dart';
import 'package:galleryimage/app_cached_network_image.dart';
import 'package:video_thumbnail/video_thumbnail.dart'; // Import video_thumbnail

import 'gallery_item_model.dart';

// to show image or video thumbnail in grid
class GalleryItemThumbnail extends StatelessWidget {
  final GalleryItemModel galleryItem;
  final GestureTapCallback? onTap;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final double radius;
  // Add cache parameter
  final Map<String, Uint8List> thumbnailCache;

  const GalleryItemThumbnail(
      {super.key,
      required this.galleryItem,
      this.onTap, // Make onTap nullable as it might be handled by parent
      required this.radius,
      required this.thumbnailCache, // Require the cache
      this.loadingWidget, // Make loading/error widgets nullable
      this.errorWidget});

  // Widget to display video thumbnail
  Widget _buildVideoThumbnail(BuildContext context) {
    // Check cache first
    if (thumbnailCache.containsKey(galleryItem.url)) {
      return _buildThumbnailFromData(thumbnailCache[galleryItem.url]!);
    }

    return FutureBuilder<Uint8List?>(
      future: VideoThumbnail.thumbnailData(
        video: galleryItem.url,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 128, // Adjust quality/size as needed
        quality: 25,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loadingWidget ??
              const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          // Return error widget or a placeholder for video error
          return errorWidget ??
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(radius),
                ),
                child: const Center(
                    child: Icon(Icons.error_outline, color: Colors.red)),
              );
        }
        // Cache the result before returning the widget
        if (snapshot.data != null) {
          thumbnailCache[galleryItem.url] = snapshot.data!;
        }
        // Display the thumbnail and overlay a play icon
        return _buildThumbnailFromData(snapshot.data!);
      },
    );
  }

  // Helper widget to build the thumbnail display from data (used by cache and future)
  Widget _buildThumbnailFromData(Uint8List thumbnailData) {
    return ClipRRect(
      // Apply radius to the Stack itself or the outer container
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          Image.memory(
            thumbnailData, // Use the provided data
            fit: BoxFit.cover,
          ),
          // Play icon overlay
          Container(
            decoration: BoxDecoration(
              // Ensure overlay respects radius
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(
                  radius), // Apply radius here too if needed
            ),
            child: const Center(
              // Center the icon
              child: Icon(
                Icons.play_circle_outline,
                color: Colors.white,
                size: 30, // Adjust size as needed
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget to display image thumbnail
  Widget _buildImageThumbnail(BuildContext context) {
    return AppCachedNetworkImage(
      fit: BoxFit.cover,
      imageUrl: galleryItem.url, // Use the generic url field
      loadingWidget: loadingWidget,
      errorWidget: errorWidget,
      radius: radius, // Apply radius directly
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use ClipRRect to ensure the radius is applied consistently
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: GestureDetector(
        onTap: onTap,
        child: Hero(
          // Ensure the tag is prefixed differently than the main view
          tag: "thumbnail_${galleryItem.id}",
          child: galleryItem.isVideo
              ? _buildVideoThumbnail(context)
              : _buildImageThumbnail(context),
        ),
      ),
    );
  }
}
