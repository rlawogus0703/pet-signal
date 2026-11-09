import 'package:flutter/material.dart';

import '../models/candidate.dart';
import '../models/lost_dog.dart';
import '../utils/format.dart';
import 'normalizer.dart';
import 'scorer.dart';

class ScoreItem {
  const ScoreItem(this.label, this.icon, this.value, this.weight, {this.ai = false});
  final String label;
  final IconData icon;
  final double? value;
  final double weight;
  final bool ai;
}

List<ScoreItem> scoreItems(Candidate c) {
  final s = c.score;
  final w = RuleScorer.weights;
  return [
    ScoreItem('품종', Icons.pets_rounded, s.breed, w['breed']!),
    ScoreItem('색상', Icons.palette_outlined, s.color, w['color']!),
    ScoreItem('거리', Icons.place_outlined, s.distance, w['distance']!),
    ScoreItem('날짜', Icons.event_outlined, s.date, w['date']!),
    ScoreItem('특징', Icons.label_outline_rounded, s.features, w['features']!),
    ScoreItem('나이', Icons.cake_outlined, s.age, w['age']!),
    ScoreItem('이미지 유사도', Icons.image_search_rounded, s.image, w['image']!, ai: true),
    ScoreItem('텍스트 유사도', Icons.text_snippet_outlined, s.text, w['text']!, ai: true),
  ];
}

double? distanceKm(LostDog d, Candidate c) {
  if (c.foundLat == null || c.foundLng == null) return null;
  return RuleScorer.haversineKm(d.lostLat, d.lostLng, c.foundLat!, c.foundLng!);
}

int dayDiff(LostDog d, Candidate c) => c.foundDate.difference(d.lostDate).inDays;

class Explanation {
  const Explanation(this.icon, this.title, this.sentence, this.level);
  final IconData icon;
  final String title;
  final String sentence;

  /// 2: 강함, 1: 보통, 0: 약함
  final int level;
}

/// 항목별 점수를 사람이 읽기 쉬운 문장으로
List<Explanation> explain(LostDog d, Candidate c) {
  final out = <Explanation>[];
  final s = c.score;
  final nb1 = Normalizer.normBreed(d.breed), nb2 = Normalizer.normBreed(c.breed);

  if (s.breed >= 0.99) {
    out.add(Explanation(Icons.pets_rounded, '품종 일치',
        '등록한 품종 "${d.breed}"와 공고의 "${c.breed}"가 같은 품종으로 정규화되었어요.', 2));
  } else if (s.breed >= 0.5) {
    out.add(Explanation(Icons.pets_rounded, '품종 표기 차이 보정',
        '공고에는 "${c.breed}"로 적혀 있지만, 보호소에서 소형 견종을 믹스견으로 기록하는 경우가 많아 후보에서 빼지 않았어요.', 1));
  } else {
    out.add(Explanation(Icons.pets_rounded, '품종 다름', '"${d.breed}"와 "${c.breed}"는 다른 품종으로 분류돼요.', 0));
  }

  if (s.color >= 0.99) {
    out.add(Explanation(Icons.palette_outlined, '색상 일치', '털색 "${d.color}"와 "${c.color}"가 같은 색상군이에요.', 2));
  } else if (s.color >= 0.5) {
    out.add(Explanation(Icons.palette_outlined, '비슷한 색상',
        '"${d.color}"와 "${c.color}"는 표기는 다르지만 가까운 색상군으로 판단했어요. 조명·미용 상태에 따라 다르게 기록되기도 해요.', 1));
  } else {
    out.add(Explanation(Icons.palette_outlined, '색상 다름', '"${d.color}"와 "${c.color}"는 색상군이 달라요.', 0));
  }

  final km = distanceKm(d, c);
  if (km != null) {
    out.add(Explanation(Icons.place_outlined, '실종 위치와 ${km.toStringAsFixed(1)}km',
        km <= 5
            ? '실종 지점에서 걸어서 이동할 수 있는 거리에서 발견됐어요.'
            : km <= 20
                ? '실종 지점과 같은 생활권 안에서 발견됐어요.'
                : '실종 지점과 꽤 떨어진 곳에서 발견됐어요. 구조 후 이동했을 수도 있어요.',
        s.distance >= 0.7 ? 2 : (s.distance >= 0.4 ? 1 : 0)));
  }

  final dd = dayDiff(d, c);
  out.add(Explanation(
      Icons.event_outlined,
      dd >= 0 ? '실종 $dd일 후 발견' : '실종 ${-dd}일 전 발견',
      dd >= 0 && dd <= 7
          ? '실종일(${ymd(d.lostDate)}) 직후 구조된 공고라 시기가 잘 맞아요.'
          : dd < 0
              ? '실종일보다 먼저 올라온 공고라 가능성이 낮아요.'
              : '실종일(${ymd(d.lostDate)})과 시간 차이가 조금 있어요.',
      s.date >= 0.7 ? 2 : (s.date >= 0.4 ? 1 : 0)));

  if (s.features >= 0.15) {
    final ta = Normalizer.featureTokens(d.features).toSet();
    final tb = Normalizer.featureTokens(c.features).toSet();
    final common = ta.intersection(tb).toList();
    out.add(Explanation(
        Icons.label_outline_rounded,
        '특징 키워드 일치',
        common.isEmpty ? '설명 문구가 일부 겹쳐요.' : '공통 키워드: ${common.map((e) => '"$e"').join(', ')}',
        s.features >= 0.3 ? 2 : 1));
  }

  if (s.age >= 0.8) {
    out.add(Explanation(Icons.cake_outlined, '나이대 비슷', '${d.age ?? '-'} / ${c.age ?? '-'} 로 나이대가 비슷해요.', 2));
  }

  final img = s.image, txt = s.text;
  if (img != null || txt != null) {
    out.add(Explanation(
        Icons.auto_awesome_rounded,
        'AI 멀티모달 유사도',
        '사진 유사도 ${img == null ? '-' : pct(img)}점, 설명 문장 유사도 ${txt == null ? '-' : pct(txt)}점을 규칙 점수와 함께 융합했어요.',
        ((img ?? 0) + (txt ?? 0)) / 2 >= 0.6 ? 2 : 1));
  }
  if (nb1 != nb2 && nb2 == 'mix' && s.color >= 0.5) {
    out.insert(
        0,
        Explanation(Icons.lightbulb_outline_rounded, '일반 검색이라면 놓쳤을 후보',
            '"${d.color} ${d.breed}"로 검색하면 "${c.color} ${c.breed}" 공고는 나오지 않아요. 펫 시그널은 표기를 정규화해서 이 후보를 찾아냈어요.', 2));
  }
  return out;
}
