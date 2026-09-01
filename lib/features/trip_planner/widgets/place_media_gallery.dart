import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/models/place_media_model.dart';
import '../../../core/services/place_media_service.dart';

class PlaceMediaGallery extends StatefulWidget {
  final String placeName;
  final String? cityName;

  const PlaceMediaGallery({
    super.key,
    required this.placeName,
    this.cityName,
  });

  @override
  State<PlaceMediaGallery> createState() => _PlaceMediaGalleryState();
}

class _PlaceMediaGalleryState extends State<PlaceMediaGallery> {
  final PlaceMediaService _mediaService = PlaceMediaService();
  final PageController _pageController = PageController();
  
  PlaceMediaModel? _mediaModel;
  bool _isLoading = true;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _fetchMedia();
  }

  @override
  void didUpdateWidget(covariant PlaceMediaGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placeName != widget.placeName) {
      _fetchMedia();
    }
  }

  Future<void> _fetchMedia() async {
    setState(() => _isLoading = true);
    
    try {
      final media = await _mediaService.fetchMediaForPlace(
        widget.placeName, 
        city: widget.cityName,
      );
      
      if (mounted) {
        setState(() {
          _mediaModel = media;
          _isLoading = false;
          _currentPage = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _launchVideo() async {
    if (_mediaModel?.videoUrl == null) return;
    
    final Uri url = Uri.parse(_mediaModel!.videoUrl!);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildShimmer();
    }

    if (_mediaModel == null || !_mediaModel!.hasMedia) {
      // Graceful fallback if no media found
      return const SizedBox.shrink(); 
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Image Carousel ──
        if (_mediaModel!.images.isNotEmpty)
          SizedBox(
            height: 200,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) => setState(() => _currentPage = index),
                    itemCount: _mediaModel!.images.length,
                    itemBuilder: (context, index) {
                      return CachedNetworkImage(
                        imageUrl: _mediaModel!.images[index],
                        fit: BoxFit.cover,
                        placeholder: (context, url) => _buildShimmer(height: double.infinity),
                        errorWidget: (context, url, error) => Container(
                          color: AppColors.bgElevated,
                          child: const Icon(Icons.broken_image, color: AppColors.textSoft),
                        ),
                      );
                    },
                  ),
                ),
                
                // ── Video Play Button Overlay ──
                if (_mediaModel!.hasVideo && _currentPage == 0)
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _launchVideo,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(AppTokens.sm),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── Pagination Indicators ──
                if (_mediaModel!.images.length > 1)
                  Positioned(
                    bottom: AppTokens.sm,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _mediaModel!.images.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 20 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _currentPage == index ? AppColors.brand : Colors.white.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 2)
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
        const SizedBox(height: AppTokens.md),
      ],
    );
  }

  Widget _buildShimmer({double height = 200}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Shimmer.fromColors(
          baseColor: AppColors.cardAlt,
          highlightColor: AppColors.bgElevated,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
            ),
          ),
        ),
        const SizedBox(height: AppTokens.md),
      ],
    );
  }
}
