import 'package:uuid/uuid.dart';

import '../matching/scorer.dart';
import '../models/app_notification.dart';
import '../models/candidate.dart';
import '../models/lost_dog.dart';
import 'mock_data.dart';
import 'repository.dart';

/// 오프라인 시연용: 예시 공고 + Dart 규칙 스코어러
class MockRepository implements PetSignalRepository {
  final _uuid = const Uuid();
  final _scorer = RuleScorer();
  final Map<String, LostDog> _dogs = {};
  final Map<String, List<AppNotification>> _notifs = {};

  @override
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
  }) async {
    final dog = LostDog(
      id: _uuid.v4(),
      photoUrl: photoUrl,
      breed: breed,
      color: color,
      features: features,
      age: age,
      lostDate: lostDate,
      lostLat: lostLat,
      lostLng: lostLng,
      lostAddress: lostAddress,
      createdAt: DateTime.now(),
    );
    _dogs[dog.id] = dog;

    // 시연 연출: 매칭 계산 시간
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final ranked = _scorer.rank(dog, exampleNotices());
    final now = DateTime.now();
    _notifs[dog.id] = [
      for (var i = 0; i < ranked.length && i < 3; i++)
        AppNotification(
          id: _uuid.v4(),
          lostDogId: dog.id,
          noticeId: ranked[i].noticeId,
          title: i == 0 ? '새로운 유사 후보가 등록되었어요' : '유사 후보 공고가 추가되었어요',
          body:
              '${ranked[i].shelterName}에 ${ranked[i].color} ${ranked[i].breed} 공고가 올라왔어요. 유사도 ${(ranked[i].score.total * 100).round()}점',
          createdAt: now.subtract(Duration(minutes: i * 47)),
          read: i == 2,
        ),
    ];
    return dog;
  }

  @override
  Future<LostDog> getLostDog(String id) async {
    final d = _dogs[id];
    if (d == null) throw StateError('lost dog not found');
    return d;
  }

  @override
  Future<List<Candidate>> getCandidates(String lostDogId, {int limit = 20}) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final dog = await getLostDog(lostDogId);
    final ranked = _scorer.rank(dog, exampleNotices());
    return ranked.take(limit).toList();
  }

  @override
  Future<Candidate> getCandidateDetail(String lostDogId, String noticeId) async {
    final list = await getCandidates(lostDogId);
    return list.firstWhere((c) => c.noticeId == noticeId);
  }

  @override
  Future<List<AppNotification>> getNotifications(String lostDogId) async {
    return List.of(_notifs[lostDogId] ?? const []);
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    for (final list in _notifs.values) {
      for (var i = 0; i < list.length; i++) {
        if (list[i].id == notificationId) {
          final n = list[i];
          list[i] = AppNotification(
            id: n.id,
            lostDogId: n.lostDogId,
            noticeId: n.noticeId,
            title: n.title,
            body: n.body,
            createdAt: n.createdAt,
            read: true,
          );
        }
      }
    }
  }
}
