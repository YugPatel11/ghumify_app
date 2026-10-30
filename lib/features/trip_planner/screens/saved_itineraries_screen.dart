import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/itinerary_model.dart';
import '../../../core/models/multi_city_trip_model.dart';
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
                            final doc = docs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final isMultiCity = data['tripType'] == 'multi_city' ||
                                (data['cities'] is List && (data['cities'] as List).isNotEmpty);

                            if (isMultiCity) {
                              final trip = MultiCityTripModel.fromMap(data);
                              return _buildMultiCityCard(context, trip, doc.id);
                            }

                            final itinerary = ItineraryModel.fromFirestore(doc);
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
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                itinerary.isFamilyFriendly ? Icons.family_restroom : Icons.people_outline,
                                size: 13,
                                color: itinerary.isFamilyFriendly ? AppColors.badgeNature : AppColors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  itinerary.displayTravelersSummary,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: itinerary.isFamilyFriendly ? AppColors.badgeNature : AppColors.textMuted,
                                    fontSize: 12,
                                    fontWeight: itinerary.isFamilyFriendly ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
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

  Widget _buildMultiCityCard(BuildContext context, MultiCityTripModel trip, String docId) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.md),
      child: GestureDetector(
        onTap: () {
          context.push('/multi-city-itinerary', extra: {'trip': trip});
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
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      ),
                      child: const Center(
                        child: Icon(Icons.hub_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                    const SizedBox(width: AppTokens.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.brandDeep,
                                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                                ),
                                child: const Text(
                                  'MULTI-CITY',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${trip.totalDays} Days · ${trip.cities.length} Cities',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSoft,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            trip.routeSummary,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Transit: ₹${trip.estimatedTravelCost} · ${trip.legs.length} Legs',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTokens.md, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Created: ${trip.createdAt.year}-${trip.createdAt.month.toString().padLeft(2, '0')}-${trip.createdAt.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSoft),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Multi-City Trip?'),
                            content: const Text('Are you sure you want to remove this trip?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                child: const Text('Delete', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await FirebaseFirestore.instance
                              .collection(AppConstants.itinerariesCollection)
                              .doc(docId)
                              .delete();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Multi-city trip deleted.')),
                            );
                          }
                        }
                      },
                    ),
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

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
