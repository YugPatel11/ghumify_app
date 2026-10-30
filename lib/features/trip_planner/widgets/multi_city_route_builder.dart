import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/models/city_stay_model.dart';
import '../../../core/models/place_suggestion_model.dart';
import '../../../core/services/places_service.dart';
import '../../../core/services/transport_service.dart';
import '../../../core/utils/image_resolver.dart';

/// Interactive route builder allowing users to add, reorder, configure days, and optimize multi-city journeys.
class MultiCityRouteBuilder extends StatefulWidget {
  final List<CityStayModel> cities;
  final ValueChanged<List<CityStayModel>> onCitiesChanged;
  final bool isRoundTrip;
  final ValueChanged<bool> onRoundTripChanged;
  final DateTime startDate;

  const MultiCityRouteBuilder({
    super.key,
    required this.cities,
    required this.onCitiesChanged,
    required this.isRoundTrip,
    required this.onRoundTripChanged,
    required this.startDate,
  });

  @override
  State<MultiCityRouteBuilder> createState() => _MultiCityRouteBuilderState();
}

class _MultiCityRouteBuilderState extends State<MultiCityRouteBuilder> {
  final TransportService _transportService = TransportService();

  List<NearbyCitySuggestion> _nearbySuggestions = [];
  bool _isLoadingSuggestions = false;
  List<CityStayModel>? _lastBeforeOptimization;

  static const int minCities = 2;
  static const int maxCities = 8;

  @override
  void initState() {
    super.initState();
    _fetchNearbySuggestions();
  }

  @override
  void didUpdateWidget(covariant MultiCityRouteBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cities.length != widget.cities.length ||
        (widget.cities.isNotEmpty &&
            oldWidget.cities.isNotEmpty &&
            widget.cities.last.name != oldWidget.cities.last.name)) {
      _fetchNearbySuggestions();
    }
  }

  Future<void> _fetchNearbySuggestions() async {
    if (widget.cities.isEmpty) return;
    setState(() => _isLoadingSuggestions = true);

    try {
      final baseCity = widget.cities.last;
      final existingNames = widget.cities.map((c) => c.name).toList();
      final results = await _transportService.getNearbyCitySuggestions(
        baseCity: baseCity.name,
        baseLat: baseCity.latitude,
        baseLng: baseCity.longitude,
        excludeCityNames: existingNames,
      );

      if (mounted) {
        setState(() {
          _nearbySuggestions = results;
          _isLoadingSuggestions = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSuggestions = false);
    }
  }

  void _addCity(String name, String state, double lat, double lng) {
    if (widget.cities.length >= maxCities) {
      _showLimitMessage('Maximum $maxCities cities allowed per trip.');
      return;
    }

    HapticFeedback.mediumImpact();
    final updated = List<CityStayModel>.from(widget.cities);
    final newCity = CityStayModel(
      id: 'city_${DateTime.now().millisecondsSinceEpoch}_${updated.length}',
      name: name,
      stateOrRegion: state,
      country: 'India',
      latitude: lat,
      longitude: lng,
      stayDays: 2,
      heroImage: ImageResolver.getHeroImage(name),
    );

    updated.add(newCity);
    widget.onCitiesChanged(_recalculateDates(updated));
  }

  void _insertCityAt(int index, String name, String state, double lat, double lng) {
    if (widget.cities.length >= maxCities) {
      _showLimitMessage('Maximum $maxCities cities allowed per trip.');
      return;
    }

    HapticFeedback.mediumImpact();
    final updated = List<CityStayModel>.from(widget.cities);
    final newCity = CityStayModel(
      id: 'city_${DateTime.now().millisecondsSinceEpoch}_$index',
      name: name,
      stateOrRegion: state,
      country: 'India',
      latitude: lat,
      longitude: lng,
      stayDays: 2,
      heroImage: ImageResolver.getHeroImage(name),
    );

    updated.insert(index, newCity);
    widget.onCitiesChanged(_recalculateDates(updated));
  }

  void _removeCity(int index) {
    if (widget.cities.length <= minCities) {
      _showLimitMessage('A multi-city trip requires at least $minCities cities.');
      return;
    }

    HapticFeedback.lightImpact();
    final updated = List<CityStayModel>.from(widget.cities);
    updated.removeAt(index);
    widget.onCitiesChanged(_recalculateDates(updated));
  }

  void _moveCity(int fromIndex, int toIndex) {
    if (toIndex < 0 || toIndex >= widget.cities.length) return;
    HapticFeedback.selectionClick();
    final updated = List<CityStayModel>.from(widget.cities);
    final item = updated.removeAt(fromIndex);
    updated.insert(toIndex, item);
    widget.onCitiesChanged(_recalculateDates(updated));
  }

  void _updateDays(int index, int delta) {
    HapticFeedback.selectionClick();
    final updated = List<CityStayModel>.from(widget.cities);
    final current = updated[index];
    final newDays = (current.stayDays + delta).clamp(1, 14);
    updated[index] = current.copyWith(stayDays: newDays);
    widget.onCitiesChanged(_recalculateDates(updated));
  }

  void _optimizeRoute() {
    if (widget.cities.length <= 2) return;
    HapticFeedback.mediumImpact();

    _lastBeforeOptimization = List.from(widget.cities);
    final optimized = _transportService.optimizeRoute(
      widget.cities,
      isRoundTrip: widget.isRoundTrip,
    );

    widget.onCitiesChanged(_recalculateDates(optimized));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Route optimized for shortest distance & least backtracking!',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.brand,
        action: SnackBarAction(
          label: 'UNDO',
          textColor: AppColors.accentLight,
          onPressed: () {
            if (_lastBeforeOptimization != null) {
              widget.onCitiesChanged(_lastBeforeOptimization!);
            }
          },
        ),
      ),
    );
  }

  List<CityStayModel> _recalculateDates(List<CityStayModel> list) {
    DateTime current = widget.startDate;
    final updated = <CityStayModel>[];

    for (final c in list) {
      final arrival = current;
      final departure = current.add(Duration(days: c.stayDays));
      updated.add(c.copyWith(arrivalDate: arrival, departureDate: departure));
      current = departure;
    }
    return updated;
  }

  void _showLimitMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openCitySearchModal({int? insertIndex}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CitySearchSheet(
        onCitySelected: (suggestion) {
          Navigator.of(ctx).pop();
          if (insertIndex != null) {
            _insertCityAt(
              insertIndex,
              suggestion.name,
              suggestion.secondaryText,
              suggestion.latitude ?? 28.6139,
              suggestion.longitude ?? 77.2090,
            );
          } else {
            _addCity(
              suggestion.name,
              suggestion.secondaryText,
              suggestion.latitude ?? 28.6139,
              suggestion.longitude ?? 77.2090,
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalDays = widget.cities.fold<int>(0, (sum, c) => sum + c.stayDays);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Route Summary & Best Order Action
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MULTI-CITY ITINERARY ROUTE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: AppColors.textSoft,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.cities.length} Cities · $totalDays Total Days',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brand,
                  ),
                ),
              ],
            ),
            if (widget.cities.length > 2)
              ElevatedButton.icon(
                onPressed: _optimizeRoute,
                icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                label: const Text('Best Order'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandSoft,
                  foregroundColor: AppColors.brand,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppTokens.md),

        // Route Card with Cities and Connectors
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(color: AppColors.border),
            boxShadow: AppTokens.shadow(level: 1),
          ),
          child: Column(
            children: [
              for (int i = 0; i < widget.cities.length; i++) ...[
                _buildCityItem(i),
                if (i < widget.cities.length - 1) _buildTransitConnector(i),
              ],
            ],
          ),
        ),

        const SizedBox(height: AppTokens.md),

        // Add City & Round Trip Controls
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.cities.length < maxCities
                    ? () => _openCitySearchModal()
                    : null,
                icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                label: Text(
                  widget.cities.length < maxCities
                      ? 'Add Another City'
                      : 'Max Cities Reached',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brand,
                  side: const BorderSide(color: AppColors.brand, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTokens.sm),
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onRoundTripChanged(!widget.isRoundTrip);
              },
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.isRoundTrip ? AppColors.brandSoft : AppColors.cardAlt,
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  border: Border.all(
                    color: widget.isRoundTrip ? AppColors.brand : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.isRoundTrip
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color: widget.isRoundTrip ? AppColors.brand : AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Round Trip',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: widget.isRoundTrip ? AppColors.brand : AppColors.textSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Nearby City Suggestions Section
        if (_nearbySuggestions.isNotEmpty) ...[
          const SizedBox(height: AppTokens.lg),
          Row(
            children: [
              const Icon(Icons.explore_outlined, size: 16, color: AppColors.brand),
              const SizedBox(width: 6),
              Text(
                'Suggestions near ${widget.cities.last.name}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const Spacer(),
              if (_isLoadingSuggestions)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _nearbySuggestions.map((s) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: const Icon(Icons.add_circle_outline, size: 16, color: AppColors.brand),
                    label: Text('${s.name} (${s.distanceKm.toInt()} km, ~${s.estimatedHours})'),
                    labelStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                    ),
                    onPressed: () {
                      _addCity(s.name, s.state, s.latitude, s.longitude);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCityItem(int index) {
    final city = widget.cities[index];
    final isFirst = index == 0;
    final isLast = index == widget.cities.length - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // City Index Badge
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: isFirst
                  ? const LinearGradient(colors: [Color(0xFF0F2361), Color(0xFF1A3685)])
                  : null,
              color: isFirst ? null : AppColors.cardAlt,
              shape: BoxShape.circle,
              border: Border.all(
                color: isFirst ? Colors.transparent : AppColors.border,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isFirst ? Colors.white : AppColors.text,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // City Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        city.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isFirst) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.brandSoft,
                          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                        ),
                        child: const Text(
                          'Start',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brand,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  city.stateOrRegion,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

          // Days Counter Stepper
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.cardAlt,
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 14),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                  onPressed: city.stayDays > 1 ? () => _updateDays(index, -1) : null,
                ),
                Text(
                  '${city.stayDays}d',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 14),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                  onPressed: city.stayDays < 14 ? () => _updateDays(index, 1) : null,
                ),
              ],
            ),
          ),

          // Accessible Move Up / Down Buttons
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 18),
                constraints: const BoxConstraints(minWidth: 24, minHeight: 20),
                padding: EdgeInsets.zero,
                color: !isFirst ? AppColors.textSoft : AppColors.border,
                onPressed: !isFirst ? () => _moveCity(index, index - 1) : null,
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                constraints: const BoxConstraints(minWidth: 24, minHeight: 20),
                padding: EdgeInsets.zero,
                color: !isLast ? AppColors.textSoft : AppColors.border,
                onPressed: !isLast ? () => _moveCity(index, index + 1) : null,
              ),
            ],
          ),

          // Remove Button
          if (widget.cities.length > minCities)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
              onPressed: () => _removeCity(index),
            ),
        ],
      ),
    );
  }

  Widget _buildTransitConnector(int index) {
    return Container(
      color: AppColors.cardAlt,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.more_vert, size: 16, color: AppColors.brand),
          const SizedBox(width: 8),
          const Text(
            'Inter-city travel leg',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSoft,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 16, color: AppColors.brand),
            tooltip: 'Insert a stop in between',
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            padding: EdgeInsets.zero,
            onPressed: () => _openCitySearchModal(insertIndex: index + 1),
          ),
        ],
      ),
    );
  }
}

/// Search modal for selecting a city to add to the multi-city route
class _CitySearchSheet extends StatefulWidget {
  final ValueChanged<PlaceSuggestion> onCitySelected;

  const _CitySearchSheet({required this.onCitySelected});

  @override
  State<_CitySearchSheet> createState() => _CitySearchSheetState();
}

class _CitySearchSheetState extends State<_CitySearchSheet> {
  final TextEditingController _controller = TextEditingController();
  final PlacesService _placesService = PlacesService();
  List<PlaceSuggestion> _results = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPopularCities();
  }

  Future<void> _loadPopularCities() async {
    final list = await _placesService.searchPlaceSuggestions('city');
    if (mounted) {
      setState(() => _results = list);
    }
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.trim().length < 2) {
      _loadPopularCities();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final list = await _placesService.searchPlaceSuggestions(query);
      if (mounted) {
        setState(() {
          _results = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(AppTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Add Destination City',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.sm),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search Indian city (e.g. Udaipur, Agra, Varanasi)',
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.brand),
              suffixIcon: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              filled: true,
              fillColor: AppColors.cardAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: AppTokens.md),
          Expanded(
            child: _results.isEmpty
                ? const Center(
                    child: Text(
                      'No destinations found.\nTry typing another Indian city name.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final item = _results[i];
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.brandSoft,
                          child: Icon(Icons.location_city_rounded, color: AppColors.brand, size: 18),
                        ),
                        title: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          item.secondaryText,
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                        trailing: const Icon(Icons.add_rounded, color: AppColors.brand),
                        onTap: () => widget.onCitySelected(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
