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
  // v2: 공고 상세 + 사진
  final String source; // seed | animal_api
  final String? photoUrl2;
  final String? photoProxyUrl; // 서버 경유 사진 (절대 주소로 바꿔서 저장)
  final String? photo2ProxyUrl;
  final String kindFull;
  final String sex;
  final String neuter;
  final String weight;
  final String shelterAddress;
  final String orgName;
  final String processState;
  final DateTime? noticeStart;
  final DateTime? noticeEnd;
  final List<String> commonKeywords;
  final List<String> matchedAttributes;

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
    this.source = 'seed',
    this.photoUrl2,
    this.photoProxyUrl,
    this.photo2ProxyUrl,
    this.kindFull = '',
    this.sex = '',
    this.neuter = '',
    this.weight = '',
    this.shelterAddress = '',
    this.orgName = '',
    this.processState = '',
    this.noticeStart,
    this.noticeEnd,
    this.commonKeywords = const [],
    this.matchedAttributes = const [],
  });

  /// 화면에 띄울 공고 사진 주소 (서버 경유 우선 — 브라우저 CORS 문제 회피)
  String? get displayPhotoUrl => photoProxyUrl ?? photoUrl;

  /// 사용자 사진은 있는데 공고 사진이 없어 이미지 점수를 못 낸 경우
  bool get imageMissing => score.image == null && score.imageStatus != 'no_user_photo';

  static DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse('$v');

  static String? _abs(String? path, String? base) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http') || base == null) return path;
    return '$base$path';
  }

  factory Candidate.fromJson(Map<String, dynamic> j, {String? baseUrl}) {
    final start = _date(j['notice_start']);
    return Candidate(
      noticeId: j['notice_id'] as String,
      noticeNo: j['notice_no'] as String? ?? '',
      photoUrl: j['photo_url'] as String?,
      breed: j['breed'] as String? ?? '',
      color: j['color'] as String? ?? '',
      age: j['age'] as String?,
      features: j['features'] as String? ?? '',
      foundDate: _date(j['found_date']) ?? start ?? DateTime.now(),
      foundLat: (j['found_lat'] as num?)?.toDouble(),
      foundLng: (j['found_lng'] as num?)?.toDouble(),
      foundAddress: j['found_address'] as String? ?? '',
      shelterName: j['shelter_name'] as String? ?? '',
      shelterPhone: j['shelter_phone'] as String? ?? '',
      noticeUrl: j['notice_url'] as String? ?? '',
      score: ScoreBreakdown.fromJson(j['score'] as Map<String, dynamic>),
      reasons: (j['reasons'] as List<dynamic>? ?? []).map((e) => '$e').toList(),
      rank: j['rank'] as int? ?? 0,
      source: j['source'] as String? ?? 'seed',
      photoUrl2: j['photo_url2'] as String?,
      photoProxyUrl: _abs(j['photo_proxy_url'] as String?, baseUrl),
      photo2ProxyUrl: _abs(j['photo2_proxy_url'] as String?, baseUrl),
      kindFull: j['kind_full'] as String? ?? '',
      sex: j['sex'] as String? ?? '',
      neuter: j['neuter'] as String? ?? '',
      weight: j['weight'] as String? ?? '',
      shelterAddress: j['shelter_address'] as String? ?? '',
      orgName: j['org_name'] as String? ?? '',
      processState: j['process_state'] as String? ?? '',
      noticeStart: start,
      noticeEnd: _date(j['notice_end']),
      commonKeywords: (j['common_keywords'] as List<dynamic>? ?? []).map((e) => '$e').toList(),
      matchedAttributes: (j['matched_attributes'] as List<dynamic>? ?? []).map((e) => '$e').toList(),
    );
  }

  Candidate withRank(int r) => Candidate(
        noticeId: noticeId,
        noticeNo: noticeNo,
        photoUrl: photoUrl,
        breed: breed,
        color: color,
        age: age,
        features: features,
        foundDate: foundDate,
        foundLat: foundLat,
        foundLng: foundLng,
        foundAddress: foundAddress,
        shelterName: shelterName,
        shelterPhone: shelterPhone,
        noticeUrl: noticeUrl,
        score: score,
        reasons: reasons,
        rank: r,
        source: source,
        photoUrl2: photoUrl2,
        photoProxyUrl: photoProxyUrl,
        photo2ProxyUrl: photo2ProxyUrl,
        kindFull: kindFull,
        sex: sex,
        neuter: neuter,
        weight: weight,
        shelterAddress: shelterAddress,
        orgName: orgName,
        processState: processState,
        noticeStart: noticeStart,
        noticeEnd: noticeEnd,
        commonKeywords: commonKeywords,
        matchedAttributes: matchedAttributes,
      );
}
