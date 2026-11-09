import 'package:flutter_test/flutter_test.dart';
import 'package:pet_signal_web/data/mock_data.dart';
import 'package:pet_signal_web/matching/scorer.dart';
import 'package:pet_signal_web/models/lost_dog.dart';
import 'package:pet_signal_web/state/demo.dart';

void main() {
  test('논문 예시: 흰색 말티즈 → 크림색 믹스견이 상위 3위 안', () {
    final dog = LostDog(
      id: 'd',
      breed: DemoDog.breed,
      color: DemoDog.color,
      features: DemoDog.features,
      age: DemoDog.age,
      lostDate: DemoDog.lostDate,
      lostLat: DemoDog.lat,
      lostLng: DemoDog.lng,
      lostAddress: DemoDog.address,
      createdAt: DateTime(2026, 11, 1),
    );
    final ranked = RuleScorer().rank(dog, exampleNotices());
    for (final c in ranked) {
      // ignore: avoid_print
      print('${c.rank}. ${c.color} ${c.breed} ${c.foundAddress} ${(c.score.total * 100).round()}');
    }
    final idx = ranked.indexWhere((c) => c.noticeId == 'N20261102001');
    expect(idx, lessThan(3));
  });
}
