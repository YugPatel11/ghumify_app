import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';

class ItineraryResultScreen extends StatelessWidget {
  final String city;
  final int days;
  final String itinerary;

  const ItineraryResultScreen({
    super.key,
    required this.city,
    required this.days,
    required this.itinerary,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text('Your $city Itinerary'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.indigoGradient,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppTokens.radiusXl),
                  bottomRight: Radius.circular(AppTokens.radiusXl),
                ),
                boxShadow: AppTokens.coloredShadow(AppColors.indigo, level: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                        ),
                        child: Text(
                          '$days Days'.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.brand,
                          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.auto_awesome, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'AI CRAFTED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ready to explore $city?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We have curated the perfect journey for you.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            
            // Markdown content
            Expanded(
              child: Markdown(
                data: itinerary,
                padding: const EdgeInsets.all(24),
                styleSheet: MarkdownStyleSheet(
                  h1: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: AppColors.brandDeep,
                        fontWeight: FontWeight.w900,
                        height: 1.5,
                      ),
                  h2: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.indigo,
                        fontWeight: FontWeight.w800,
                        height: 1.5,
                      ),
                  h3: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                  p: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSoft,
                        height: 1.6,
                      ),
                  listBullet: const TextStyle(color: AppColors.brand, fontSize: 20),
                  blockquote: const TextStyle(
                    color: AppColors.textSoft,
                    fontStyle: FontStyle.italic,
                  ),
                  blockquoteDecoration: BoxDecoration(
                    color: AppColors.brandSoft,
                    border: const Border(
                      left: BorderSide(color: AppColors.brand, width: 4),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Save functionality
        },
        icon: const Icon(Icons.bookmark_border),
        label: const Text('Save Itinerary', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.brand,
      ),
    );
  }
}
