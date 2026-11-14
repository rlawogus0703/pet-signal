import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../matching/image_features.dart';
import '../matching/scorer.dart';
import '../models/app_notification.dart';
import '../models/candidate.dart';
import '../models/browse_notice.dart';
import '../models/lost_dog.dart';
import '../models/notice.dart';
import '../matching/normalizer.dart';
import 'mock_data.dart';
import 'options.dart';
import 'repository.dart';

/// 오프라인 시연용: 예시 공고 + Dart 멀티모달 스코어러 (서버와 같은 공식)
/// 사진 유사도는 번들 사진(assets/dogs)과 업로드 사진의 경량 특징으로 계산합니다.
class MockRepository implements PetSignalRepository {
  final _uuid = const Uuid();
  final _scorer = RuleScorer();
  final Map<String, LostDog> _dogs = {};
  final Map<String, List<AppNotification>> _notifs = {};
  final Map<String, List<double>?> _dogFeatures = {};

  Future<Map<String, double?>?> _imageScores(String dogId) async {
    final f = _dogFeatures[dogId];
    if (f == null) return null;
    final out = <String, double?>{};
    for (final n in exampleNotices()) {
      final asset = noticePhotoAssets[n.noticeId];
      final nf = asset == null ? null : await ImageFeatures.fromAsset(asset);
      out[n.noticeId] = nf == null ? null : ImageFeatures.similarity(f, nf);
    }
    return out;
  }

  Future<List<Candidate>> _rank(LostDog dog) async {
    final scores = await _imageScores(dog.id);
    return _scorer.rank(dog, exampleNotices(), imageScores: scores, hasUserPhoto: scores != null);
  }

  @override
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
    if (photoBytes != null) _dogFeatures[dog.id] = await ImageFeatures.fromBytes(photoBytes);

    // 시연 연출: 매칭 계산 시간
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final ranked = await _rank(dog);
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
    final ranked = await _rank(dog);
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


  BrowseNotice _fromExample(Notice n, {double? distKm}) {
    final asset = noticePhotoAssets[n.noticeId];
    return BrowseNotice(
      noticeId: n.noticeId,
      noticeNo: n.noticeNo,
      photoUrl: asset,
      breed: n.breed,
      color: n.color,
      age: n.age,
      features: n.features,
      foundDate: n.foundDate,
      foundLat: n.foundLat,
      foundLng: n.foundLng,
      foundAddress: n.foundAddress,
      distKm: distKm,
      shelterName: n.shelterName,
      shelterPhone: n.shelterPhone,
      shelterAddress: n.shelterAddress,
      noticeStart: n.noticeStart,
      noticeEnd: n.noticeEnd,
      noticeUrl: n.noticeUrl,
      weight: n.weight,
      source: 'seed',
    );
  }

  @override
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
  }) async {
    var oLat = lat;
    var oLng = lng;
    var label = '현재 위치';
    if (oLat == null || oLng == null) {
      Region? r;
      final raw = (region ?? '').trim();
      if (raw.isNotEmpty) {
        for (final e in regions) {
          if (e.label == raw || e.sido == raw) { r = e; break; }
        }
      }
      r ??= regions.firstWhere((e) => e.sido.startsWith('서울'), orElse: () => regions.first);
      oLat = r.lat;
      oLng = r.lng;
      label = r.label;
    }
    final now = DateTime.now();
    final cutoff = days == null ? null : now.subtract(Duration(days: days));
    final rows = <BrowseNotice>[];
    for (final n in exampleNotices()) {
      if (kind != null && kind.trim().isNotEmpty) {
        final q = Normalizer.normBreed(kind);
        if (q != Normalizer.normBreed(n.breed) && !n.breed.contains(kind.trim())) continue;
      }
      if (color != null && color.trim().isNotEmpty) {
        final q = Normalizer.normColor(color);
        if (q != Normalizer.normColor(n.color) && !n.color.contains(color.trim())) continue;
      }
      if (cutoff != null && n.foundDate.isBefore(DateTime(cutoff.year, cutoff.month, cutoff.day))) continue;
      double? dist;
      if (n.foundLat != null && n.foundLng != null) {
        dist = RuleScorer.haversineKm(oLat, oLng, n.foundLat!, n.foundLng!);
      }
      if (radius != null && radius > 0 && (dist == null || dist > radius)) continue;
      rows.add(_fromExample(n, distKm: dist == null ? null : double.parse(dist.toStringAsFixed(2))));
    }
    rows.sort((a, b) {
      if (a.distKm == null && b.distKm == null) return a.noticeId.compareTo(b.noticeId);
      if (a.distKm == null) return 1;
      if (b.distKm == null) return -1;
      return a.distKm!.compareTo(b.distKm!);
    });
    final total = rows.length;
    final start = ((page < 1 ? 1 : page) - 1) * pageSize;
    final items = start >= rows.length ? <BrowseNotice>[] : rows.sublist(start, start + pageSize > rows.length ? rows.length : start + pageSize);
    return NearbyPage(originLat: oLat, originLng: oLng, originLabel: label, total: total, page: page, pageSize: pageSize, items: items);
  }

  @override
  Future<BrowseNotice> getNotice(String noticeId) async {
    final n = exampleNotices().firstWhere((e) => e.noticeId == noticeId);
    return _fromExample(n);
  }
}
