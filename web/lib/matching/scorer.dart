import 'dart:math';
import '../models/candidate.dart';
import '../models/lost_dog.dart';
import '../models/notice.dart';
import '../models/score_breakdown.dart';
import 'normalizer.dart';

/// 규칙 기반 유사도 스코어러 (웹 오프라인 데모용)
class RuleScorer {
  static const weights = <String, double>{
    'breed': 0.18,
    'color': 0.15,
    'distance': 0.18,
    'date': 0.12,
    'features': 0.12,
    'age': 0.10,
    'image': 0.08, // 웹 mock에서는 의사 점수
    'text': 0.07,
  };

  List<Candidate> rank(LostDog dog, List<Notice> notices) {
    final scored = notices.map((n) => _scoreOne(dog, n)).toList();
    scored.sort((a, b) => b.score.total.compareTo(a.score.total));
    return [
      for (var i = 0; i < scored.length; i++)
        Candidate(
          noticeId: scored[i].noticeId,
          noticeNo: scored[i].noticeNo,
          photoUrl: scored[i].photoUrl,
          breed: scored[i].breed,
          color: scored[i].color,
          age: scored[i].age,
          features: scored[i].features,
          foundDate: scored[i].foundDate,
          foundLat: scored[i].foundLat,
          foundLng: scored[i].foundLng,
          foundAddress: scored[i].foundAddress,
          shelterName: scored[i].shelterName,
          shelterPhone: scored[i].shelterPhone,
          noticeUrl: scored[i].noticeUrl,
          score: scored[i].score,
          reasons: scored[i].reasons,
          rank: i + 1,
        ),
    ];
  }

  Candidate _scoreOne(LostDog dog, Notice n) {
    final breed = _breedScore(dog.breed, n.breed);
    final color = _colorScore(dog.color, n.color);
    final distKm = (n.foundLat != null && n.foundLng != null)
        ? haversineKm(dog.lostLat, dog.lostLng, n.foundLat!, n.foundLng!)
        : 50.0;
    final distance = _distanceScore(distKm);
    final dayDiff = dog.lostDate.difference(n.foundDate).inDays.abs();
    final date = _dateScore(dayDiff);
    final features = _featureScore(dog.features, n.features);
    final age = _ageScore(dog.age, n.age);
    // 시연용 의사 이미지/텍스트 점수 (규칙 기반 근사)
    final image = ((color + breed) / 2 * 0.7 + features * 0.3).clamp(0.0, 1.0);
    final text = ((features * 0.6) + (breed * 0.2) + (color * 0.2)).clamp(0.0, 1.0);

    final total = _fuse({
      'breed': breed,
      'color': color,
      'distance': distance,
      'date': date,
      'features': features,
      'age': age,
      'image': image,
      'text': text,
    });

    final reasons = <String>[];
    if (breed >= 0.99) {
      reasons.add('품종 일치 (${dog.breed} / ${n.breed})');
    } else if (breed >= 0.5) {
      reasons.add('품종 유사 (${dog.breed} / ${n.breed})');
    }
    if (color >= 0.99) {
      reasons.add('색상 일치 (${dog.color} / ${n.color})');
    } else if (color >= 0.5) {
      reasons.add('색상 유사 (${dog.color} / ${n.color})');
    }
    if (distance >= 0.5) {
      reasons.add('실종 지점과 약 ${distKm.toStringAsFixed(1)}km');
    }
    if (date >= 0.5) reasons.add('날짜 차이 $dayDiff일');
    if (age >= 0.5) reasons.add('나이 유사 (${dog.age ?? "-"} / ${n.age ?? "-"})');
    if (features >= 0.3) reasons.add('특징 키워드 일부 일치');
    reasons.add('사진 유사도 ${image.toStringAsFixed(2)}');
    reasons.add('설명 텍스트 유사도 ${text.toStringAsFixed(2)}');
    if (reasons.isEmpty) reasons.add('일부 항목이 부분 일치합니다');

    return Candidate(
      noticeId: n.noticeId,
      noticeNo: n.noticeNo,
      photoUrl: n.photoUrl,
      breed: n.breed,
      color: n.color,
      age: n.age,
      features: n.features,
      foundDate: n.foundDate,
      foundLat: n.foundLat,
      foundLng: n.foundLng,
      foundAddress: n.foundAddress,
      shelterName: n.shelterName,
      shelterPhone: n.shelterPhone,
      noticeUrl: n.noticeUrl,
      score: ScoreBreakdown(
        breed: breed,
        color: color,
        distance: distance,
        date: date,
        features: features,
        age: age,
        image: image,
        text: text,
        total: total,
      ),
      reasons: reasons,
      rank: 0,
    );
  }

  double _fuse(Map<String, double> parts) {
    var s = 0.0;
    var wsum = 0.0;
    parts.forEach((k, v) {
      final w = weights[k] ?? 0;
      s += w * v;
      wsum += w;
    });
    return wsum == 0 ? 0 : (s / wsum).clamp(0.0, 1.0);
  }

  double _breedScore(String a, String b) {
    final na = Normalizer.normBreed(a);
    final nb = Normalizer.normBreed(b);
    if (na == nb) return 1.0;
    if (na == 'mix' || nb == 'mix') return 0.6;
    return 0.0;
  }

  double _colorScore(String a, String b) {
    final na = Normalizer.normColor(a);
    final nb = Normalizer.normColor(b);
    if (na == nb) return 1.0;
    if (Normalizer.colorNeighbors[na]?.contains(nb) == true) return 0.85;
    return 0.0;
  }

  double _distanceScore(double km) {
    if (km <= 1) return 1.0;
    if (km <= 5) return 0.9;
    if (km <= 15) return 0.7;
    if (km <= 30) return 0.45;
    if (km <= 50) return 0.25;
    return 0.05;
  }

  double _dateScore(int days) {
    if (days <= 1) return 1.0;
    if (days <= 3) return 0.9;
    if (days <= 7) return 0.7;
    if (days <= 14) return 0.45;
    if (days <= 30) return 0.25;
    return 0.05;
  }

  double _featureScore(String a, String b) {
    final ta = Normalizer.featureTokens(a).toSet();
    final tb = Normalizer.featureTokens(b).toSet();
    if (ta.isEmpty || tb.isEmpty) return 0.1;
    final inter = ta.intersection(tb).length;
    final uni = ta.union(tb).length;
    return uni == 0 ? 0.0 : inter / uni;
  }

  double _ageScore(String? a, String? b) {
    final ya = Normalizer.parseAgeYears(a);
    final yb = Normalizer.parseAgeYears(b);
    if (ya == null || yb == null) return 0.3;
    final diff = (ya - yb).abs();
    if (diff <= 0.5) return 1.0;
    if (diff <= 1.5) return 0.8;
    if (diff <= 3) return 0.5;
    return 0.15;
  }

  static double haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return 2 * r * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _rad(double d) => d * pi / 180.0;
}
