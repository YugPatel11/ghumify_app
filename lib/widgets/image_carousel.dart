import 'package:flutter/material.dart';
import 'dart:async';
import '../app/theme/app_colors.dart';
import '../app/theme/app_tokens.dart';
import '../core/widgets/app_image.dart';

class CarouselItem {
  final String imageUrl;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool isAsset;

  CarouselItem({
    required this.imageUrl,
    required this.title,
    this.subtitle,
    this.onTap,
    this.isAsset = false,
  });
}

class ImageCarousel extends StatefulWidget {
  final List<CarouselItem> items;
  final bool autoScroll;
  final String? sectionTitle;

  const ImageCarousel({
    super.key,
    required this.items,
    this.autoScroll = true,
    this.sectionTitle,
  });

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  late PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);

    if (widget.autoScroll && widget.items.isNotEmpty) {
      _startAutoScroll();
    }
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        _currentPage = (_currentPage + 1) % widget.items.length;
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.fastOutSlowIn,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.sectionTitle != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
            child: Text(
              widget.sectionTitle!,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
          ),
        if (widget.sectionTitle != null) const SizedBox(height: AppTokens.md),
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              _currentPage = index;
            },
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              return _buildCarouselCard(widget.items[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCarouselCard(CarouselItem item) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          child: Stack(
            fit: StackFit.expand,
            children: [
              item.isAsset
                  ? Image.asset(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    )
                  : AppImage(
                      imageUrl: item.imageUrl,
                      fit: BoxFit.cover,
                    ),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xB3000000)], // Gradient to 70% black
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
