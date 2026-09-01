class PlaceMediaModel {
  final String placeName;
  final List<String> images;
  final String? videoUrl;
  final String source;

  PlaceMediaModel({
    required this.placeName,
    required this.images,
    this.videoUrl,
    required this.source,
  });

  factory PlaceMediaModel.empty(String placeName) {
    return PlaceMediaModel(
      placeName: placeName,
      images: [],
      source: 'none',
    );
  }

  bool get hasMedia => images.isNotEmpty || videoUrl != null;
  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;
}
