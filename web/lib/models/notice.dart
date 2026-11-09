/// 보호소 공고 (예시/수집 데이터)
class Notice {
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

  const Notice({
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
  });
}
