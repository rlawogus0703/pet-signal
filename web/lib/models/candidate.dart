import 'score_breakdown.dart';

/// 유사 후보 (동일 개체 단정 아님)
class Candidate {
  final String noticeId;
  final String noticeNo;
  final String? photoUrl;
  final String breed;
  final String color;
  final String? age;
  final String features;
  final DateTime foundDate;
  final double? foundLat;
  final double? foundLng;
  final String foundAddress;
  final String shelterName;
  final String shelterPhone;
  final String noticeUrl;
  final ScoreBreakdown score;
  final List<String> reasons;
  final int rank;

  Candidate({
    required this.noticeId,
    required this.noticeNo,
    this.photoUrl,
    required this.breed,
    required this.color,
    this.age,
    required this.features,
    required this.foundDate,
    this.foundLat,
    this.foundLng,
    required this.foundAddress,
    required this.shelterName,
    required this.shelterPhone,
    required this.noticeUrl,
    required this.score,
    required this.reasons,
    required this.rank,
  });

  factory Candidate.fromJson(Map<String, dynamic> j) => Candidate(
        noticeId: j['notice_id'] as String,
        noticeNo: j['notice_no'] as String? ?? '',
        photoUrl: j['photo_url'] as String?,
        breed: j['breed'] as String? ?? '',
        color: j['color'] as String? ?? '',
        age: j['age'] as String?,
        features: j['features'] as String? ?? '',
        foundDate: DateTime.parse(j['found_date'] as String),
        foundLat: (j['found_lat'] as num?)?.toDouble(),
        foundLng: (j['found_lng'] as num?)?.toDouble(),
        foundAddress: j['found_address'] as String? ?? '',
        shelterName: j['shelter_name'] as String? ?? '',
        shelterPhone: j['shelter_phone'] as String? ?? '',
        noticeUrl: j['notice_url'] as String? ?? '',
        score: ScoreBreakdown.fromJson(j['score'] as Map<String, dynamic>),
        reasons: (j['reasons'] as List<dynamic>? ?? []).map((e) => '$e').toList(),
        rank: j['rank'] as int? ?? 0,
      );
}
