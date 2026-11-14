/// 항목별·갈래별·최종 유사도 점수 (0~1)
///
/// 교수님 피드백 구성도: 규칙(rule) · 텍스트(text) · 이미지(image) → 멀티모달 최종(total)
class ScoreBreakdown {
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

  factory ScoreBreakdown.fromJson(Map<String, dynamic> j) => ScoreBreakdown(
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
