class GalleryItemModel {
  GalleryItemModel({
    required this.id,
    required this.url, // Renamed from imageUrl for clarity
    required this.index,
    this.isVideo = false, // Added isVideo flag
  });
  // index in list of media
  final int index;
  // id media (url) to use in hero animation
  final String id;
  // media url (image or video)
  final String url;
  // Flag to identify video content
  final bool isVideo;
}
