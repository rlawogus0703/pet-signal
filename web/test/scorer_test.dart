import 'package:flutter_test/flutter_test.dart';
import 'package:pet_signal_web/data/mock_data.dart';
import 'package:pet_signal_web/matching/rule_points.dart';
import 'package:pet_signal_web/matching/scorer.dart';
import 'package:pet_signal_web/models/lost_dog.dart';
import 'package:pet_signal_web/state/example_dog.dart';

void main() {
  final dog = LostDog(
    id: 'd',
    breed: ExampleDog.breed,
    color: ExampleDog.color,
    features: ExampleDog.features,
    age: ExampleDog.age,
    lostDate: ExampleDog.lostDate,
    lostLat: ExampleDog.lat,
    lostLng: ExampleDog.lng,
    lostAddress: ExampleDog.address,
    createdAt: DateTime(2026, 11, 1),
  );

  test('규칙 점수 100점으로 순위: 품종 30 · 색상 25 · 지역 20 · 특징 15 · 날짜 10', () {
    final ranked = RuleScorer().rank(dog, exampleNotices());
    for (final c in ranked) {
      // ignore: avoid_print
      print('${c.rank}. ${c.color} ${c.breed} ${c.foundAddress} ${c.score.displayPoints}/100 '
          '${c.score.items.map((e) => '${e.label}${e.points}').join(' ')}');
    }
    for (final c in ranked) {
      expect(c.score.items.map((e) => e.key).toList(), ['breed', 'color', 'region', 'features', 'date']);
      expect(c.score.items.map((e) => e.max).toList(), [30, 25, 20, 15, 10]);
      expect(c.score.points, c.score.items.fold<int>(0, (s, e) => s + e.points));
      expect(c.score.total, closeTo(c.score.points! / 100, 1e-9));
    }
    for (var i = 1; i < ranked.length; i++) {
      expect(ranked[i - 1].score.points!, greaterThanOrEqualTo(ranked[i].score.points!));
    }
    // 흰색 말티즈 + 오산시 공고는 품종·색상·지역을 모두 받음
    final top = ranked.first;
    expect(top.score.item('breed')!.points, 30);
    expect(top.score.item('color')!.points, 25);
  });

  test('사진 유사도는 순위에 쓰지 않는다', () {
    final scores = {for (final n in exampleNotices()) n.noticeId: 0.2};
    scores['N20261102001'] = 0.9;
    final a = RuleScorer().rank(dog, exampleNotices());
    final b = RuleScorer().rank(dog, exampleNotices(), imageScores: scores, hasUserPhoto: true);
    expect(b.map((c) => c.noticeId).toList(), a.map((c) => c.noticeId).toList());
  });

  test('시군구 표기 비교', () {
    expect(RulePoints.regionKey('경기도 오산시 양산동 (한신대학교 인근)'), '경기 오산시');
    expect(RulePoints.regionKey('서울특별시 강남구'), '서울 강남구');
    expect(RulePoints.regionKey('경기도 수원시 권선구 세류동'), '경기 수원시');
    expect(RulePoints.regionKey('상적동 96-7'), isNull);
  });
}
