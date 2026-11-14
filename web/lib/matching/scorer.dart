import 'dart:math';

import '../models/candidate.dart';
import '../models/lost_dog.dart';
import '../models/notice.dart';
import '../models/score_breakdown.dart';
import 'normalizer.dart';
import 'text_similarity.dart';

/// 멀티모달 유사도 스코어러 (웹 오프라인 데모용)
///
/// 서버(backend/app/services/matcher.py + app/ai/fusion.py)와 같은 공식·가중치입니다.
///   rule  = 품종 0.25 · 색상 0.25 · 거리 0.25 · 날짜 0.15 · 나이 0.10
///   text  = 키워드 0.4 · 문장 의미 0.4 · 속성/성향 0.2
///   image = 사진 특징 유사도 (색상 히스토그램 + dHash)
///   final = rule 0.45 + text 0.25 + image 0.30
/// 사용자 사진이 없으면 image 는 빼고 다시 나누고, 공고 사진만 없으면 중립값 0.40 을 넣습니다.
/// (backend/tests 의 기준값 web/test/fixtures/scoring_cases.json 으로 서버와 일치 여부를 테스트합니다)
class RuleScorer {
  static const ruleWeights = <String, double>{
    'breed': 0.25,
    'color': 0.25,
    'distance': 0.25,
    'date': 0.15,
    'age': 0.10,
  };
  static const modalWeights = <String, double>{'rule': 0.45, 'text': 0.25, 'image': 0.30};
  static const missingImageNeutral = 0.40;

  /// 예전 화면 호환용: 항목별 가중치를 한 표로
  static final weights = <String, double>{
    for (final e in ruleWeights.entries) e.key: e.value * modalWeights['rule']!,
    'text': modalWeights['text']!,
    'image': modalWeights['image']!,
  };

  /// [imageScores]: 공고 ID → 사진 유사도 (사용자 사진이 있을 때만, 공고 사진 없으면 null)
  List<Candidate> rank(LostDog dog, List<Notice> notices,
      {Map<String, double?>? imageScores, bool hasUserPhoto = false}) {
    final scored = [
      for (final n in notices)
        scoreOne(dog, n, image: imageScores?[n.noticeId], hasUserPhoto: hasUserPhoto && imageScores != null)
    ];
    scored.sort((a, b) => b.score.total.compareTo(a.score.total));
    return [for (var i = 0; i < scored.length; i++) scored[i].withRank(i + 1)];
  }

  static double fuse(Map<String, double?> parts, Map<String, double> w) {
    var s = 0.0, ws = 0.0;
    w.forEach((k, weight) {
      final v = parts[k];
      if (v == null) return;
      s += weight * v;
      ws += weight;
    });
    return ws == 0 ? 0.0 : (s / ws).clamp(0.0, 1.0);
  }

  static double finalScore(double rule, double? text, double? image) =>
      fuse({'rule': rule, 'text': text, 'image': image}, modalWeights);

  Candidate scoreOne(LostDog dog, Notice n, {double? image, bool hasUserPhoto = false}) {
    final breed = breedScore(dog.breed, n.breed);
    final color = colorScore(dog.color, n.color);
    final distKm = (n.foundLat != null && n.foundLng != null)
        ? haversineKm(dog.lostLat, dog.lostLng, n.foundLat!, n.foundLng!)
        : 50.0;
    final distance = distanceScore(distKm);
    final dayDiff = n.foundDate.difference(dog.lostDate).inDays;
    final date = signedDateScore(dayDiff);
    final age = ageScore(dog.age, n.age);
    final rule = fuse({'breed': breed, 'color': color, 'distance': distance, 'date': date, 'age': age}, ruleWeights);

    final tr = TextSimilarity.compare(
      dogFeatures: dog.features,
      dogSentence: TextSimilarity.describe(dog.breed, dog.color, dog.age, dog.features),
      noticeFeatures: n.features,
      noticeSentence: TextSimilarity.describe(n.breed, n.color, n.age, n.features),
      noticeWeight: n.weight.isEmpty ? null : n.weight,
    );

    final img = hasUserPhoto ? image : null;
    final status = img != null ? 'ok' : (hasUserPhoto ? 'no_notice_photo' : 'no_user_photo');
    final total = finalScore(rule, tr.score, img ?? (hasUserPhoto ? missingImageNeutral : null));

    String f2(double v) => v.toStringAsFixed(2);
    final reasons = <String>[];
    if (breed >= 0.99) {
      reasons.add('품종 일치 (${dog.breed} ↔ ${n.breed})');
    } else if (breed >= 0.5) {
      reasons.add('품종 유사 (${dog.breed} ↔ ${n.breed})');
    }
    if (color >= 0.99) {
      reasons.add('색상 일치 (${dog.color} ↔ ${n.color})');
    } else if (color >= 0.5) {
      reasons.add('색상 유사 (${dog.color} ↔ ${n.color})');
    }
    if (distance >= 0.5) reasons.add('실종 지점과 약 ${distKm.toStringAsFixed(1)}km');
    if (date >= 0.5) reasons.add('날짜 차이 ${dayDiff.abs()}일');
    if (age >= 0.5) reasons.add('나이 유사 (${dog.age ?? '-'} ↔ ${n.age ?? '-'})');
    if (tr.commonKeywords.isNotEmpty) reasons.add('공통 특징 키워드: ${tr.commonKeywords.take(5).join(', ')}');
    if (tr.matchedAttributes.isNotEmpty) reasons.add('문장 속성 일치: ${tr.matchedAttributes.join(', ')}');
    reasons.add('설명 텍스트 유사도 ${f2(tr.score)} (키워드 ${f2(tr.keyword)} · 문장 의미 ${f2(tr.semantic)} · 속성 '
        '${tr.attribute == null ? '-' : f2(tr.attribute!)})');
    if (img != null) {
      reasons.add('사진 유사도 ${f2(img)}');
    } else if (status == 'no_user_photo') {
      reasons.add('사진 미등록: 이미지 점수 제외');
    } else {
      reasons.add('공고 사진이 없어 이미지 점수는 중립값 ${f2(missingImageNeutral)} 적용');
    }
    reasons.add('멀티모달 최종 ${f2(total)} (규칙 ${f2(rule)} · 텍스트 ${f2(tr.score)} · 이미지 ${img == null ? '-' : f2(img)})');

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
      shelterAddress: n.shelterAddress,
      noticeStart: n.noticeStart,
      noticeEnd: n.noticeEnd,
      weight: n.weight,
      score: ScoreBreakdown(
        breed: breed,
        color: color,
        distance: distance,
        date: date,
        features: tr.keyword,
        age: age,
        rule: rule,
        text: tr.score,
        image: img,
        total: total,
        textKeyword: tr.keyword,
        textSemantic: tr.semantic,
        textAttribute: tr.attribute,
        textMethod: 'char-ngram',
        imageMethod: img != null ? 'color-hist+dhash' : null,
        imageStatus: status,
      ),
      reasons: reasons,
      rank: 0,
      commonKeywords: tr.commonKeywords,
      matchedAttributes: tr.matchedAttributes,
    );
  }

  static double breedScore(String a, String b) {
    final na = Normalizer.normBreed(a);
    final nb = Normalizer.normBreed(b);
    if (na == nb) return 1.0;
    if (na == 'mix' || nb == 'mix') return 0.6;
    return 0.0;
  }

  /// 색상 집합 비교: 같음 1.0 · 일부 공유 0.9 · 이웃 색 0.85 · 다름 0
  static double colorScore(String a, String b) {
    final ca = Normalizer.colorSet(a), cb = Normalizer.colorSet(b);
    if (ca.isEmpty || cb.isEmpty) {
      final ta = a.trim(), tb = b.trim();
      return (ta.isNotEmpty && ta == tb) ? 1.0 : 0.0;
    }
    final sa = ca.toSet(), sb = cb.toSet();
    if (sa.length == sb.length && sa.containsAll(sb)) return 1.0;
    if (sa.intersection(sb).isNotEmpty) return 0.9;
    for (final x in ca) {
      for (final y in cb) {
        if (Normalizer.colorNeighbors[x]?.contains(y) == true) return 0.85;
      }
    }
    return 0.0;
  }

  static double distanceScore(double km) {
    if (km <= 1) return 1.0;
    if (km <= 5) return 0.9;
    if (km <= 15) return 0.7;
    if (km <= 30) return 0.45;
    if (km <= 50) return 0.25;
    return 0.05;
  }

  static double dateScore(int days) {
    if (days <= 1) return 1.0;
    if (days <= 3) return 0.9;
    if (days <= 7) return 0.7;
    if (days <= 14) return 0.45;
    if (days <= 30) return 0.25;
    return 0.05;
  }

  /// dayDiff = 발견일 - 실종일. 실종 2일 이상 전에 발견된 공고는 낮게.
  static double signedDateScore(int dayDiff) => dayDiff < -1 ? 0.1 : dateScore(dayDiff.abs());

  static double ageScore(String? a, String? b) {
    final ya = Normalizer.parseAgeYears(a);
    final yb = Normalizer.parseAgeYears(b);
    if (ya == null || yb == null) return 0.3;
    final diff = (ya - yb).abs();
    if (diff <= 0.5) return 1.0;
    if (diff <= 1.5) return 0.8;
    if (diff <= 3) return 0.5;
    return 0.15;
  }

  /// 서버와 같은 하버사인 공식
  static double haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    const p = pi / 180.0;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 2 * r * asin(sqrt(a));
  }
}
