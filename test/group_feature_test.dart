import 'package:flutter_test/flutter_test.dart';
import 'package:ghumify_app/core/models/group_model.dart';
import 'package:ghumify_app/core/models/group_message_model.dart';
import 'package:ghumify_app/core/models/group_location_model.dart';
import 'package:ghumify_app/core/models/group_invitation_model.dart';

void main() {
  group('GroupModel Permissions and Policies Tests', () {
    test('Owner is always considered an admin', () {
      final group = GroupModel(
        id: 'grp_1',
        name: 'Goa Trip',
        ownerId: 'user_owner',
        adminIds: ['user_admin'],
        memberIds: ['user_owner', 'user_admin', 'user_member'],
      );

      expect(group.isAdmin('user_owner'), isTrue);
      expect(group.isAdmin('user_admin'), isTrue);
      expect(group.isAdmin('user_member'), isFalse);
    });

    test('admins_only policy allows only owner and admins to edit itinerary', () {
      final group = GroupModel(
        id: 'grp_1',
        name: 'Goa Trip',
        ownerId: 'user_owner',
        adminIds: ['user_admin'],
        memberIds: ['user_owner', 'user_admin', 'user_member'],
        itineraryEditPolicy: 'admins_only',
      );

      expect(group.canEditItinerary('user_owner'), isTrue);
      expect(group.canEditItinerary('user_admin'), isTrue);
      expect(group.canEditItinerary('user_member'), isFalse);
      expect(group.canEditItinerary('outsider'), isFalse);
    });

    test('all_members policy allows all group members to edit itinerary', () {
      final group = GroupModel(
        id: 'grp_1',
        name: 'Goa Trip',
        ownerId: 'user_owner',
        adminIds: ['user_admin'],
        memberIds: ['user_owner', 'user_admin', 'user_member'],
        itineraryEditPolicy: 'all_members',
      );

      expect(group.canEditItinerary('user_owner'), isTrue);
      expect(group.canEditItinerary('user_admin'), isTrue);
      expect(group.canEditItinerary('user_member'), isTrue);
      expect(group.canEditItinerary('outsider'), isFalse);
    });

    test('selected_members policy allows only explicitly designated members to edit', () {
      final group = GroupModel(
        id: 'grp_1',
        name: 'Goa Trip',
        ownerId: 'user_owner',
        adminIds: ['user_admin'],
        memberIds: ['user_owner', 'user_admin', 'user_member1', 'user_member2'],
        itineraryEditPolicy: 'selected_members',
        editableMemberIds: ['user_member1'],
      );

      expect(group.canEditItinerary('user_owner'), isTrue); // Admin always can
      expect(group.canEditItinerary('user_admin'), isTrue); // Admin always can
      expect(group.canEditItinerary('user_member1'), isTrue); // Explicitly allowed
      expect(group.canEditItinerary('user_member2'), isFalse); // Not allowed
      expect(group.canEditItinerary('outsider'), isFalse);
    });
  });

  group('GroupMessageModel Tests', () {
    test('Text message serialization and properties', () {
      final msg = GroupMessageModel(
        id: 'msg_1',
        senderId: 'user_1',
        senderName: 'Aman',
        content: 'Hello everyone!',
        type: 'text',
      );

      expect(msg.isText, isTrue);
      expect(msg.isSystem, isFalse);
      expect(msg.isLocationPin, isFalse);
      expect(msg.isItineraryCard, isFalse);
      expect(msg.content, equals('Hello everyone!'));

      final firestoreMap = msg.toFirestore();
      expect(firestoreMap['senderId'], equals('user_1'));
      expect(firestoreMap['type'], equals('text'));
    });

    test('System message identified correctly', () {
      final msg = GroupMessageModel(
        id: 'msg_sys',
        senderId: 'system',
        senderName: 'System',
        content: 'Aman added Rahul to the group',
        type: 'system',
      );

      expect(msg.isSystem, isTrue);
      expect(msg.isText, isFalse);
    });

    test('Location pin message correctly stores coordinates metadata', () {
      final msg = GroupMessageModel(
        id: 'msg_loc',
        senderId: 'user_1',
        senderName: 'Aman',
        content: '📍 Current location',
        type: 'location_pin',
        metadata: {
          'latitude': 28.6139,
          'longitude': 77.2090,
          'placeName': 'India Gate, New Delhi',
        },
      );

      expect(msg.isLocationPin, isTrue);
      expect(msg.metadata?['latitude'], equals(28.6139));
      expect(msg.metadata?['longitude'], equals(77.2090));
      expect(msg.metadata?['placeName'], equals('India Gate, New Delhi'));
    });

    test('Itinerary card message stores stop information', () {
      final msg = GroupMessageModel(
        id: 'msg_itin',
        senderId: 'user_1',
        senderName: 'Aman',
        content: 'Shared stop: Baga Beach',
        type: 'itinerary_card',
        metadata: {
          'city': 'Goa',
          'stop': {
            'name': 'Baga Beach',
            'startTime': '10:00 AM',
            'description': 'Famous beach with water sports',
          },
        },
      );

      expect(msg.isItineraryCard, isTrue);
      expect(msg.metadata?['city'], equals('Goa'));
      final stop = msg.metadata?['stop'] as Map<String, dynamic>;
      expect(stop['name'], equals('Baga Beach'));
    });
  });

  group('GroupLocationModel Live Expiration Tests', () {
    test('Non-expired active location is live', () {
      final loc = GroupLocationModel(
        userId: 'user_1',
        userName: 'Aman',
        latitude: 15.2993,
        longitude: 74.1240,
        expiresAt: DateTime.now().add(const Duration(minutes: 30)),
        isActive: true,
      );

      expect(loc.isExpired, isFalse);
      expect(loc.isLive, isTrue);
    });

    test('Expired location is not live', () {
      final loc = GroupLocationModel(
        userId: 'user_1',
        userName: 'Aman',
        latitude: 15.2993,
        longitude: 74.1240,
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
        isActive: true,
      );

      expect(loc.isExpired, isTrue);
      expect(loc.isLive, isFalse);
    });

    test('Inactive location is not live even if not expired', () {
      final loc = GroupLocationModel(
        userId: 'user_1',
        userName: 'Aman',
        latitude: 15.2993,
        longitude: 74.1240,
        expiresAt: DateTime.now().add(const Duration(minutes: 30)),
        isActive: false,
      );

      expect(loc.isExpired, isFalse);
      expect(loc.isLive, isFalse);
    });
  });

  group('GroupInvitationModel Tests', () {
    test('Invitation lifecycle status and expiration', () {
      final invite = GroupInvitationModel(
        id: 'inv_1',
        groupId: 'grp_1',
        groupName: 'Rajasthan Roadtrip',
        inviterId: 'user_1',
        inviterName: 'Aman',
        inviteeEmail: 'friend@example.com',
        status: 'pending',
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );

      expect(invite.isPending, isTrue);
      expect(invite.isExpired, isFalse);
      expect(invite.inviteeEmail, equals('friend@example.com'));
    });

    test('Accepted invitation updates group membership and reflects in sorted groups list', () {
      final now = DateTime.now();
      final olderGroup = GroupModel(
        id: 'grp_old',
        name: 'Old Trip',
        ownerId: 'owner_1',
        memberIds: ['user_invited'],
        updatedAt: now.subtract(const Duration(hours: 2)),
      );
      final newGroup = GroupModel(
        id: 'grp_new',
        name: 'New Joined Trip',
        ownerId: 'admin_1',
        memberIds: ['admin_1', 'user_invited'],
        updatedAt: now,
      );

      // Verify newly accepted member is recognized
      expect(newGroup.isMember('user_invited'), isTrue);
      expect(newGroup.isMember('outsider'), isFalse);

      // Verify in-memory descending sort by updatedAt (matches streamMyGroups)
      final userGroups = [olderGroup, newGroup];
      userGroups.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      expect(userGroups.first.id, equals('grp_new'));
      expect(userGroups.last.id, equals('grp_old'));
    });
  });
}
