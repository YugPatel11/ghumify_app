import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/group_model.dart';
import '../models/group_member_model.dart';
import '../models/group_message_model.dart';
import '../models/group_invitation_model.dart';
import '../models/group_location_model.dart';
import '../models/group_activity_model.dart';
import '../models/personal_itinerary_model.dart';
import '../services/group_service.dart';
import '../services/location_service.dart';

/// State management for Groups feature
class GroupProvider extends ChangeNotifier {
  final GroupService _groupService = GroupService();
  final LocationService _locationService = LocationService();

  List<GroupModel> _groups = [];
  List<GroupInvitationModel> _invitations = [];
  GroupModel? _currentGroup;
  List<GroupMemberModel> _currentMembers = [];
  List<GroupMessageModel> _currentMessages = [];
  Map<String, dynamic>? _currentItinerary;
  PersonalItineraryModel? _personalItinerary;
  List<PersonalItineraryModel> _allPersonalItineraries = [];
  String _itineraryMode = 'group'; // "group" (Whole Group) | "personal" (Only Me)
  List<GroupLocationModel> _liveLocations = [];
  List<GroupActivityModel> _activityLogs = [];
  bool _isSharingLiveLocation = false;
  Timer? _liveLocationTimer;

  bool _isLoading = false;
  String? _error;

  StreamSubscription? _groupsSub;
  StreamSubscription? _invitationsSub;
  StreamSubscription? _currentGroupSub;
  StreamSubscription? _membersSub;
  StreamSubscription? _messagesSub;
  StreamSubscription? _itinerarySub;
  StreamSubscription? _personalItinerarySub;
  StreamSubscription? _allPersonalItinerariesSub;
  StreamSubscription? _liveLocationsSub;
  StreamSubscription? _activityLogsSub;

  // Getters
  List<GroupModel> get groups => _groups;
  List<GroupInvitationModel> get invitations => _invitations;
  GroupModel? get currentGroup => _currentGroup;
  List<GroupMemberModel> get currentMembers => _currentMembers;
  List<GroupMessageModel> get currentMessages => _currentMessages;
  Map<String, dynamic>? get currentItinerary => _currentItinerary;
  PersonalItineraryModel? get personalItinerary => _personalItinerary;
  List<PersonalItineraryModel> get allPersonalItineraries => _allPersonalItineraries;
  String get itineraryMode => _itineraryMode;
  bool get isPersonalMode => _itineraryMode == 'personal';
  List<GroupLocationModel> get liveLocations => _liveLocations;
  List<GroupActivityModel> get activityLogs => _activityLogs;
  bool get isSharingLiveLocation => _isSharingLiveLocation;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalUnreadCount =>
      _groups.fold(0, (sum, g) => sum + g.getUnreadCount(_getUserId()));

  String _getUserId() {
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  // ── Lifecycle ──

  /// Start listening to the user's groups and invitations
  void init() {
    _groupsSub?.cancel();
    _groupsSub = _groupService.streamMyGroups().listen(
      (groups) {
        _groups = groups;
        notifyListeners();
      },
      onError: (e) {
        _error = 'Failed to load groups: $e';
        notifyListeners();
      },
    );

    _invitationsSub?.cancel();
    _invitationsSub = _groupService.streamMyInvitations().listen(
      (invitations) {
        _invitations = invitations;
        notifyListeners();
      },
      onError: (e) {
        // Silently handle invitation errors
      },
    );

    // Resolve any pending invitations from before the user signed up
    _groupService.resolveInvitationsForCurrentUser();
  }

  /// Switch between "group" (Whole Group) and "personal" (Only Me) modes
  void setItineraryMode(String mode) {
    if (_itineraryMode != mode) {
      _itineraryMode = mode;
      notifyListeners();
    }
  }

  /// Open a specific group — starts streaming its data
  void openGroup(String groupId) {
    _currentGroupSub?.cancel();
    _membersSub?.cancel();
    _messagesSub?.cancel();
    _itinerarySub?.cancel();
    _personalItinerarySub?.cancel();
    _allPersonalItinerariesSub?.cancel();
    _liveLocationsSub?.cancel();
    _activityLogsSub?.cancel();

    final myUid = _getUserId();

    _currentGroupSub = _groupService.streamGroup(groupId).listen(
      (group) {
        _currentGroup = group;
        notifyListeners();
      },
    );

    _membersSub = _groupService.streamMembers(groupId).listen(
      (members) {
        _currentMembers = members;
        notifyListeners();
      },
    );

    _messagesSub = _groupService.streamMessages(groupId).listen(
      (messages) {
        _currentMessages = messages;
        notifyListeners();
      },
    );

    _itinerarySub = _groupService.streamGroupItinerary(groupId).listen(
      (itinerary) {
        _currentItinerary = itinerary;
        notifyListeners();
      },
    );

    if (myUid.isNotEmpty) {
      _personalItinerarySub = _groupService
          .streamPersonalItinerary(groupId, myUid)
          .listen((personal) {
        _personalItinerary = personal;
        notifyListeners();
      });
    }

    _allPersonalItinerariesSub = _groupService
        .streamAllPersonalItineraries(groupId)
        .listen((allPersonal) {
      _allPersonalItineraries = allPersonal;
      notifyListeners();
    });

    _liveLocationsSub = _groupService.streamLiveLocations(groupId).listen(
      (locations) {
        _liveLocations = locations;
        _isSharingLiveLocation = locations.any((l) => l.userId == myUid && l.isLive);
        notifyListeners();
      },
    );

    _activityLogsSub = _groupService.streamActivityLogs(groupId).listen(
      (logs) {
        _activityLogs = logs;
        notifyListeners();
      },
    );

    // Mark messages as seen when opening
    _groupService.markMessagesAsSeen(groupId);
  }

  /// Close the current group streams
  void closeGroup() {
    _currentGroupSub?.cancel();
    _membersSub?.cancel();
    _messagesSub?.cancel();
    _itinerarySub?.cancel();
    _personalItinerarySub?.cancel();
    _allPersonalItinerariesSub?.cancel();
    _liveLocationsSub?.cancel();
    _activityLogsSub?.cancel();
    _liveLocationTimer?.cancel();

    _currentGroup = null;
    _currentMembers = [];
    _currentMessages = [];
    _currentItinerary = null;
    _personalItinerary = null;
    _allPersonalItineraries = [];
    _itineraryMode = 'group';
    _liveLocations = [];
    _activityLogs = [];
    _isSharingLiveLocation = false;
    notifyListeners();
  }

  // ── Group CRUD ──

  Future<GroupModel?> createGroup({
    required String name,
    String description = '',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final group = await _groupService.createGroup(
        name: name,
        description: description,
      );
      _isLoading = false;
      notifyListeners();
      return group;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> deleteGroup(String groupId) async {
    try {
      await _groupService.deleteGroup(groupId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ── Membership ──

  Future<String?> addMember(String groupId, String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _groupService.addMemberByEmail(
        groupId: groupId,
        email: email,
      );
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> acceptInvitation(String invitationId) async {
    try {
      await _groupService.acceptInvitation(invitationId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> declineInvitation(String invitationId) async {
    try {
      await _groupService.declineInvitation(invitationId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> removeMember(String groupId, String memberId) async {
    try {
      await _groupService.removeMember(groupId: groupId, memberId: memberId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> leaveGroup(String groupId) async {
    try {
      await _groupService.leaveGroup(groupId);
      closeGroup();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ── Roles ──

  Future<void> promoteToAdmin(String groupId, String memberId) async {
    try {
      await _groupService.promoteToAdmin(groupId, memberId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> demoteToMember(String groupId, String memberId) async {
    try {
      await _groupService.demoteToMember(groupId, memberId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ── Chat ──

  Future<void> sendMessage(String groupId, String content) async {
    if (content.trim().isEmpty) return;
    try {
      await _groupService.sendMessage(
        groupId: groupId,
        content: content.trim(),
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> markAsSeen(String groupId) async {
    await _groupService.markMessagesAsSeen(groupId);
  }

  // ── Policy ──

  Future<void> updateEditPolicy(
    String groupId,
    String policy, {
    List<String>? selectedMemberIds,
  }) async {
    try {
      await _groupService.updateItineraryEditPolicy(
        groupId: groupId,
        policy: policy,
        selectedMemberIds: selectedMemberIds,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ── Itinerary ──

  Future<void> importItinerary({
    required String groupId,
    required Map<String, dynamic> itineraryData,
    required String city,
  }) async {
    try {
      await _groupService.importItineraryToGroup(
        groupId: groupId,
        itineraryData: itineraryData,
        city: city,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateItinerary({
    required String groupId,
    required Map<String, dynamic> itineraryData,
    required String actionDescription,
  }) async {
    try {
      await _groupService.setGroupItinerary(
        groupId: groupId,
        itineraryData: itineraryData,
        actionDescription: actionDescription,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> clearItinerary(String groupId) async {
    try {
      await _groupService.clearGroupItinerary(groupId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> shareStopToChat({
    required String groupId,
    required Map<String, dynamic> stopData,
    required String city,
  }) async {
    try {
      await _groupService.shareStopToChat(
        groupId: groupId,
        stopData: stopData,
        city: city,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Save personal itinerary with meeting points
  Future<void> savePersonalItinerary({
    required String groupId,
    required PersonalItineraryModel personalItinerary,
    String? actionDescription,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _groupService.savePersonalItinerary(
        groupId: groupId,
        personalItinerary: personalItinerary,
        customActionDescription: actionDescription,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  /// Reset personal itinerary to follow shared group plan
  Future<void> resetPersonalItinerary({
    required String groupId,
    required String userId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _groupService.resetPersonalItinerary(
        groupId: groupId,
        userId: userId,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  // ── Location Sharing ──

  Future<void> shareCurrentLocationPin(String groupId) async {
    try {
      final position = await _locationService.getCurrentPosition();
      await _groupService.shareLocationPin(
        groupId: groupId,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      _error = 'Location error: $e';
      notifyListeners();
    }
  }

  Future<void> startLiveLocationSharing(
    String groupId, {
    Duration duration = const Duration(hours: 1),
  }) async {
    try {
      final position = await _locationService.getCurrentPosition();
      await _groupService.startLiveLocationSharing(
        groupId: groupId,
        latitude: position.latitude,
        longitude: position.longitude,
        duration: duration,
        heading: position.heading,
        speed: position.speed,
      );
      _isSharingLiveLocation = true;
      notifyListeners();

      // Start periodic updates every 30 seconds
      _liveLocationTimer?.cancel();
      _liveLocationTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
        try {
          final pos = await _locationService.getCurrentPosition();
          await _groupService.updateLiveLocationCoordinates(
            groupId: groupId,
            latitude: pos.latitude,
            longitude: pos.longitude,
            heading: pos.heading,
            speed: pos.speed,
          );
        } catch (_) {
          // Silently ignore temporary GPS drop
        }
      });
    } catch (e) {
      _error = 'Failed to start live location: $e';
      notifyListeners();
    }
  }

  Future<void> stopLiveLocationSharing(String groupId) async {
    _liveLocationTimer?.cancel();
    _liveLocationTimer = null;
    try {
      await _groupService.stopLiveLocationSharing(groupId);
      _isSharingLiveLocation = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _groupsSub?.cancel();
    _invitationsSub?.cancel();
    _currentGroupSub?.cancel();
    _membersSub?.cancel();
    _messagesSub?.cancel();
    _itinerarySub?.cancel();
    _personalItinerarySub?.cancel();
    _allPersonalItinerariesSub?.cancel();
    _liveLocationsSub?.cancel();
    _activityLogsSub?.cancel();
    _liveLocationTimer?.cancel();
    super.dispose();
  }
}

