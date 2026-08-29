import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/itinerary_model.dart';
import '../../../core/providers/auth_provider.dart';

class SavedItinerariesScreen extends StatelessWidget {
  const SavedItinerariesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text(
          'SAVED JOURNEYS',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1d/Taj_Mahal_%28Edited%29.jpeg/1280px-Taj_Mahal_%28Edited%29.jpeg', // Working fallback
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: AppColors.bg),
              errorWidget: (context, url, error) => Container(color: AppColors.bg),
            ),
          ),
          // Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.5),
                    Colors.white.withOpacity(0.8),
                    AppColors.bg,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          
          user == null
              ? _buildEmptyState(context, 'Sign in to view your saved itineraries.')
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection(AppConstants.itinerariesCollection)
                      .where('userId', isEqualTo: user.uid)
                      .where('isSaved', isEqualTo: true)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _buildEmptyState(context, 'Error loading itineraries: ${snapshot.error}');
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.brand),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return _buildEmptyState(context, 'No saved itineraries yet.');
                    }

                    return SafeArea(
                      bottom: false,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(AppTokens.lg, AppTokens.md, AppTokens.lg, 120),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final itinerary = ItineraryModel.fromFirestore(docs[index]);
                          return _buildItineraryCard(context, itinerary);
                        },
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            margin: const EdgeInsets.all(AppTokens.xl),
            padding: const EdgeInsets.all(AppTokens.xxl),
            decoration: BoxDecoration(
              color: AppColors.glassWhite,
              borderRadius: BorderRadius.circular(AppTokens.radiusXl),
              border: Border.all(color: AppColors.borderGlass),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bookmark_outline, size: 48, color: AppColors.textMuted),
                ),
                const SizedBox(height: AppTokens.xl),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: AppTokens.xxl),
                ElevatedButton(
                  onPressed: () => context.push('/plan-trip'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusLg)),
                  ),
                  child: const Text(
                    'Create an Itinerary',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItineraryCard(BuildContext context, ItineraryModel itinerary) {
    final dateStr = "${itinerary.createdAt.year}-${itinerary.createdAt.month.toString().padLeft(2, '0')}-${itinerary.createdAt.day.toString().padLeft(2, '0')}";
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.lg),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.glassWhiteLight,
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              border: Border.all(color: AppColors.borderGlass),
            ),
            child: InkWell(
              onTap: () {
                context.push('/itinerary', extra: {'itinerary': itinerary});
              },
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppTokens.lg),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.brandDeep,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  itinerary.city.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${itinerary.stops.length} Stops • ${itinerary.pace.capitalize()} Pace',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.text,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 12, color: AppColors.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    itinerary.date.isNotEmpty ? itinerary.date : dateStr,
                                    style: const TextStyle(
                                      color: AppColors.textSoft,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.glassWhite,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                          ),
                          onPressed: () => _confirmDelete(context, itinerary),
                        ),
                      ],
                    ),
                  ),
                  if (itinerary.aiSummary != null && itinerary.aiSummary!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppTokens.lg, 0, AppTokens.lg, AppTokens.lg),
                      child: Text(
                        itinerary.aiSummary!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSoft,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, ItineraryModel itinerary) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Itinerary?', style: TextStyle(color: AppColors.text)),
        content: const Text('Are you sure you want to delete this saved itinerary? This cannot be undone.', style: TextStyle(color: AppColors.textSoft)),
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          side: BorderSide(color: AppColors.border),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL', style: TextStyle(color: AppColors.textSoft)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('DELETE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection(AppConstants.itinerariesCollection)
            .doc(itinerary.id)
            .delete();
            
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Itinerary deleted.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
