/// 항목별·총 유사도 점수 (0~1)
class ScoreBreakdown {
  final double breed;
  final double color;
  final double distance;
  final double date;
  final double features;
  final double age;
  final double? image;
  final double? text;
  final double total;

  const ScoreBreakdown({
    required this.breed,
    required this.color,
    required this.distance,
    required this.date,
    required this.features,
    required this.age,
    this.image,
    this.text,
    required this.total,
  });

  factory ScoreBreakdown.fromJson(Map<String, dynamic> j) => ScoreBreakdown(
        breed: (j['breed'] as num?)?.toDouble() ?? 0,
        color: (j['color'] as num?)?.toDouble() ?? 0,
        distance: (j['distance'] as num?)?.toDouble() ?? 0,
        date: (j['date'] as num?)?.toDouble() ?? 0,
        features: (j['features'] as num?)?.toDouble() ?? 0,
        age: (j['age'] as num?)?.toDouble() ?? 0,
        image: (j['image'] as num?)?.toDouble(),
        text: (j['text'] as num?)?.toDouble(),
        total: (j['total'] as num?)?.toDouble() ?? 0,
      );
}
