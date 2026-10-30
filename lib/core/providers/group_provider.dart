import 'dart:async';
import 'package:flutter/material.dart';
import '../models/group_model.dart';
import '../models/group_member_model.dart';
import '../models/group_message_model.dart';
import '../models/group_invitation_model.dart';
import '../services/group_service.dart';

/// State management for Groups feature
class GroupProvider extends ChangeNotifier {
  final GroupService _groupService = GroupService();

  List<GroupModel> _groups = [];
  List<GroupInvitationModel> _invitations = [];
  GroupModel? _currentGroup;
  List<GroupMemberModel> _currentMembers = [];
  List<GroupMessageModel> _currentMessages = [];
  bool _isLoading = false;
  String? _error;

  StreamSubscription? _groupsSub;
  StreamSubscription? _invitationsSub;
  StreamSubscription? _currentGroupSub;
  StreamSubscription? _membersSub;
  StreamSubscription? _messagesSub;

  // Getters
  List<GroupModel> get groups => _groups;
  List<GroupInvitationModel> get invitations => _invitations;
  GroupModel? get currentGroup => _currentGroup;
  List<GroupMemberModel> get currentMembers => _currentMembers;
  List<GroupMessageModel> get currentMessages => _currentMessages;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalUnreadCount =>
      _groups.fold(0, (sum, g) => sum + g.getUnreadCount(_getUserId()));

  String _getUserId() {
    return _groupService.toString().isNotEmpty ? '' : '';
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

  /// Open a specific group — starts streaming its data
  void openGroup(String groupId) {
    _currentGroupSub?.cancel();
    _membersSub?.cancel();
    _messagesSub?.cancel();

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

    // Mark messages as seen when opening
    _groupService.markMessagesAsSeen(groupId);
  }

  /// Close the current group streams
  void closeGroup() {
    _currentGroupSub?.cancel();
    _membersSub?.cancel();
    _messagesSub?.cancel();
    _currentGroup = null;
    _currentMembers = [];
    _currentMessages = [];
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
    super.dispose();
  }
}
