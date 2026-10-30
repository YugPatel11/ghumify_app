import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/group_model.dart';
import '../models/group_member_model.dart';
import '../models/group_message_model.dart';
import '../models/group_invitation_model.dart';
import '../models/group_activity_model.dart';
import '../models/group_location_model.dart';
import '../constants/app_constants.dart';

/// Service for group CRUD, membership management, chat, and invitations
class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Collection references ──
  CollectionReference get _groupsRef => _firestore.collection('groups');
  CollectionReference get _invitationsRef =>
      _firestore.collection('group_invitations');
  CollectionReference get _usersRef =>
      _firestore.collection(AppConstants.usersCollection);

  String? get _currentUserId => _auth.currentUser?.uid;

  // ═══════════════════════════════════════════════════════════════════
  // GROUP CRUD
  // ═══════════════════════════════════════════════════════════════════

  /// Create a new group. Creator becomes owner + first admin + first member.
  Future<GroupModel> createGroup({
    required String name,
    String description = '',
    String? photoUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final userDoc = await _usersRef.doc(user.uid).get();
    final userData = userDoc.data() as Map<String, dynamic>?;
    final email = (userData?['email'] ?? user.email ?? '').toString().trim().toLowerCase();
    final displayName = userData?['name'] ?? user.displayName ?? '';

    final docRef = _groupsRef.doc();
    final group = GroupModel(
      id: docRef.id,
      name: name,
      description: description,
      photoUrl: photoUrl,
      ownerId: user.uid,
      adminIds: [user.uid],
      memberIds: [user.uid],
      memberEmails: [email],
      itineraryEditPolicy: 'admins_only',
    );

    final batch = _firestore.batch();

    // Create group document
    batch.set(docRef, group.toFirestore());

    // Create member subdocument for the owner
    final memberRef = docRef.collection('members').doc(user.uid);
    final ownerMember = GroupMemberModel(
      userId: user.uid,
      email: email,
      displayName: displayName,
      photoUrl: user.photoURL,
      role: 'owner',
      canEditItinerary: true,
    );
    batch.set(memberRef, ownerMember.toFirestore());

    // System message: group created
    final msgRef = docRef.collection('messages').doc();
    final systemMsg = GroupMessageModel(
      id: msgRef.id,
      senderId: 'system',
      senderName: 'System',
      type: 'system',
      content: '$displayName created the group',
    );
    batch.set(msgRef, systemMsg.toFirestore());

    await batch.commit();
    return group;
  }

  /// Stream all groups the current user is a member of
  Stream<List<GroupModel>> streamMyGroups() {
    final uid = _currentUserId;
    if (uid == null) return Stream.value([]);

    return _groupsRef
        .where('memberIds', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => GroupModel.fromFirestore(doc)).toList());
  }

  /// Get a single group by ID
  Future<GroupModel?> getGroup(String groupId) async {
    final doc = await _groupsRef.doc(groupId).get();
    if (!doc.exists) return null;
    return GroupModel.fromFirestore(doc);
  }

  /// Stream a single group
  Stream<GroupModel?> streamGroup(String groupId) {
    return _groupsRef.doc(groupId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return GroupModel.fromFirestore(doc);
    });
  }

  /// Update group info (name, description, photo)
  Future<void> updateGroupInfo(
    String groupId, {
    String? name,
    String? description,
    String? photoUrl,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;

    await _groupsRef.doc(groupId).update(updates);
  }

  /// Delete a group (owner only)
  Future<void> deleteGroup(String groupId) async {
    // Delete subcollections first
    final subcollections = ['members', 'messages', 'group_itineraries', 'activity_logs', 'live_locations'];
    for (final sub in subcollections) {
      final snapshots = await _groupsRef.doc(groupId).collection(sub).get();
      final batch = _firestore.batch();
      for (final doc in snapshots.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    // Delete pending invitations for this group
    final invites = await _invitationsRef
        .where('groupId', isEqualTo: groupId)
        .get();
    final invBatch = _firestore.batch();
    for (final doc in invites.docs) {
      invBatch.delete(doc.reference);
    }
    await invBatch.commit();

    // Delete the group document
    await _groupsRef.doc(groupId).delete();
  }

  // ═══════════════════════════════════════════════════════════════════
  // MEMBERSHIP MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════

  /// Add a member by email. Creates invitation if user is not registered.
  Future<String> addMemberByEmail({
    required String groupId,
    required String email,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final normalizedEmail = email.trim().toLowerCase();

    // Validate email format
    if (!_isValidEmail(normalizedEmail)) {
      throw Exception('Invalid email format');
    }

    // Get group info
    final group = await getGroup(groupId);
    if (group == null) throw Exception('Group not found');

    // Check if email is already a member
    if (group.memberEmails.contains(normalizedEmail)) {
      throw Exception('User is already a member');
    }

    // Check if there's already a pending invitation
    final existingInvites = await _invitationsRef
        .where('groupId', isEqualTo: groupId)
        .where('inviteeEmail', isEqualTo: normalizedEmail)
        .where('status', isEqualTo: 'pending')
        .get();
    if (existingInvites.docs.isNotEmpty) {
      throw Exception('Invitation already sent');
    }

    // Look up user by email
    final userQuery = await _usersRef
        .where('email', isEqualTo: normalizedEmail)
        .limit(1)
        .get();

    // Get inviter info
    final inviterDoc = await _usersRef.doc(user.uid).get();
    final inviterData = inviterDoc.data() as Map<String, dynamic>?;
    final inviterName = inviterData?['name'] ?? user.displayName ?? 'Someone';

    if (userQuery.docs.isNotEmpty) {
      // User exists → create invitation they can accept
      final targetUser = userQuery.docs.first;
      final targetUserId = targetUser.id;
      final targetData = targetUser.data() as Map<String, dynamic>;

      final inviteRef = _invitationsRef.doc();
      final invitation = GroupInvitationModel(
        id: inviteRef.id,
        groupId: groupId,
        groupName: group.name,
        groupPhotoUrl: group.photoUrl,
        inviterId: user.uid,
        inviterName: inviterName,
        inviteeEmail: normalizedEmail,
        inviteeUserId: targetUserId,
      );

      await inviteRef.set(invitation.toFirestore());

      // Log activity
      await _logActivity(
        groupId: groupId,
        action: 'member_add',
        details: '$inviterName invited ${targetData['name'] ?? normalizedEmail}',
      );

      return 'Invitation sent to ${targetData['name'] ?? normalizedEmail}';
    } else {
      // User not registered → create pending invite tied to email
      final inviteRef = _invitationsRef.doc();
      final invitation = GroupInvitationModel(
        id: inviteRef.id,
        groupId: groupId,
        groupName: group.name,
        groupPhotoUrl: group.photoUrl,
        inviterId: user.uid,
        inviterName: inviterName,
        inviteeEmail: normalizedEmail,
      );

      await inviteRef.set(invitation.toFirestore());

      await _logActivity(
        groupId: groupId,
        action: 'member_add',
        details: '$inviterName invited $normalizedEmail (not yet registered)',
      );

      return 'Invitation sent. They will see it when they sign up.';
    }
  }

  /// Accept a group invitation
  Future<void> acceptInvitation(String invitationId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final inviteDoc = await _invitationsRef.doc(invitationId).get();
    if (!inviteDoc.exists) throw Exception('Invitation not found');

    final invitation = GroupInvitationModel.fromFirestore(inviteDoc);
    if (!invitation.isPending) throw Exception('Invitation is no longer valid');

    final userDoc = await _usersRef.doc(user.uid).get();
    final userData = userDoc.data() as Map<String, dynamic>?;
    final displayName = userData?['name'] ?? user.displayName ?? '';
    final email = (userData?['email'] ?? user.email ?? '').toString().trim().toLowerCase();

    final batch = _firestore.batch();

    // Update invitation status
    batch.update(_invitationsRef.doc(invitationId), {
      'status': 'accepted',
      'inviteeUserId': user.uid,
    });

    // Add user to group
    batch.update(_groupsRef.doc(invitation.groupId), {
      'memberIds': FieldValue.arrayUnion([user.uid]),
      'memberEmails': FieldValue.arrayUnion([email]),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    // Create member subdocument
    final memberRef = _groupsRef
        .doc(invitation.groupId)
        .collection('members')
        .doc(user.uid);
    final member = GroupMemberModel(
      userId: user.uid,
      email: email,
      displayName: displayName,
      photoUrl: user.photoURL,
      role: 'member',
    );
    batch.set(memberRef, member.toFirestore());

    // System message
    final msgRef = _groupsRef
        .doc(invitation.groupId)
        .collection('messages')
        .doc();
    final systemMsg = GroupMessageModel(
      id: msgRef.id,
      senderId: 'system',
      senderName: 'System',
      type: 'system',
      content: '$displayName joined the group',
    );
    batch.set(msgRef, systemMsg.toFirestore());

    await batch.commit();

    await _logActivity(
      groupId: invitation.groupId,
      action: 'member_add',
      details: '$displayName accepted the invitation and joined',
    );
  }

  /// Decline a group invitation
  Future<void> declineInvitation(String invitationId) async {
    await _invitationsRef.doc(invitationId).update({
      'status': 'declined',
    });
  }

  /// Stream pending invitations for the current user
  Stream<List<GroupInvitationModel>> streamMyInvitations() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);
    final email = (user.email ?? '').trim().toLowerCase();

    return _invitationsRef
        .where('inviteeEmail', isEqualTo: email)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GroupInvitationModel.fromFirestore(doc))
            .where((inv) => !inv.isExpired)
            .toList());
  }

  /// Resolve pending invitations on login/signup for the current user's email
  Future<void> resolveInvitationsForCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final email = (user.email ?? '').trim().toLowerCase();
    if (email.isEmpty) return;

    // No auto-join: invitations remain pending until explicitly accepted
    // This method is called on login to ensure inviteeUserId is updated
    final pendingInvites = await _invitationsRef
        .where('inviteeEmail', isEqualTo: email)
        .where('status', isEqualTo: 'pending')
        .get();

    for (final doc in pendingInvites.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['inviteeUserId'] == null) {
        await doc.reference.update({'inviteeUserId': user.uid});
      }
    }
  }

  /// Remove a member from the group
  Future<void> removeMember({
    required String groupId,
    required String memberId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final memberDoc = await _groupsRef
        .doc(groupId)
        .collection('members')
        .doc(memberId)
        .get();
    if (!memberDoc.exists) throw Exception('Member not found');

    final member = GroupMemberModel.fromFirestore(memberDoc);

    final batch = _firestore.batch();

    // Remove from group arrays
    batch.update(_groupsRef.doc(groupId), {
      'memberIds': FieldValue.arrayRemove([memberId]),
      'memberEmails': FieldValue.arrayRemove([member.email]),
      'adminIds': FieldValue.arrayRemove([memberId]),
      'editableMemberIds': FieldValue.arrayRemove([memberId]),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    // Delete member subdocument
    batch.delete(_groupsRef.doc(groupId).collection('members').doc(memberId));

    // System message
    final msgRef = _groupsRef.doc(groupId).collection('messages').doc();
    final isLeaving = memberId == user.uid;
    final systemMsg = GroupMessageModel(
      id: msgRef.id,
      senderId: 'system',
      senderName: 'System',
      type: 'system',
      content: isLeaving
          ? '${member.displayName} left the group'
          : '${member.displayName} was removed from the group',
    );
    batch.set(msgRef, systemMsg.toFirestore());

    await batch.commit();

    await _logActivity(
      groupId: groupId,
      action: 'member_remove',
      details: isLeaving
          ? '${member.displayName} left'
          : '${member.displayName} was removed',
    );
  }

  /// Leave a group (current user). Handles owner succession.
  Future<void> leaveGroup(String groupId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final group = await getGroup(groupId);
    if (group == null) throw Exception('Group not found');

    // Owner succession logic
    if (group.ownerId == user.uid) {
      final otherAdmins = group.adminIds
          .where((id) => id != user.uid)
          .toList();

      if (otherAdmins.isNotEmpty) {
        // Transfer to longest-tenured co-admin
        final newOwnerId = otherAdmins.first;
        await _groupsRef.doc(groupId).update({
          'ownerId': newOwnerId,
        });

        final newOwnerMemberRef = _groupsRef
            .doc(groupId)
            .collection('members')
            .doc(newOwnerId);
        await newOwnerMemberRef.update({'role': 'owner'});
      } else {
        final otherMembers = group.memberIds
            .where((id) => id != user.uid)
            .toList();

        if (otherMembers.isEmpty) {
          // Last member → delete group
          await deleteGroup(groupId);
          return;
        }

        // Promote longest-tenured member to owner
        final newOwnerId = otherMembers.first;
        await _groupsRef.doc(groupId).update({
          'ownerId': newOwnerId,
          'adminIds': FieldValue.arrayUnion([newOwnerId]),
        });

        final newOwnerMemberRef = _groupsRef
            .doc(groupId)
            .collection('members')
            .doc(newOwnerId);
        await newOwnerMemberRef.update({'role': 'owner'});
      }
    }

    await removeMember(groupId: groupId, memberId: user.uid);
  }

  // ═══════════════════════════════════════════════════════════════════
  // ROLE MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════

  /// Promote a member to admin
  Future<void> promoteToAdmin(String groupId, String memberId) async {
    final batch = _firestore.batch();

    batch.update(_groupsRef.doc(groupId), {
      'adminIds': FieldValue.arrayUnion([memberId]),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    batch.update(
      _groupsRef.doc(groupId).collection('members').doc(memberId),
      {'role': 'admin', 'canEditItinerary': true},
    );

    await batch.commit();

    await _logActivity(
      groupId: groupId,
      action: 'role_change',
      details: 'Promoted to admin',
    );
  }

  /// Demote an admin to member
  Future<void> demoteToMember(String groupId, String memberId) async {
    final group = await getGroup(groupId);
    if (group == null) throw Exception('Group not found');
    if (group.ownerId == memberId) throw Exception('Cannot demote the owner');

    final batch = _firestore.batch();

    batch.update(_groupsRef.doc(groupId), {
      'adminIds': FieldValue.arrayRemove([memberId]),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    batch.update(
      _groupsRef.doc(groupId).collection('members').doc(memberId),
      {'role': 'member'},
    );

    await batch.commit();

    await _logActivity(
      groupId: groupId,
      action: 'role_change',
      details: 'Demoted to member',
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // MEMBERS STREAM
  // ═══════════════════════════════════════════════════════════════════

  /// Stream all members of a group
  Stream<List<GroupMemberModel>> streamMembers(String groupId) {
    return _groupsRef
        .doc(groupId)
        .collection('members')
        .orderBy('joinedAt')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GroupMemberModel.fromFirestore(doc))
            .toList());
  }

  // ═══════════════════════════════════════════════════════════════════
  // CHAT (PHASE 2 - basic send/stream)
  // ═══════════════════════════════════════════════════════════════════

  /// Send a text message
  Future<void> sendMessage({
    required String groupId,
    required String content,
    String type = 'text',
    Map<String, dynamic>? metadata,
    String? replyToMessageId,
    Map<String, String>? replyPreview,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final userDoc = await _usersRef.doc(user.uid).get();
    final userData = userDoc.data() as Map<String, dynamic>?;
    final senderName = userData?['name'] ?? user.displayName ?? 'User';

    final msgRef = _groupsRef.doc(groupId).collection('messages').doc();
    final message = GroupMessageModel(
      id: msgRef.id,
      senderId: user.uid,
      senderName: senderName,
      senderPhotoUrl: user.photoURL,
      type: type,
      content: content,
      metadata: metadata,
      replyToMessageId: replyToMessageId,
      replyPreview: replyPreview,
      seenBy: [user.uid],
    );

    await msgRef.set(message.toFirestore());

    // Update group last message info and bump unread counts
    final group = await getGroup(groupId);
    if (group != null) {
      final newUnreads = Map<String, int>.from(group.unreadCounts);
      for (final memberId in group.memberIds) {
        if (memberId != user.uid) {
          newUnreads[memberId] = (newUnreads[memberId] ?? 0) + 1;
        }
      }

      await _groupsRef.doc(groupId).update({
        'lastMessageText': content,
        'lastMessageSenderName': senderName,
        'lastMessageAt': Timestamp.fromDate(DateTime.now()),
        'unreadCounts': newUnreads,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }
  }

  /// Stream chat messages (paginated, latest first)
  Stream<List<GroupMessageModel>> streamMessages(
    String groupId, {
    int limit = 50,
  }) {
    return _groupsRef
        .doc(groupId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GroupMessageModel.fromFirestore(doc))
            .toList());
  }

  /// Mark messages as seen by current user
  Future<void> markMessagesAsSeen(String groupId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Reset unread count for this user
    await _groupsRef.doc(groupId).update({
      'unreadCounts.${user.uid}': 0,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // ITINERARY POLICY
  // ═══════════════════════════════════════════════════════════════════

  /// Update the itinerary edit policy
  Future<void> updateItineraryEditPolicy({
    required String groupId,
    required String policy,
    List<String>? selectedMemberIds,
  }) async {
    final updates = <String, dynamic>{
      'itineraryEditPolicy': policy,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };

    if (policy == 'selected_members' && selectedMemberIds != null) {
      updates['editableMemberIds'] = selectedMemberIds;
    } else if (policy != 'selected_members') {
      updates['editableMemberIds'] = [];
    }

    await _groupsRef.doc(groupId).update(updates);

    // Update member canEditItinerary flags
    final members = await _groupsRef
        .doc(groupId)
        .collection('members')
        .get();

    final batch = _firestore.batch();
    final group = await getGroup(groupId);

    for (final memberDoc in members.docs) {
      final memberId = memberDoc.id;
      bool canEdit = false;

      if (group != null) {
        canEdit = group.copyWith(
          itineraryEditPolicy: policy,
          editableMemberIds: selectedMemberIds,
        ).canEditItinerary(memberId);
      }

      batch.update(memberDoc.reference, {'canEditItinerary': canEdit});
    }

    await batch.commit();

    await _logActivity(
      groupId: groupId,
      action: 'permission_change',
      details: 'Itinerary edit policy changed to $policy',
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\.\-\+]+@[\w\.\-]+\.\w{2,}$').hasMatch(email);
  }

  Future<void> _logActivity({
    required String groupId,
    required String action,
    required String details,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _usersRef.doc(user.uid).get();
    final userData = userDoc.data() as Map<String, dynamic>?;
    final actorName = userData?['name'] ?? user.displayName ?? 'User';

    final logRef = _groupsRef.doc(groupId).collection('activity_logs').doc();
    final activity = GroupActivityModel(
      id: logRef.id,
      actorId: user.uid,
      actorName: actorName,
      action: action,
      details: details,
    );

    await logRef.set(activity.toFirestore());
  }

  /// Stream activity logs for a group
  Stream<List<GroupActivityModel>> streamActivityLogs(String groupId) {
    return _groupsRef
        .doc(groupId)
        .collection('activity_logs')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GroupActivityModel.fromFirestore(doc))
            .toList());
  }

  // ═══════════════════════════════════════════════════════════════════
  // SHARED ITINERARY
  // ═══════════════════════════════════════════════════════════════════

  /// Stream active shared itinerary for a group
  Stream<Map<String, dynamic>?> streamGroupItinerary(String groupId) {
    return _groupsRef
        .doc(groupId)
        .collection('group_itineraries')
        .doc('active')
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  }

  /// Set or overwrite the shared group itinerary
  Future<void> setGroupItinerary({
    required String groupId,
    required Map<String, dynamic> itineraryData,
    required String actionDescription,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final group = await getGroup(groupId);
    if (group == null) throw Exception('Group not found');
    if (!group.canEditItinerary(user.uid)) {
      throw Exception('Permission denied: You cannot edit this group itinerary');
    }

    final userDoc = await _usersRef.doc(user.uid).get();
    final userData = userDoc.data() as Map<String, dynamic>?;
    final userName = userData?['name'] ?? user.displayName ?? 'A member';

    final batch = _firestore.batch();
    final itineraryRef =
        _groupsRef.doc(groupId).collection('group_itineraries').doc('active');

    final payload = Map<String, dynamic>.from(itineraryData);
    payload['lastModifiedBy'] = user.uid;
    payload['lastModifiedByName'] = userName;
    payload['lastModifiedAt'] = Timestamp.fromDate(DateTime.now());

    batch.set(itineraryRef, payload);

    // Update group root document
    final groupRef = _groupsRef.doc(groupId);
    batch.update(groupRef, {
      'sharedItineraryId': 'active',
      'lastItineraryEditBy': user.uid,
      'lastItineraryEditByName': userName,
      'lastItineraryEditAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    // Add activity log
    final logRef = _groupsRef.doc(groupId).collection('activity_logs').doc();
    final activity = GroupActivityModel(
      id: logRef.id,
      actorId: user.uid,
      actorName: userName,
      action: 'itinerary_edit',
      details: '$userName $actionDescription',
    );
    batch.set(logRef, activity.toFirestore());

    // Post system message to chat
    final msgRef = _groupsRef.doc(groupId).collection('messages').doc();
    final sysMsg = GroupMessageModel(
      id: msgRef.id,
      senderId: 'system',
      senderName: 'System',
      type: 'system',
      content: '$userName $actionDescription',
    );
    batch.set(msgRef, sysMsg.toFirestore());

    await batch.commit();
  }

  /// Import an existing user itinerary into the group
  Future<void> importItineraryToGroup({
    required String groupId,
    required Map<String, dynamic> itineraryData,
    required String city,
  }) async {
    await setGroupItinerary(
      groupId: groupId,
      itineraryData: itineraryData,
      actionDescription: 'shared a trip for $city with the group',
    );
  }

  /// Remove/clear the shared itinerary
  Future<void> clearGroupItinerary(String groupId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final group = await getGroup(groupId);
    if (group == null) throw Exception('Group not found');
    if (!group.isAdmin(user.uid)) {
      throw Exception('Only admins can remove the group itinerary');
    }

    final userDoc = await _usersRef.doc(user.uid).get();
    final userData = userDoc.data() as Map<String, dynamic>?;
    final userName = userData?['name'] ?? user.displayName ?? 'An admin';

    final batch = _firestore.batch();
    final itineraryRef =
        _groupsRef.doc(groupId).collection('group_itineraries').doc('active');
    batch.delete(itineraryRef);

    batch.update(_groupsRef.doc(groupId), {
      'sharedItineraryId': null,
      'lastItineraryEditBy': user.uid,
      'lastItineraryEditByName': userName,
      'lastItineraryEditAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    final logRef = _groupsRef.doc(groupId).collection('activity_logs').doc();
    batch.set(
      logRef,
      GroupActivityModel(
        id: logRef.id,
        actorId: user.uid,
        actorName: userName,
        action: 'itinerary_edit',
        details: '$userName removed the group itinerary',
      ).toFirestore(),
    );

    await batch.commit();
  }

  /// Share a specific itinerary stop to group chat
  Future<void> shareStopToChat({
    required String groupId,
    required Map<String, dynamic> stopData,
    required String city,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final userDoc = await _usersRef.doc(user.uid).get();
    final userData = userDoc.data() as Map<String, dynamic>?;
    final senderName = userData?['name'] ?? user.displayName ?? 'User';
    final stopName = stopData['name'] ?? 'Stop';

    final msgRef = _groupsRef.doc(groupId).collection('messages').doc();
    final message = GroupMessageModel(
      id: msgRef.id,
      senderId: user.uid,
      senderName: senderName,
      senderPhotoUrl: user.photoURL,
      type: 'itinerary_card',
      content: 'Shared itinerary stop: $stopName',
      metadata: {
        'stop': stopData,
        'city': city,
      },
    );

    await msgRef.set(message.toFirestore());

    await _groupsRef.doc(groupId).update({
      'lastMessageText': '📍 Shared stop: $stopName',
      'lastMessageSenderName': senderName,
      'lastMessageAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // LOCATION SHARING
  // ═══════════════════════════════════════════════════════════════════

  /// Share a one-time location pin into the chat
  Future<void> shareLocationPin({
    required String groupId,
    required double latitude,
    required double longitude,
    String? address,
    String? placeName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final userDoc = await _usersRef.doc(user.uid).get();
    final userData = userDoc.data() as Map<String, dynamic>?;
    final senderName = userData?['name'] ?? user.displayName ?? 'User';

    final msgRef = _groupsRef.doc(groupId).collection('messages').doc();
    final message = GroupMessageModel(
      id: msgRef.id,
      senderId: user.uid,
      senderName: senderName,
      senderPhotoUrl: user.photoURL,
      type: 'location_pin',
      content: '📍 Current Location: ${placeName ?? address ?? '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}'}',
      metadata: {
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'placeName': placeName,
      },
    );

    await msgRef.set(message.toFirestore());

    await _groupsRef.doc(groupId).update({
      'lastMessageText': '📍 Shared location pin',
      'lastMessageSenderName': senderName,
      'lastMessageAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Start live location sharing for a given duration
  Future<void> startLiveLocationSharing({
    required String groupId,
    required double latitude,
    required double longitude,
    required Duration duration,
    double? heading,
    double? speed,
    int? batteryLevel,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final userDoc = await _usersRef.doc(user.uid).get();
    final userData = userDoc.data() as Map<String, dynamic>?;
    final userName = userData?['name'] ?? user.displayName ?? 'User';

    final now = DateTime.now();
    final expiresAt = now.add(duration);

    final locationModel = GroupLocationModel(
      userId: user.uid,
      userName: userName,
      userPhotoUrl: user.photoURL,
      latitude: latitude,
      longitude: longitude,
      heading: heading,
      speed: speed,
      batteryLevel: batteryLevel,
      startedAt: now,
      expiresAt: expiresAt,
      updatedAt: now,
      isActive: true,
    );

    final locRef =
        _groupsRef.doc(groupId).collection('live_locations').doc(user.uid);
    await locRef.set(locationModel.toFirestore());

    // Send a live location share announcement card into chat
    final msgRef = _groupsRef.doc(groupId).collection('messages').doc();
    final message = GroupMessageModel(
      id: msgRef.id,
      senderId: user.uid,
      senderName: userName,
      senderPhotoUrl: user.photoURL,
      type: 'live_location_share',
      content: '📡 Started sharing live location (${duration.inMinutes}m)',
      metadata: {
        'durationMinutes': duration.inMinutes,
        'expiresAt': expiresAt.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
      },
    );

    await msgRef.set(message.toFirestore());

    await _groupsRef.doc(groupId).update({
      'lastMessageText': '📡 Live location shared (${duration.inMinutes}m)',
      'lastMessageSenderName': userName,
      'lastMessageAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Update live location coordinates
  Future<void> updateLiveLocationCoordinates({
    required String groupId,
    required double latitude,
    required double longitude,
    double? heading,
    double? speed,
    int? batteryLevel,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final locRef =
        _groupsRef.doc(groupId).collection('live_locations').doc(user.uid);
    final doc = await locRef.get();
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;
    final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      // Auto-expire
      await locRef.update({'isActive': false});
      return;
    }

    await locRef.update({
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading,
      'speed': speed,
      'batteryLevel': batteryLevel,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Stop live location sharing
  Future<void> stopLiveLocationSharing(String groupId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final locRef =
        _groupsRef.doc(groupId).collection('live_locations').doc(user.uid);
    await locRef.update({
      'isActive': false,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Stream all active live locations for a group
  Stream<List<GroupLocationModel>> streamLiveLocations(String groupId) {
    return _groupsRef
        .doc(groupId)
        .collection('live_locations')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GroupLocationModel.fromFirestore(doc))
            .where((loc) => loc.isLive)
            .toList());
  }
}

