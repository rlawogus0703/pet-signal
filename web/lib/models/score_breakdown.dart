/// 규칙 점수 한 항목 (예: 품종 30/30점 · 일치 (포메라니안))
class RuleItem {
  final String key; // breed | color | region | features | date
  final String label; // 품종 | 색상 | 지역 | 특징 | 날짜
  final int points;
  final int max;
  final String reason;

  const RuleItem({required this.key, required this.label, required this.points, required this.max, required this.reason});

  double get fraction => max == 0 ? 0 : points / max;

  factory RuleItem.fromJson(Map<String, dynamic> j) => RuleItem(
        key: j['key'] as String? ?? '',
        label: j['label'] as String? ?? '',
        points: (j['points'] as num?)?.toInt() ?? 0,
        max: (j['max'] as num?)?.toInt() ?? 0,
        reason: j['reason'] as String? ?? '',
      );
}

/// 매칭 점수
///
/// 순위 기준 = 규칙 점수 100점 (김민재 앱과 같은 기준): 품종 30 · 색상 25 · 지역 20 · 특징 15 · 날짜 10.
/// 일치 근거를 합산한 점수이며 동일견일 확률이 아닙니다. total = points / 100.
/// 아래 0~1 필드(rule/text/image 등)는 예전 멀티모달 방식 호환용으로 남겨 두었습니다.
class ScoreBreakdown {
  static const defaultCaption = '일치 근거를 합산한 점수이며, 동일견일 확률이 아니에요.';
  static const defaultNote = '지역은 시군구 표기를 비교해요. 실제 거리와 사진 유사도는 계산하지 않아요. 구조 접수일은 실제 발견일과 다를 수 있어요.';

  // 규칙 점수 100점
  final int? points;
  final int maxPoints;
  final List<RuleItem> items;
  final String caption;
  final String note;
  // 규칙 항목
  final double breed;
  final double color;
  final double distance;
  final double date;
  final double features; // = textKeyword (예전 필드 호환)
  final double age;
  // 세 갈래 + 최종
  final double? rule;
  final double? text;
  final double? image;
  final double total;
  // 텍스트 세부
  final double? textKeyword;
  final double? textSemantic;
  final double? textAttribute;
  final String? textMethod;
  // 이미지 세부
  final String? imageMethod;
  final String? imageStatus; // ok | no_user_photo | no_notice_photo | fetch_failed

  const ScoreBreakdown({
    this.points,
    this.maxPoints = 100,
    this.items = const [],
    this.caption = defaultCaption,
    this.note = defaultNote,
    required this.breed,
    required this.color,
    required this.distance,
    required this.date,
    required this.features,
    required this.age,
    this.rule,
    this.image,
    this.text,
    required this.total,
    this.textKeyword,
    this.textSemantic,
    this.textAttribute,
    this.textMethod,
    this.imageMethod,
    this.imageStatus,
  });

  static double? _d(dynamic v) => (v as num?)?.toDouble();

  /// 화면에 보여줄 점수 (0~100). 예전 응답이면 total 로 대신합니다.
  int get displayPoints => points ?? (total * 100).round();

  RuleItem? item(String key) {
    for (final it in items) {
      if (it.key == key) return it;
    }
    return null;
  }

  factory ScoreBreakdown.fromJson(Map<String, dynamic> j) => ScoreBreakdown(
        points: (j['points'] as num?)?.toInt(),
        maxPoints: (j['max_points'] as num?)?.toInt() ?? 100,
        items: (j['items'] as List<dynamic>? ?? [])
            .map((e) => RuleItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        caption: j['caption'] as String? ?? defaultCaption,
        note: j['note'] as String? ?? defaultNote,
        breed: _d(j['breed']) ?? 0,
        color: _d(j['color']) ?? 0,
        distance: _d(j['distance']) ?? 0,
        date: _d(j['date']) ?? 0,
        features: _d(j['features']) ?? 0,
        age: _d(j['age']) ?? 0,
        rule: _d(j['rule']),
        image: _d(j['image']),
        text: _d(j['text']),
        total: _d(j['total']) ?? 0,
        textKeyword: _d(j['text_keyword']),
        textSemantic: _d(j['text_semantic']),
        textAttribute: _d(j['text_attribute']),
        textMethod: j['text_method'] as String?,
        imageMethod: j['image_method'] as String?,
        imageStatus: j['image_status'] as String?,
      );
}
