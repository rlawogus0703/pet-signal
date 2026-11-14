import 'dart:typed_data';

import '../models/app_notification.dart';
import '../models/candidate.dart';
import '../models/lost_dog.dart';

/// 데이터 계층 추상 인터페이스 (Mock ↔ API 교체)
abstract class PetSignalRepository {
  /// [photoBytes]: 보호자가 올린 사진 (이미지 유사도 계산에 사용)
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
}
