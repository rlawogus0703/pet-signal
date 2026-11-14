import 'package:flutter_test/flutter_test.dart';
import 'package:pet_signal_web/data/mock_data.dart';
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

  test('논문 예시: 흰색 말티즈 → 크림색 믹스견이 상위 3위 안 (사진 없이)', () {
    final ranked = RuleScorer().rank(dog, exampleNotices());
    for (final c in ranked) {
      // ignore: avoid_print
      print('${c.rank}. ${c.color} ${c.breed} ${c.foundAddress} ${(c.score.total * 100).round()} '
          '(규칙 ${(c.score.rule! * 100).round()} 텍스트 ${(c.score.text! * 100).round()})');
    }
    final idx = ranked.indexWhere((c) => c.noticeId == 'N20261102001');
    expect(idx, lessThan(3));
    expect(ranked.first.score.image, isNull);
    expect(ranked.first.score.imageStatus, 'no_user_photo');
  });

  test('사진 점수가 들어가면 이미지 갈래가 최종 점수에 반영된다', () {
    final scores = {for (final n in exampleNotices()) n.noticeId: 0.2};
    scores['N20261102001'] = 0.9;
    final ranked = RuleScorer().rank(dog, exampleNotices(), imageScores: scores, hasUserPhoto: true);
    expect(ranked.first.noticeId, 'N20261102001');
    expect(ranked.first.score.image, 0.9);
    expect(ranked.first.reasons.any((r) => r.contains('사진 유사도 0.90')), isTrue);
  });
}
