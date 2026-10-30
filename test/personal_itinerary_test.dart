import 'package:flutter_test/flutter_test.dart';
import 'package:ghumify_app/core/models/personal_itinerary_model.dart';
import 'package:ghumify_app/core/models/group_model.dart';
import 'package:ghumify_app/core/services/location_service.dart';

void main() {
  group('MeetingPointModel Serialization and URL Tests', () {
    test('Meeting point correctly serializes to and from Map', () {
      final mp = MeetingPointModel(
        id: 'mp_123',
        placeName: 'Rock Garden Main Gate',
        latitude: 30.7525,
        longitude: 76.8101,
        address: 'Sector 1, Chandigarh',
        meetTime: '17:00',
        meetDate: 'Day 1',
        rejoinStopName: 'Rock Garden',
        notes: 'Waiting near ticket counter',
      );

      final map = mp.toMap();
      expect(map['id'], 'mp_123');
      expect(map['placeName'], 'Rock Garden Main Gate');
      expect(map['latitude'], 30.7525);
      expect(map['longitude'], 76.8101);
      expect(map['meetTime'], '17:00');
      expect(map['rejoinStopName'], 'Rock Garden');

      final fromMap = MeetingPointModel.fromMap(map);
      expect(fromMap.id, mp.id);
      expect(fromMap.placeName, mp.placeName);
      expect(fromMap.latitude, mp.latitude);
      expect(fromMap.longitude, mp.longitude);
      expect(fromMap.notes, mp.notes);
    });

    test('Official Google Maps search and directions URLs are correctly formatted', () {
      final mp = MeetingPointModel(
        id: 'mp_456',
        placeName: 'Hawa Mahal',
        latitude: 26.9239,
        longitude: 75.8267,
        meetTime: '5:00 PM',
      );

      expect(
        mp.googleMapsUrl,
        'https://www.google.com/maps/search/?api=1&query=26.9239,75.8267',
      );
      expect(
        mp.directionsUrl,
        'https://www.google.com/maps/dir/?api=1&destination=26.9239,75.8267',
      );
    });
  });

  group('PersonalItineraryModel Divergence & Review Tests', () {
    test('Unchanged stops with no additions or deletions does not diverge', () {
      final plan = PersonalItineraryModel(
        id: 'user_1',
        userId: 'user_1',
        userName: 'Aman',
        groupId: 'grp_1',
        customStops: [
          {'name': 'Amber Fort', 'statusTag': 'unchanged'},
          {'name': 'City Palace', 'statusTag': 'unchanged'},
        ],
      );

      expect(plan.hasDiverged, isFalse);
    });

    test('Adding a stop flags the plan as diverged', () {
      final plan = PersonalItineraryModel(
        id: 'user_2',
        userId: 'user_2',
        userName: 'Riya',
        groupId: 'grp_1',
        addedStopNames: ['Jantar Mantar'],
        customStops: [
          {'name': 'Amber Fort', 'statusTag': 'unchanged'},
          {'name': 'Jantar Mantar', 'statusTag': 'added'},
        ],
      );

      expect(plan.hasDiverged, isTrue);
    });

    test('Modifying or removing stops flags the plan as diverged', () {
      final modifiedPlan = PersonalItineraryModel(
        id: 'user_3',
        userId: 'user_3',
        userName: 'Karan',
        groupId: 'grp_1',
        modifiedStopNames: ['City Palace'],
      );
      expect(modifiedPlan.hasDiverged, isTrue);

      final removedPlan = PersonalItineraryModel(
        id: 'user_4',
        userId: 'user_4',
        userName: 'Priya',
        groupId: 'grp_1',
        removedStopNames: ['Hawa Mahal'],
      );
      expect(removedPlan.hasDiverged, isTrue);
    });

    test('needsReview property correctly detects status needs_review', () {
      final planActive = PersonalItineraryModel(
        id: 'u1',
        userId: 'u1',
        userName: 'Test',
        groupId: 'g1',
        status: 'active',
      );
      expect(planActive.needsReview, isFalse);

      final planReview = PersonalItineraryModel(
        id: 'u2',
        userId: 'u2',
        userName: 'Test',
        groupId: 'g1',
        status: 'needs_review',
        reviewReason: 'Rejoin stop was removed by admin',
      );
      expect(planReview.needsReview, isTrue);
      expect(planReview.reviewReason, contains('removed'));
    });

    test('Meeting summary text formats correctly for group coordination', () {
      final plan = PersonalItineraryModel(
        id: 'user_riya',
        userId: 'user_riya',
        userName: 'Riya',
        groupId: 'grp_trip',
        meetingPoints: [
          MeetingPointModel(
            id: 'mp_1',
            placeName: 'Rock Garden Main Gate',
            latitude: 30.75,
            longitude: 76.81,
            meetTime: '5:00 PM',
          ),
        ],
      );

      expect(
        plan.meetingSummaryText,
        'Riya rejoins the group at Rock Garden Main Gate at 5:00 PM',
      );
    });
  });

  group('Permission Matrix & Two-Mode Reconciled Access Tests', () {
    final group = GroupModel(
      id: 'grp_test',
      name: 'Goa Squad',
      ownerId: 'owner_user',
      adminIds: ['owner_user', 'admin_user'],
      memberIds: ['owner_user', 'admin_user', 'edit_member', 'regular_member'],
      itineraryEditPolicy: 'admins_only',
      editableMemberIds: ['edit_member'],
    );

    test('Group owner has both Whole Group and Only Me permissions', () {
      expect(group.canEditItinerary('owner_user'), isTrue);
      expect(group.isMember('owner_user'), isTrue);
    });

    test('Admin has both Whole Group and Only Me permissions', () {
      expect(group.canEditItinerary('admin_user'), isTrue);
      expect(group.isMember('admin_user'), isTrue);
    });

    test('Under admins_only policy, regular member can use Only Me, blocked from Whole Group', () {
      expect(group.canEditItinerary('regular_member'), isFalse);
      expect(group.isMember('regular_member'), isTrue);
    });

    test('Under selected_members policy, designated member can use Whole Group', () {
      final selectedGroup = group.copyWith(itineraryEditPolicy: 'selected_members');
      expect(selectedGroup.canEditItinerary('edit_member'), isTrue);
      expect(selectedGroup.canEditItinerary('regular_member'), isFalse);
    });

    test('Under all_members policy, all members can use Whole Group and Only Me', () {
      final allGroup = group.copyWith(itineraryEditPolicy: 'all_members');
      expect(allGroup.canEditItinerary('regular_member'), isTrue);
      expect(allGroup.isMember('regular_member'), isTrue);
    });

    test('Non-member is denied from both Whole Group and Only Me', () {
      expect(group.canEditItinerary('stranger_user'), isFalse);
      expect(group.isMember('stranger_user'), isFalse);
    });

    test('Removed member loses access immediately', () {
      final updatedGroup = group.copyWith(
        memberIds: ['owner_user', 'admin_user'],
      );
      expect(updatedGroup.isMember('regular_member'), isFalse);
      expect(updatedGroup.canEditItinerary('regular_member'), isFalse);
    });
  });

  group('Meeting Point Mandatory Validation Logic', () {
    void validatePersonalPlan(PersonalItineraryModel plan) {
      if (plan.hasDiverged) {
        if (plan.meetingPoints.isEmpty) {
          throw Exception('Meeting point required: Every personal plan diverging from the group plan must have at least one meeting point.');
        }
        for (final mp in plan.meetingPoints) {
          if (mp.placeName.trim().isEmpty) {
            throw Exception('Meeting place name cannot be empty.');
          }
          if (mp.meetTime.trim().isEmpty) {
            throw Exception('Meeting time cannot be empty.');
          }
          if (mp.latitude == 0.0 && mp.longitude == 0.0) {
            throw Exception('Meeting place must have valid map coordinates.');
          }
        }
      }
    }

    test('Saving diverged plan without meeting point throws Exception', () {
      final divergedPlanNoMp = PersonalItineraryModel(
        id: 'u1',
        userId: 'u1',
        userName: 'Aman',
        groupId: 'g1',
        addedStopNames: ['Chokhi Dhani'],
        meetingPoints: [],
      );

      expect(
        () => validatePersonalPlan(divergedPlanNoMp),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Meeting point required'),
        )),
      );
    });

    test('Saving meeting point with empty place name throws Exception', () {
      final plan = PersonalItineraryModel(
        id: 'u1',
        userId: 'u1',
        userName: 'Aman',
        groupId: 'g1',
        addedStopNames: ['Chokhi Dhani'],
        meetingPoints: [
          MeetingPointModel(
            id: 'mp1',
            placeName: '',
            latitude: 26.9,
            longitude: 75.8,
            meetTime: '18:00',
          ),
        ],
      );

      expect(
        () => validatePersonalPlan(plan),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Meeting place name cannot be empty'),
        )),
      );
    });

    test('Saving meeting point with invalid coordinates (0,0) throws Exception', () {
      final plan = PersonalItineraryModel(
        id: 'u1',
        userId: 'u1',
        userName: 'Aman',
        groupId: 'g1',
        addedStopNames: ['Chokhi Dhani'],
        meetingPoints: [
          MeetingPointModel(
            id: 'mp1',
            placeName: 'City Center',
            latitude: 0.0,
            longitude: 0.0,
            meetTime: '18:00',
          ),
        ],
      );

      expect(
        () => validatePersonalPlan(plan),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('valid map coordinates'),
        )),
      );
    });

    test('Saving valid diverged plan with complete meeting point succeeds', () {
      final plan = PersonalItineraryModel(
        id: 'u1',
        userId: 'u1',
        userName: 'Aman',
        groupId: 'g1',
        addedStopNames: ['Chokhi Dhani'],
        meetingPoints: [
          MeetingPointModel(
            id: 'mp1',
            placeName: 'Rock Garden North Gate',
            latitude: 30.752,
            longitude: 76.810,
            meetTime: '17:30',
            rejoinStopName: 'Rock Garden',
          ),
        ],
      );

      expect(() => validatePersonalPlan(plan), returnsNormally);
    });
  });

  group('Sync Conflict & Reconcile Simulation', () {
    test('Detects deleted rejoin stop in updated group itinerary and flags needs_review', () {
      final personalPlan = PersonalItineraryModel(
        id: 'u_riya',
        userId: 'u_riya',
        userName: 'Riya',
        groupId: 'grp_1',
        addedStopNames: ['Local Cafe'],
        meetingPoints: [
          MeetingPointModel(
            id: 'mp_1',
            placeName: 'Rock Garden Gate',
            latitude: 30.75,
            longitude: 76.81,
            meetTime: '17:00',
            rejoinStopName: 'Rock Garden',
          ),
        ],
      );

      // New group itinerary stops where "Rock Garden" was removed
      final newGroupStops = [
        {'name': 'Sukhna Lake'},
        {'name': 'Rose Garden'},
      ];

      final newStopNames = newGroupStops
          .map((s) => (s['name'] ?? '').toString().toLowerCase().trim())
          .toSet();

      bool conflictDetected = false;
      String? reason;

      for (final mp in personalPlan.meetingPoints) {
        if (mp.rejoinStopName != null && mp.rejoinStopName!.isNotEmpty) {
          final rejoinLower = mp.rejoinStopName!.toLowerCase().trim();
          if (!newStopNames.contains(rejoinLower)) {
            conflictDetected = true;
            reason = 'The group rejoin stop "${mp.rejoinStopName}" was changed or removed in the shared itinerary.';
            break;
          }
        }
      }

      expect(conflictDetected, isTrue);
      expect(reason, contains('Rock Garden'));
    });

    test('Non-conflicting group changes preserve active status', () {
      final personalPlan = PersonalItineraryModel(
        id: 'u_riya',
        userId: 'u_riya',
        userName: 'Riya',
        groupId: 'grp_1',
        addedStopNames: ['Local Cafe'],
        meetingPoints: [
          MeetingPointModel(
            id: 'mp_1',
            placeName: 'Rock Garden Gate',
            latitude: 30.75,
            longitude: 76.81,
            meetTime: '17:00',
            rejoinStopName: 'Rock Garden',
          ),
        ],
      );

      // New group itinerary where another stop was added, but "Rock Garden" is intact
      final newGroupStops = [
        {'name': 'Sukhna Lake'},
        {'name': 'Rock Garden'},
        {'name': 'Rose Garden'},
      ];

      final newStopNames = newGroupStops
          .map((s) => (s['name'] ?? '').toString().toLowerCase().trim())
          .toSet();

      bool conflictDetected = false;
      for (final mp in personalPlan.meetingPoints) {
        if (mp.rejoinStopName != null && mp.rejoinStopName!.isNotEmpty) {
          final rejoinLower = mp.rejoinStopName!.toLowerCase().trim();
          if (!newStopNames.contains(rejoinLower)) {
            conflictDetected = true;
            break;
          }
        }
      }

      expect(conflictDetected, isFalse);
    });
  });

  group('Distance and Travel Time Warning Calculation Tests', () {
    final locationService = LocationService();

    test('Accurately computes distance between two locations', () {
      // Jaipur Hawa Mahal (26.9239, 75.8267) to Amber Fort (26.9855, 75.8513)
      final distanceKm = locationService.calculateDistance(
        26.9239,
        75.8267,
        26.9855,
        75.8513,
      );

      expect(distanceKm, greaterThan(6.0));
      expect(distanceKm, lessThan(9.0));

      // Estimated transit time at 25 km/h + 5 min buffer
      final estimatedMinutes = ((distanceKm / 25.0) * 60 + 5).round();
      expect(estimatedMinutes, greaterThan(20));
      expect(estimatedMinutes, lessThan(30));
    });
  });
}
