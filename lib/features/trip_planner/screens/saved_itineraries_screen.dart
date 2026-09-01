import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

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
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppTokens.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
              child: Text('My Trips', style: Theme.of(context).textTheme.displayMedium),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
              child: Text(
                'Your saved itineraries',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: AppTokens.lg),
            Expanded(
              child: user == null
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
                          return _buildEmptyState(context, 'Error loading itineraries.');
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
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(AppTokens.lg, 0, AppTokens.lg, 100),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final itinerary = ItineraryModel.fromFirestore(docs[index]);
                            return _buildItineraryCard(context, itinerary);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTokens.xl),
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.luggage_outlined, size: 48, color: AppColors.brand),
            ),
            const SizedBox(height: AppTokens.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppColors.textSoft),
            ),
            const SizedBox(height: AppTokens.xl),
            ElevatedButton.icon(
              onPressed: () => context.push('/plan-trip'),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Plan a Trip'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItineraryCard(BuildContext context, ItineraryModel itinerary) {
    final dateStr = "${itinerary.createdAt.year}-${itinerary.createdAt.month.toString().padLeft(2, '0')}-${itinerary.createdAt.day.toString().padLeft(2, '0')}";

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.md),
      child: GestureDetector(
        onTap: () {
          context.push('/itinerary', extra: {'itinerary': itinerary});
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppTokens.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppTokens.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // City icon block
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.brandSoft,
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      ),
                      child: const Center(
                        child: Icon(Icons.location_on, color: AppColors.brand, size: 24),
                      ),
                    ),
                    const SizedBox(width: AppTokens.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.brand,
                              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                            ),
                            child: Text(
                              itinerary.city.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${itinerary.stops.length} Stops · ${itinerary.pace.isNotEmpty ? '${itinerary.pace[0].toUpperCase()}${itinerary.pace.substring(1)}' : 'Moderate'} Pace',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 12, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                itinerary.date.isNotEmpty ? itinerary.date : dateStr,
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _confirmDelete(context, itinerary),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              if (itinerary.aiSummary != null && itinerary.aiSummary!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppTokens.md, 0, AppTokens.md, AppTokens.md),
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
    );
  }

  Future<void> _confirmDelete(BuildContext context, ItineraryModel itinerary) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Itinerary?'),
        content: const Text('This cannot be undone.'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSoft)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
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
