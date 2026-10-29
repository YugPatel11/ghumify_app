import 'lib/core/services/place_media_service.dart';

void main() async {
  final service = PlaceMediaService();
  final result = await service.fetchMediaForPlace('Hawa Mahal', city: 'Jaipur');
  print('\n\n--- FINAL RESULT IN APP ---');
  print('hasMedia: ${result.hasMedia}');
  print('Images Count: ${result.images.length}');
  print('Video URL: ${result.videoUrl}');
}
