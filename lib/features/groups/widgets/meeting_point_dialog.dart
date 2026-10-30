import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/models/personal_itinerary_model.dart';
import '../../../core/models/place_suggestion_model.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/places_service.dart';

/// Modal dialog to create or edit a mandatory meeting point where the member rejoins the group
class MeetingPointDialog extends StatefulWidget {
  final MeetingPointModel? initialMeetingPoint;
  final List<Map<String, dynamic>> groupStops;
  final Map<String, dynamic>? lastPersonalStop;

  const MeetingPointDialog({
    super.key,
    this.initialMeetingPoint,
    required this.groupStops,
    this.lastPersonalStop,
  });

  @override
  State<MeetingPointDialog> createState() => _MeetingPointDialogState();
}

class _MeetingPointDialogState extends State<MeetingPointDialog> {
  final _formKey = GlobalKey<FormState>();
  final _placeNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _timeController = TextEditingController();
  final _dateController = TextEditingController();
  final _notesController = TextEditingController();
  final _searchQueryController = TextEditingController();

  final PlacesService _placesService = PlacesService();
  final LocationService _locationService = LocationService();

  double _latitude = 0.0;
  double _longitude = 0.0;
  String? _selectedRejoinStop;
  List<PlaceSuggestion> _searchResults = [];
  bool _isSearching = false;
  String? _travelWarning;

  @override
  void initState() {
    super.initState();
    final mp = widget.initialMeetingPoint;
    if (mp != null) {
      _placeNameController.text = mp.placeName;
      _addressController.text = mp.address ?? '';
      _timeController.text = mp.meetTime;
      _dateController.text = mp.meetDate ?? 'Day 1';
      _notesController.text = mp.notes ?? '';
      _latitude = mp.latitude;
      _longitude = mp.longitude;
      _selectedRejoinStop = mp.rejoinStopName;
    } else {
      _dateController.text = 'Day 1';
      _timeController.text = '17:00';
      if (widget.groupStops.isNotEmpty) {
        final last = widget.groupStops.last;
        _selectGroupStop(last);
      }
    }
    _checkTravelTimeWarning();
  }

  @override
  void dispose() {
    _placeNameController.dispose();
    _addressController.dispose();
    _timeController.dispose();
    _dateController.dispose();
    _notesController.dispose();
    _searchQueryController.dispose();
    super.dispose();
  }

  void _selectGroupStop(Map<String, dynamic> stop) {
    setState(() {
      _placeNameController.text = stop['name'] ?? '';
      _addressController.text = stop['description'] ?? stop['city'] ?? '';
      _latitude = (stop['latitude'] as num?)?.toDouble() ?? 0.0;
      _longitude = (stop['longitude'] as num?)?.toDouble() ?? 0.0;
      _selectedRejoinStop = stop['name'];
      _searchResults.clear();
      _searchQueryController.clear();
    });
    _checkTravelTimeWarning();
  }

  void _selectSearchResult(PlaceSuggestion suggestion) {
    setState(() {
      _placeNameController.text = suggestion.name;
      _addressController.text = suggestion.secondaryText;
      _latitude = suggestion.latitude ?? 28.6139;
      _longitude = suggestion.longitude ?? 77.2090;
      _searchResults.clear();
      _searchQueryController.clear();
    });
    _checkTravelTimeWarning();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await _placesService.searchPlaceSuggestions(query.trim());
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _checkTravelTimeWarning() {
    final lastStop = widget.lastPersonalStop;
    if (lastStop == null || _latitude == 0.0 || _longitude == 0.0) {
      _travelWarning = null;
      return;
    }

    final prevLat = (lastStop['latitude'] as num?)?.toDouble();
    final prevLng = (lastStop['longitude'] as num?)?.toDouble();
    if (prevLat == null || prevLng == null || (prevLat == 0.0 && prevLng == 0.0)) {
      _travelWarning = null;
      return;
    }

    final distanceKm = _locationService.calculateDistance(prevLat, prevLng, _latitude, _longitude);
    final estimatedMinutes = ((distanceKm / 25.0) * 60 + 5).round();

    // Check if time difference between last stop end time and meet time is tight
    final lastEndTime = (lastStop['endTime'] ?? '').toString();
    final meetTime = _timeController.text.trim();

    final prevMinutes = _parseTimeToMinutes(lastEndTime);
    final meetMinutes = _parseTimeToMinutes(meetTime);

    if (prevMinutes != null && meetMinutes != null) {
      final diff = meetMinutes - prevMinutes;
      if (diff > 0 && diff < estimatedMinutes) {
        setState(() {
          _travelWarning =
              'Travel time notice: Distance is ${distanceKm.toStringAsFixed(1)} km (~$estimatedMinutes mins estimate). You have $diff mins scheduled, which may be tight.';
        });
        return;
      }
    }

    if (distanceKm > 15.0) {
      setState(() {
        _travelWarning =
            'Estimated travel distance is ${distanceKm.toStringAsFixed(1)} km (~$estimatedMinutes mins transit). Please verify traffic conditions.';
      });
    } else {
      setState(() => _travelWarning = null);
    }
  }

  int? _parseTimeToMinutes(String timeStr) {
    if (timeStr.isEmpty) return null;
    final clean = timeStr.trim().toLowerCase();
    try {
      if (clean.contains(':')) {
        final parts = clean.split(':');
        int hours = int.parse(parts[0].replaceAll(RegExp(r'[^0-9]'), ''));
        int mins = parts.length > 1 ? int.parse(parts[1].substring(0, 2).replaceAll(RegExp(r'[^0-9]'), '')) : 0;
        if (clean.contains('pm') && hours < 12) hours += 12;
        if (clean.contains('am') && hours == 12) hours = 0;
        return hours * 60 + mins;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _pickTime() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: now,
    );
    if (picked != null) {
      final hourStr = picked.hour.toString().padLeft(2, '0');
      final minuteStr = picked.minute.toString().padLeft(2, '0');
      setState(() {
        _timeController.text = '$hourStr:$minuteStr';
      });
      _checkTravelTimeWarning();
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_latitude == 0.0 && _longitude == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select a valid place with coordinates.',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final id = widget.initialMeetingPoint?.id ??
        'mp_${DateTime.now().millisecondsSinceEpoch}';

    final result = MeetingPointModel(
      id: id,
      placeName: _placeNameController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      address: _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : null,
      meetTime: _timeController.text.trim(),
      meetDate: _dateController.text.trim().isNotEmpty
          ? _dateController.text.trim()
          : null,
      rejoinStopName: _selectedRejoinStop,
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
      ),
      child: Container(
        constraints: BoxConstraints(maxWidth: 500, maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.all(AppTokens.lg),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.place_rounded,
                      color: AppColors.brand,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppTokens.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.initialMeetingPoint == null
                              ? 'Set Meeting Point'
                              : 'Edit Meeting Point',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        Text(
                          'Where you will rejoin the group (Required)',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.md),

              // Quick Pick from Group Stops
              if (widget.groupStops.isNotEmpty) ...[
                Text(
                  'Quick Pick from Group Itinerary Stops:',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSoft,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.groupStops.take(6).map((stop) {
                    final isSelected = _placeNameController.text == stop['name'];
                    return ActionChip(
                      label: Text(
                        stop['name'] ?? '',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: isSelected ? Colors.white : AppColors.text,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      backgroundColor: isSelected ? AppColors.brand : AppColors.cardAlt,
                      side: BorderSide(
                        color: isSelected ? AppColors.brand : AppColors.border,
                      ),
                      onPressed: () => _selectGroupStop(stop),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppTokens.md),
              ],

              // Search place
              Text(
                'Or Search Any Place / Landmark:',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSoft,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _searchQueryController,
                decoration: InputDecoration(
                  hintText: 'Search landmark, hotel, or station...',
                  hintStyle: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand),
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.cardAlt,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
                onChanged: _performSearch,
              ),

              if (_searchResults.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 160),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final item = _searchResults[index];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.place_outlined, size: 18, color: AppColors.brand),
                        title: Text(
                          item.name,
                          style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          item.secondaryText,
                          style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _selectSearchResult(item),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: AppTokens.md),

              // Meeting Place Name Field
              TextFormField(
                controller: _placeNameController,
                style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text),
                decoration: InputDecoration(
                  labelText: 'Meeting Place Name *',
                  labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.cardAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Place name is required';
                  }
                  return null;
                },
                onChanged: (_) => _checkTravelTimeWarning(),
              ),

              const SizedBox(height: AppTokens.sm),

              // Address Field
              TextFormField(
                controller: _addressController,
                style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text),
                decoration: InputDecoration(
                  labelText: 'Address or Area (Optional)',
                  labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.cardAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),

              const SizedBox(height: AppTokens.sm),

              // Time and Date Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _timeController,
                      readOnly: true,
                      onTap: _pickTime,
                      style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text),
                      decoration: InputDecoration(
                        labelText: 'Rejoin Time *',
                        labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                        prefixIcon: const Icon(Icons.access_time_rounded, size: 18, color: AppColors.brand),
                        filled: true,
                        fillColor: AppColors.cardAlt,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Time is required';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: AppTokens.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _dateController,
                      style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text),
                      decoration: InputDecoration(
                        labelText: 'Day / Date',
                        labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                        prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.brand),
                        filled: true,
                        fillColor: AppColors.cardAlt,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppTokens.sm),

              // Rejoin Stop Dropdown
              if (widget.groupStops.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedRejoinStop,
                  dropdownColor: AppColors.card,
                  decoration: InputDecoration(
                    labelText: 'Group Stop to Rejoin At (Optional)',
                    labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.cardAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  items: widget.groupStops.map((stop) {
                    final name = stop['name'] ?? '';
                    return DropdownMenuItem<String>(
                      value: name,
                      child: Text(
                        name,
                        style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedRejoinStop = val);
                  },
                ),

              const SizedBox(height: AppTokens.sm),

              // Notes field
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text),
                decoration: InputDecoration(
                  labelText: 'Meeting Notes / Exact Landmark (Optional)',
                  hintText: 'e.g. Near the main entrance ticket booth',
                  labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                  hintStyle: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.cardAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),

              // Travel Time Warning
              if (_travelWarning != null) ...[
                const SizedBox(height: AppTokens.md),
                Container(
                  padding: const EdgeInsets.all(AppTokens.sm),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                    border: Border.all(color: AppColors.warning.withOpacity(0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _travelWarning!,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.warning,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppTokens.lg),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.outfit(color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(width: AppTokens.sm),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      'Set Meeting Point',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      ),
                    ),
                    onPressed: _save,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
