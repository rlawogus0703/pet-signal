import '../models/app_notification.dart';
import '../models/candidate.dart';
import '../models/lost_dog.dart';

/// 데이터 계층 추상 인터페이스 (Mock ↔ API 교체)
abstract class PetSignalRepository {
  Future<LostDog> registerLostDog({
    String? photoUrl,
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
}
