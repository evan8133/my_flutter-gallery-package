import 'dart:ui';

import 'package:chewie/chewie.dart'; // Add Chewie import
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:galleryimage/app_cached_network_image.dart';
import 'package:video_player/video_player.dart'; // Add VideoPlayer import

import 'gallery_item_model.dart';
import 'gallery_item_thumbnail.dart'; // Import GalleryItemThumbnail

// to view image in full screen
class GalleryImageViewWrapper extends StatefulWidget {
  final Color? backgroundColor;
  final int? initialIndex;
  final List<GalleryItemModel> galleryItems;
  final String? titleGallery;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final double minScale;
  final double maxScale;
  final double radius;
  final Color closeIconColor;
  final Color closeIconBackgroundColor;
  final bool reverse;
  final bool showListInGalley;
  final bool showAppBar;
  final bool closeWhenSwipeUp;
  final bool closeWhenSwipeDown;
  final Map<String, Uint8List> thumbnailCache; // Add cache parameter

  const GalleryImageViewWrapper({
    super.key,
    required this.titleGallery,
    required this.backgroundColor,
    required this.initialIndex,
    required this.galleryItems,
    required this.thumbnailCache, // Require the cache
    required this.loadingWidget,
    required this.closeIconColor,
    required this.closeIconBackgroundColor,
    required this.errorWidget,
    required this.minScale,
    required this.maxScale,
    required this.radius,
    required this.reverse,
    required this.showListInGalley,
    required this.showAppBar,
    required this.closeWhenSwipeUp,
    required this.closeWhenSwipeDown,
  });

  @override
  State<StatefulWidget> createState() {
    return _GalleryImageViewWrapperState();
  }
}

class _GalleryImageViewWrapperState extends State<GalleryImageViewWrapper> {
  // Correct initialization syntax for PageController
  late final PageController _pageController =
      PageController(initialPage: widget.initialIndex ?? 0);
  late final ScrollController _thumbnailScrollController =
      ScrollController(); // Add ScrollController
  int _currentPage = 0;

  // Video Player State
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  int? _currentVideoIndex; // Keep track of which item is playing

  @override
  void initState() {
    _currentPage = widget.initialIndex ?? 0;
    _pageController.addListener(() {
      final newPage = _pageController.page?.round() ?? 0;
      if (newPage != _currentPage) {
        setState(() {
          _currentPage = newPage;
          _disposeVideoController(); // Dispose previous video controller if any
          _initializeVideoControllerIfNeeded(
              _currentPage); // Initialize for new page if it's a video
          _scrollToThumbnail(_currentPage); // Scroll thumbnails
        });
      }
    });
    _initializeVideoControllerIfNeeded(
        _currentPage); // Initialize for the initial page
    // Scroll to initial thumbnail after layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.showListInGalley) {
        _scrollToThumbnail(_currentPage);
      }
    });
    super.initState();
  }

  // Initialize video controller only if the item is a video
  Future<void> _initializeVideoControllerIfNeeded(int index) async {
    if (index < 0 || index >= widget.galleryItems.length) {
      return; // Bounds check
    }

    final item = widget.galleryItems[index];
    if (item.isVideo) {
      _videoPlayerController =
          VideoPlayerController.networkUrl(Uri.parse(item.url));
      try {
        await _videoPlayerController!.initialize();
        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController!,
          autoPlay: true, // Enable autoplay
          looping: false,
          showControls: false, // Hide controls
          // Add other Chewie options as needed
          errorBuilder: (context, errorMessage) {
            return Center(
              child: Text(
                errorMessage,
                style: const TextStyle(color: Colors.white),
              ),
            );
          },
        );
        _currentVideoIndex = index; // Track the current video index
        // Ensure the UI rebuilds after initialization
        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        if (kDebugMode) {
          print("Error initializing video player for ${item.url}: $e");
        }
        // Optionally handle the error in the UI
        _disposeVideoController(); // Clean up if initialization failed
        if (mounted) {
          setState(() {}); // Update UI to potentially show an error state
        }
      }
    }
  }

  // Dispose video controllers
  void _disposeVideoController() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _videoPlayerController = null;
    _chewieController = null;
    _currentVideoIndex = null; // Reset the tracking index
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbnailScrollController.dispose(); // Dispose ScrollController
    _disposeVideoController(); // Dispose video controllers
    super.dispose();
  }

  // Function to scroll the thumbnail list
  void _scrollToThumbnail(int index) {
    if (!_thumbnailScrollController.hasClients) return;

    // Assuming each thumbnail is roughly 70 wide + 10 padding = 80
    const double itemWidth = 75.0; // Width of thumbnail + padding
    final screenWidth = MediaQuery.of(context).size.width;
    final scrollPosition =
        (index * itemWidth) - (screenWidth / 2) + (itemWidth / 2);

    _thumbnailScrollController.animateTo(
      scrollPosition.clamp(
          0.0,
          _thumbnailScrollController
              .position.maxScrollExtent), // Ensure position is valid
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(widget.titleGallery ?? "Gallery"),
            )
          : null,
      backgroundColor: widget.backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                // Use thumbnail for video background if available, otherwise use image
                child: _buildBackground(_currentPage),
              ),
            ),
            Container(
              constraints: BoxConstraints.expand(
                  height: MediaQuery.of(context).size.height),
              child: Column(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onVerticalDragEnd: (details) {
                        if (widget.closeWhenSwipeUp &&
                            details.primaryVelocity! < 0) {
                          //'up'
                          Navigator.of(context).pop();
                        }
                        if (widget.closeWhenSwipeDown &&
                            details.primaryVelocity! > 0) {
                          // 'down'
                          Navigator.of(context).pop();
                        }
                      },
                      child: PageView.builder(
                        reverse: widget.reverse,
                        controller:
                            _pageController, // Use the renamed controller
                        itemCount: widget.galleryItems.length,
                        itemBuilder: (context, index) {
                          // Pass the correct item and index
                          return _buildItemViewer(
                              widget.galleryItems[index], index);
                        },
                      ),
                    ),
                  ),
                  if (widget.showListInGalley)
                    SizedBox(
                      height: 80,
                      child: SingleChildScrollView(
                        controller:
                            _thumbnailScrollController, // Assign controller
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: widget.galleryItems
                              .asMap() // Use asMap to get index easily
                              .entries
                              .map((entry) => _buildLitImage(
                                  entry.value,
                                  entry.key ==
                                      _currentPage)) // Pass item and selected status
                              .toList(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                },
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                      color: widget.closeIconBackgroundColor,
                      shape: BoxShape.circle),
                  child: Icon(
                    Icons.close,
                    color: widget.closeIconColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to build the background widget
  Widget _buildBackground(int index) {
    final item = widget.galleryItems[index];
    // Check if it's a video and if its thumbnail is cached
    if (item.isVideo && widget.thumbnailCache.containsKey(item.url)) {
      final thumbnailData = widget.thumbnailCache[item.url]!;
      return Image.memory(
        thumbnailData,
        fit: BoxFit.cover,
        // Add error builder for memory image if needed
        errorBuilder: (context, error, stackTrace) {
          // Fallback to network image on error or show placeholder
          return AppCachedNetworkImage(
            fit: BoxFit.cover,
            imageUrl: item.url, // Use original URL as fallback
            loadingWidget: widget.loadingWidget,
            errorWidget: widget.errorWidget,
            radius: 0,
          );
        },
      );
    } else {
      // Default to AppCachedNetworkImage for images or if thumbnail isn't ready
      return AppCachedNetworkImage(
        fit: BoxFit.cover,
        imageUrl: item.url,
        loadingWidget: widget.loadingWidget,
        errorWidget: widget.errorWidget,
        radius: 0,
      );
    }
  }

  // Renamed from _buildImage to handle both images and videos
  Widget _buildItemViewer(GalleryItemModel item, int index) {
    // Check if the current item being built is the one with the active video controller
    final bool isCurrentVideo = item.isVideo &&
        _chewieController != null &&
        _currentVideoIndex == index;

    return Padding(
      padding: const EdgeInsets.all(15),
      child: Hero(
        // Add a prefix to differentiate from thumbnail hero tags
        tag: "main_view_${item.id}",
        child: Center(
          child: item.isVideo
              ? (isCurrentVideo
                  ? Chewie(controller: _chewieController!)
                  : (widget.loadingWidget ??
                      const Center(
                          child:
                              CircularProgressIndicator()))) // Show loading while video initializes
              : InteractiveViewer(
                  // Keep InteractiveViewer for images
                  minScale: widget.minScale,
                  maxScale: widget.maxScale,
                  child: AppCachedNetworkImage(
                    imageUrl: item.url,
                    loadingWidget: widget.loadingWidget,
                    errorWidget: widget.errorWidget,
                    radius: 5, // Keep radius for image consistency if needed
                    fit: BoxFit.contain, // Use contain to see the whole image
                  ),
                ),
        ),
      ),
    );
  }

// build thumbnail image or video representation
// Added isSelected parameter
  Widget _buildLitImage(GalleryItemModel item, bool isSelected) {
    // Determine size based on selection
    final double size = isSelected ? 70 : 60;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: GestureDetector(
        onTap: () {
          // Jump the PageView, the listener will handle video init and scrolling
          _pageController.jumpToPage(item.index);
        },
        child: Container(
          // Add border or visual cue for selected item
          decoration: isSelected
              ? BoxDecoration(
                  border: Border.all(
                      color: Theme.of(context).primaryColor, width: 2),
                  borderRadius: BorderRadius.circular(widget.radius),
                )
              : null,
          child: SizedBox(
            // Use SizedBox to constrain the inner content
            height: size,
            width: size,
            child: GalleryItemThumbnail(
              // Reuse GalleryItemThumbnail
              galleryItem: item,
              thumbnailCache: widget.thumbnailCache, // Pass the cache
              onTap: null, // onTap handled by GestureDetector above
              radius: widget.radius,
              loadingWidget: widget.loadingWidget,
              errorWidget: widget.errorWidget,
            ),
          ),
        ),
      ),
    );
  }
} // End of _GalleryImageViewWrapperState
