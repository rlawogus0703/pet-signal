import 'dart:typed_data';

import '../models/app_notification.dart';
import '../models/candidate.dart';
import '../models/browse_notice.dart';
import '../models/lost_dog.dart';


abstract class PetSignalRepository {

  Future<LostDog> registerLostDog({
    String? photoUrl,
    Uint8List? photoBytes,
    required String breed,
    required String color,
    required String features,
    String? age,
    required DateTime lostDate,
    required double lostLat,
    required double lostLng,
    required String lostAddress,
  });

  Future<LostDog> getLostDog(String id);

  Future<List<Candidate>> getCandidates(String lostDogId, {int limit = 20});

  Future<Candidate> getCandidateDetail(String lostDogId, String noticeId);

  Future<List<AppNotification>> getNotifications(String lostDogId);

  Future<void> markNotificationRead(String notificationId);


  Future<NearbyPage> listNearbyNotices({
    double? lat,
    double? lng,
    String? region,
    String? kind,
    String? color,
    int? days,
    double? radius,
    int page = 1,
    int pageSize = 20,
  });

  Future<BrowseNotice> getNotice(String noticeId);
}
