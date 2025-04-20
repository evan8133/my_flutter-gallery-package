library galleryimage;

import 'dart:typed_data'; // Import for cache type

import 'package:flutter/material.dart';
import 'package:path/path.dart'
    as p; // Import path package for extension checking

import './gallery_image_view_wrapper.dart';
import './util.dart';
import 'gallery_item_model.dart';
import 'gallery_item_thumbnail.dart';

class GalleryImage extends StatefulWidget {
  // Renamed imageUrls to urls to reflect support for multiple media types
  final List<String> urls;
  final String? titleGallery;
  final int numOfShowImages;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;
  final EdgeInsetsGeometry padding;
  final Color? colorOfNumberWidget;
  final Color galleryBackgroundColor;
  final TextStyle? textStyleOfNumberWidget;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final double minScale;
  final double maxScale;
  final double imageRadius;
  final bool reverse;
  final bool showListInGalley;
  final bool showAppBar;
  final bool closeWhenSwipeUp;
  final bool closeWhenSwipeDown;
  final Color closeIconColor;
  final Color closeIconBackgroundColor;

  const GalleryImage({
    Key? key,
    required this.urls, // Updated parameter name
    this.titleGallery,
    this.childAspectRatio = 1,
    this.crossAxisCount = 3,
    this.mainAxisSpacing = 5,
    this.crossAxisSpacing = 5,
    this.numOfShowImages = 3,
    this.colorOfNumberWidget,
    this.textStyleOfNumberWidget,
    this.padding = EdgeInsets.zero,
    this.loadingWidget,
    this.errorWidget,
    this.galleryBackgroundColor = Colors.black,
    this.minScale = .5,
    this.maxScale = 10,
    this.imageRadius = 8,
    this.reverse = false,
    this.showListInGalley = true,
    this.showAppBar = true,
    this.closeWhenSwipeUp = false,
    this.closeWhenSwipeDown = false,
    this.closeIconColor = Colors.white,
    this.closeIconBackgroundColor = Colors.black,
  })  : assert(numOfShowImages <= urls.length), // Updated assertion
        super(key: key);
  @override
  State<GalleryImage> createState() => _GalleryImageState();
}

class _GalleryImageState extends State<GalleryImage> {
  List<GalleryItemModel> galleryItems = <GalleryItemModel>[];
  // Add a cache for video thumbnails
  final Map<String, Uint8List> _thumbnailCache = {};

  @override
  void initState() {
    _buildItemsList(widget.urls); // Updated to use widget.urls
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return galleryItems.isEmpty
        ? const EmptyWidget()
        : GridView.builder(
            primary: false,
            itemCount: galleryItems.length > 3
                ? widget.numOfShowImages
                : galleryItems.length,
            padding: widget.padding,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              childAspectRatio: widget.childAspectRatio,
              crossAxisCount: widget.crossAxisCount,
              mainAxisSpacing: widget.mainAxisSpacing,
              crossAxisSpacing: widget.crossAxisSpacing,
            ),
            shrinkWrap: true,
            itemBuilder: (BuildContext context, int index) {
              // Pass the correct gallery item (which now includes isVideo flag)
              // Also pass the thumbnail cache
              return _isLastItem(index)
                  ? _buildImageNumbers(index)
                  : GalleryItemThumbnail(
                      galleryItem: galleryItems[index], // Pass the model
                      thumbnailCache: _thumbnailCache, // Pass the cache
                      onTap: () {
                        _openImageFullScreen(index);
                      },
                      loadingWidget: widget.loadingWidget,
                      errorWidget: widget.errorWidget,
                      radius: widget.imageRadius,
                    );
            });
  }

// build image with number for other images
  Widget _buildImageNumbers(int index) {
    return GestureDetector(
      onTap: () {
        _openImageFullScreen(index);
      },
      child: Stack(
        alignment: AlignmentDirectional.center,
        fit: StackFit.expand,
        children: <Widget>[
          // Use the updated GalleryItemThumbnail which will handle video/image
          // Pass the thumbnail cache
          GalleryItemThumbnail(
            galleryItem: galleryItems[index], // Pass the model
            thumbnailCache: _thumbnailCache, // Pass the cache
            loadingWidget: widget.loadingWidget,
            errorWidget: widget.errorWidget,
            onTap: null, // onTap is handled by the GestureDetector above
            radius: widget.imageRadius,
          ),
          ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(widget.imageRadius)),
            child: ColoredBox(
              // Fixed deprecated withOpacity
              color: widget.colorOfNumberWidget ??
                  Colors.black.withAlpha((255 * 0.7).round()),
              child: Center(
                child: Text(
                  // Display remaining count correctly
                  "+${galleryItems.length - widget.numOfShowImages + 1}",
                  style: widget.textStyleOfNumberWidget ??
                      const TextStyle(color: Colors.white, fontSize: 40),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

// Check if item is last image in grid to view image or number
  bool _isLastItem(int index) {
    // Show the number overlay only on the last visible thumbnail
    // when there are more items than shown.
    return galleryItems.length > widget.numOfShowImages &&
        index == widget.numOfShowImages - 1;
  }

// to open gallery image/video in full screen
  Future<void> _openImageFullScreen(int indexOfItem) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        // GalleryImageViewWrapper will need updates to handle video
        builder: (context) => GalleryImageViewWrapper(
          titleGallery: widget.titleGallery,
          galleryItems: galleryItems, // Pass the updated list
          backgroundColor: widget.galleryBackgroundColor,
          initialIndex: indexOfItem,
          loadingWidget: widget.loadingWidget,
          errorWidget: widget.errorWidget,
          maxScale: widget.maxScale,
          minScale: widget.minScale,
          reverse: widget.reverse,
          showListInGalley: widget.showListInGalley,
          showAppBar: widget.showAppBar,
          closeWhenSwipeUp: widget.closeWhenSwipeUp,
          closeWhenSwipeDown: widget.closeWhenSwipeDown,
          radius: widget.imageRadius,
          closeIconColor: widget.closeIconColor,
          closeIconBackgroundColor: widget.closeIconBackgroundColor,
          thumbnailCache: _thumbnailCache, // Pass the cache
        ),
      ),
    );
  }

  // List of common video file extensions
  final _videoExtensions = {
    '.mp4',
    '.mov',
    '.avi',
    '.mkv',
    '.wmv',
    '.flv',
    '.webm'
  };

  // Checks if the url string likely points to a video file
  bool _isVideoUrl(String url) {
    try {
      // Use Uri.parse to handle potential query parameters or fragments
      final uri = Uri.parse(url);
      // Get the extension from the path component of the URI
      final extension = p.extension(uri.path).toLowerCase();
      return _videoExtensions.contains(extension);
    } catch (e) {
      // Handle potential parsing errors if the URL is malformed
      print("Error parsing URL $url: $e");
      return false;
    }
  }

// clear and build list
  void _buildItemsList(List<String> items) {
    galleryItems.clear();
    for (var item in items) {
      final isVideo = _isVideoUrl(item); // Check if it's a video URL
      final index = items.indexOf(item); // Get index for unique ID
      galleryItems.add(
        GalleryItemModel(
          // Create a unique ID using url and index for the Hero tag
          id: '$item-$index',
          url: item, // Use the updated 'url' field
          index: index,
          isVideo: isVideo, // Set the isVideo flag
        ),
      );
    }
  }
}
