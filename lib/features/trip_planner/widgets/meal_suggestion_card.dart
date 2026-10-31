import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/food_preferences.dart';
import '../../../core/constants/meal_config.dart';
import '../../../core/models/meal_suggestion_model.dart';

/// Card displaying 2 to 3 restaurant suggestions for Lunch or Dinner in the timeline
class MealSuggestionCard extends StatefulWidget {
  final String mealType; // 'lunch' or 'dinner'
  final String? anchorStopName;
  final List<MealSuggestionModel> suggestions;
  final bool isLoading;
  final String? errorMessage;
  final String foodPreference;
  final bool isSavedMode;
  final DateTime? lastUpdated;
  final VoidCallback? onRefresh;
  final ValueChanged<MealSuggestionModel>? onAddToItinerary;
  final bool isAddedToItinerary;
  final String? addedRestaurantName;
  final VoidCallback? onRemoveFromItinerary;

  const MealSuggestionCard({
    super.key,
    required this.mealType,
    this.anchorStopName,
    required this.suggestions,
    this.isLoading = false,
    this.errorMessage,
    this.foodPreference = 'all',
    this.isSavedMode = false,
    this.lastUpdated,
    this.onRefresh,
    this.onAddToItinerary,
    this.isAddedToItinerary = false,
    this.addedRestaurantName,
    this.onRemoveFromItinerary,
  });

  @override
  State<MealSuggestionCard> createState() => _MealSuggestionCardState();
}

class _MealSuggestionCardState extends State<MealSuggestionCard> {
  int _pageOffset = 0;

  bool get isLunch => widget.mealType == MealConfig.lunch;

  String get timeWindow =>
      isLunch ? '${MealConfig.lunchStartTime} – ${MealConfig.lunchEndTime}' : '${MealConfig.dinnerStartTime} – ${MealConfig.dinnerEndTime}';

  String get title => isLunch ? 'Lunch Suggestions' : 'Dinner Suggestions';

  IconData get mealIcon => isLunch ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded;

  Color get accentColor => isLunch ? const Color(0xFFF59E0B) : const Color(0xFF6366F1);

  List<MealSuggestionModel> get _displayedSuggestions {
    if (widget.suggestions.isEmpty) return [];
    if (widget.suggestions.length <= 3) return widget.suggestions;

    // Cycle through available suggestions in chunks of 3
    final start = _pageOffset % widget.suggestions.length;
    final end = (start + 3).clamp(0, widget.suggestions.length);
    final slice = widget.suggestions.sublist(start, end);
    if (slice.length < 3 && widget.suggestions.length >= 3) {
      final remainder = 3 - slice.length;
      return [...slice, ...widget.suggestions.sublist(0, remainder)];
    }
    return slice;
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    setState(() {
      _pageOffset = (_pageOffset + 3) % widget.suggestions.length;
    });
  }

  Future<void> _launchExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTokens.lg, vertical: AppTokens.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(
          color: widget.isAddedToItinerary ? AppColors.brand.withValues(alpha: 0.5) : AppColors.border,
          width: widget.isAddedToItinerary ? 1.5 : 1.0,
        ),
        boxShadow: AppTokens.shadow(level: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Bar ──
          _buildHeader(context),

          const Divider(height: 1, color: AppColors.borderLight),

          // ── Content State ──
          if (widget.isLoading)
            _buildLoadingState()
          else if (widget.errorMessage != null)
            _buildErrorState()
          else if (widget.suggestions.isEmpty)
            _buildEmptyState()
          else
            _buildSuggestionsList(context),

          // ── Disclaimer & Attribution ──
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.md),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.05),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTokens.radiusLg)),
      ),
      child: Row(
        children: [
          // Meal Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(mealIcon, size: 18, color: accentColor),
          ),
          const SizedBox(width: AppTokens.sm),

          // Titles & Window
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        timeWindow,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  widget.anchorStopName != null && widget.anchorStopName!.isNotEmpty
                      ? 'Suggestions near ${widget.anchorStopName}'
                      : 'Popular nearby dining options',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSoft,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Refresh Button
          if (widget.onRefresh != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.textSoft),
              tooltip: 'Refresh suggestions',
              onPressed: widget.onRefresh,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList(BuildContext context) {
    final displayed = _displayedSuggestions;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.md, vertical: AppTokens.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Jain Warning note if preference is Jain
          if (widget.foodPreference == FoodPreference.jain) ...[
            Container(
              margin: const EdgeInsets.only(bottom: AppTokens.sm),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF059669)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Please confirm Jain preparation with the restaurant before ordering.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Active Added Stop Notification
          if (widget.isAddedToItinerary && widget.addedRestaurantName != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: AppTokens.sm),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.brand),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Added "${widget.addedRestaurantName}" to itinerary as ${isLunch ? 'Lunch' : 'Dinner'} stop.',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandDeep,
                      ),
                    ),
                  ),
                  if (widget.onRemoveFromItinerary != null)
                    GestureDetector(
                      onTap: widget.onRemoveFromItinerary,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'Remove',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.error,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // List of suggestions
          ...displayed.map((restaurant) => _buildRestaurantRow(context, restaurant)),

          // Bottom Bar: "Show other options" & "Last updated"
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.suggestions.length > 3)
                  TextButton.icon(
                    onPressed: _nextPage,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: AppColors.brand),
                    label: const Text(
                      'Show other options',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brand,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                else
                  const SizedBox.shrink(),

                if (widget.lastUpdated != null && widget.isSavedMode)
                  Text(
                    'Last updated ${_formatTimeAgo(widget.lastUpdated!)}',
                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantRow(BuildContext context, MealSuggestionModel item) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        _launchExternalUrl(item.googleMapsUrl);
      },
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(AppTokens.sm + 2),
        decoration: BoxDecoration(
          color: AppColors.cardAlt,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(
            color: AppColors.borderLight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Row 1: Name and Dietary Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _buildDietaryBadge(item.dietaryType, item.dietaryBadge),
            ],
          ),
          const SizedBox(height: 3),

          // Row 2: Cuisine, Distance, Rough Travel Time
          Row(
            children: [
              Expanded(
                child: Text(
                  item.cuisine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Text('\u2022', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
              const SizedBox(width: 6),
              const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textSoft),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  '${item.displayDistance} (${item.displayTravelTime})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
          // Row 3: Rating (if real) & Opening Hours
          const SizedBox(height: 3),
          Row(
            children: [
              if (item.rating != null) ...[
                const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF59E0B)),
                const SizedBox(width: 2),
                Text(
                  item.rating!.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                if (item.reviewCount != null) ...[
                  const SizedBox(width: 2),
                  Text(
                    '(${item.reviewCount})',
                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                  ),
                ],
                const SizedBox(width: 8),
                const Text('•', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                const SizedBox(width: 8),
              ],
              Icon(
                Icons.schedule_rounded,
                size: 12,
                color: item.openingStatus.contains('Open') ? const Color(0xFF10B981) : AppColors.textSoft,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  item.openingStatus,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: item.openingStatus.contains('Open') ? const Color(0xFF10B981) : AppColors.textSoft,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Row 4: Reason text
          if (item.suggestedReason.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              item.suggestedReason,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textSoft,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          // Row 5: Action buttons
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 6,
            runSpacing: 6,
            children: [
              // Google Maps button
              _buildSmallActionButton(
                label: 'Maps',
                icon: Icons.map_outlined,
                onTap: () => _launchExternalUrl(item.googleMapsUrl),
                tooltip: 'Open in Google Maps',
              ),

              // Directions button
              _buildSmallActionButton(
                label: 'Directions',
                icon: Icons.directions_rounded,
                onTap: () => _launchExternalUrl(item.directionsUrl),
                tooltip: 'Get directions in Google Maps',
              ),

              // Call button (if phone exists)
              if (item.phone != null && item.phone!.isNotEmpty)
                _buildSmallActionButton(
                  label: 'Call',
                  icon: Icons.call_outlined,
                  onTap: () => _callPhone(item.phone!),
                  tooltip: 'Call restaurant',
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

  Widget _buildDietaryBadge(String dietaryType, String label) {
    final color = FoodPreference.getIndicatorColor(dietaryType);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: AppColors.textSoft),
              const SizedBox(width: 3),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.all(AppTokens.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          const SizedBox(width: AppTokens.md),
          Text(
            'Finding best nearby $title...',
            style: const TextStyle(fontSize: 12, color: AppColors.textSoft),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(AppTokens.lg),
      child: Column(
        children: [
          const Icon(Icons.restaurant_outlined, size: 28, color: AppColors.textMuted),
          const SizedBox(height: 6),
          const Text(
            'No restaurants found nearby within 5 km.',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          const Text(
            'Try refreshing or searching around a different stop.',
            style: TextStyle(fontSize: 11, color: AppColors.textSoft),
            textAlign: TextAlign.center,
          ),
          if (widget.onRefresh != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: widget.onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Retry Search', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: accentColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    String displayMsg = widget.errorMessage ?? 'Unable to load restaurant suggestions right now.';
    final lower = displayMsg.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('connection failed') ||
        lower.contains('network is unreachable') ||
        lower.contains('errno') ||
        lower.contains('overpass') ||
        lower.contains('timed out')) {
      displayMsg = 'Could not load ${isLunch ? "lunch" : "dinner"} suggestions due to a network connection issue.';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.md, vertical: AppTokens.lg),
      child: Container(
        padding: const EdgeInsets.all(AppTokens.md),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, size: 22, color: AppColors.error),
            const SizedBox(width: AppTokens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayMsg,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Please check your internet connection and tap Retry.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSoft,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.onRefresh != null) ...[
              const SizedBox(width: AppTokens.sm),
              FilledButton.icon(
                onPressed: widget.onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('Retry', style: TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.md, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppTokens.radiusLg)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 11, color: AppColors.textMuted),
          SizedBox(width: 4),
          Expanded(
            child: Text(
              '${MealConfig.osmAttribution} • ${MealConfig.disclaimer}',
              style: TextStyle(
                fontSize: 9.5,
                color: AppColors.textMuted,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
