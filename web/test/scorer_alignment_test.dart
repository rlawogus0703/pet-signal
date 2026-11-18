import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_signal_web/matching/image_features.dart';
import 'package:pet_signal_web/matching/scorer.dart';
import 'package:pet_signal_web/models/lost_dog.dart';
import 'package:pet_signal_web/models/notice.dart';


void main() {
  final fx = jsonDecode(File('test/fixtures/scoring_cases.json').readAsStringSync()) as Map<String, dynamic>;
  final d = fx['dog'] as Map<String, dynamic>;
  final dog = LostDog(
    id: 'd',
    breed: d['breed'],
    color: d['color'],
    features: d['features'],
    age: d['age'],
    lostDate: DateTime.parse(d['lost_date']),
    lostLat: (d['lat'] as num).toDouble(),
    lostLng: (d['lng'] as num).toDouble(),
    lostAddress: d['address'] ?? '',
    createdAt: DateTime(2026, 11, 1),
  );

  test('규칙 점수 100점과 (예전) 규칙·텍스트·멀티모달 점수가 서버와 같다', () {
    final cases = fx['cases'] as List<dynamic>;
    for (var i = 0; i < cases.length; i++) {
      final c = cases[i] as Map<String, dynamic>;
      final n = c['notice'] as Map<String, dynamic>;
      final e = c['expected'] as Map<String, dynamic>;
      final notice = Notice(
        noticeId: 'n$i',
        noticeNo: '',
        breed: n['breed'],
        color: n['color'],
        age: n['age'],
        features: n['features'],
        foundDate: DateTime.parse(n['found_date']),
        foundLat: (n['lat'] as num?)?.toDouble(),
        foundLng: (n['lng'] as num?)?.toDouble(),
        foundAddress: n['address'] ?? '',
        shelterName: '',
        shelterPhone: '',
        noticeUrl: '',
        weight: n['weight'] ?? '',
      );
      final noPhoto = RuleScorer().scoreOne(dog, notice).score;
      void eq(String k, double? v) {
        final want = (e[k] as num?)?.toDouble();
        if (want == null) {
          expect(v, isNull, reason: 'case $i $k');
        } else {
          expect(v, closeTo(want, 1e-9), reason: 'case $i $k');
        }
      }

      eq('breed', noPhoto.breed);
      eq('color', noPhoto.color);
      eq('distance', noPhoto.distance);
      eq('date', noPhoto.date);
      eq('age', noPhoto.age);
      eq('rule', noPhoto.rule);
      eq('keyword', noPhoto.textKeyword);
      eq('semantic', noPhoto.textSemantic);
      eq('attribute', noPhoto.textAttribute);
      eq('text', noPhoto.text);

      expect(noPhoto.points, e['points'], reason: 'case $i points');
      expect([for (final it in noPhoto.items) it.points], e['point_items'], reason: 'case $i point_items');
      expect(noPhoto.total, closeTo((e['points'] as num) / 100, 1e-9));

      eq('final_no_photo', RuleScorer.finalScore(noPhoto.rule!, noPhoto.text, null));
      final img = (c['image'] as num?)?.toDouble();
      final withPhoto = RuleScorer().scoreOne(dog, notice, image: img, hasUserPhoto: true).score;
      eq('final_with_photo',
          RuleScorer.finalScore(withPhoto.rule!, withPhoto.text, img ?? RuleScorer.missingImageNeutral));
    }
  });

  test('경량 이미지 특징(히스토그램+dHash)이 서버와 같다', () {
    final im = fx['image'] as Map<String, dynamic>;
    Uint8List synth(int seed) {
      final b = Uint8List(80 * 80 * 4);
      var i = 0;
      for (var y = 0; y < 80; y++) {
        for (var x = 0; x < 80; x++) {
          b[i++] = (x * 3 + y * seed) % 256;
          b[i++] = (x * seed + y * 5 + 40) % 256;
          b[i++] = ((x ^ y) * (seed + 1)) % 256;
          b[i++] = 255;
        }
      }
      return b;
    }

    final fa = ImageFeatures.fromRgba(synth(im['seed_a']), 80, 80);
    final fb = ImageFeatures.fromRgba(synth(im['seed_b']), 80, 80);
    final want = (im['features_a'] as List).map((e) => (e as num).toDouble()).toList();
    for (var i = 0; i < 128; i++) {
      expect(fa[i], closeTo(want[i], 1e-12), reason: 'feature $i');
    }
    expect(ImageFeatures.similarity(fa, fb), closeTo((im['similarity'] as num).toDouble(), 1e-12));
    expect(ImageFeatures.similarity(fa, fa), closeTo(1.0, 1e-12));
  });
}
