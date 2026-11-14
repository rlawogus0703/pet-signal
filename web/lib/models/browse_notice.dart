/// 로그인 없이 둘러보는 보호소 공고
class BrowseNotice {
  final String noticeId;
  final String noticeNo;
  final String? photoUrl;
  final String? photoUrl2;
  final String? photoProxyUrl;
  final String? photo2ProxyUrl;
  final String breed;
  final String color;
  final String? age;
  final String features;
  final String kindFull;
  final String sex;
  final String neuter;
  final String weight;
  final DateTime? foundDate;
  final double? foundLat;
  final double? foundLng;
  final String foundAddress;
  final double? distKm;
  final String shelterName;
  final String shelterPhone;
  final String shelterAddress;
  final String orgName;
  final String processState;
  final DateTime? noticeStart;
  final DateTime? noticeEnd;
  final String noticeUrl;
  final String source;

  const BrowseNotice({
    required this.noticeId,
    this.noticeNo = '',
    this.photoUrl,
    this.photoUrl2,
    this.photoProxyUrl,
    this.photo2ProxyUrl,
    this.breed = '',
    this.color = '',
    this.age,
    this.features = '',
    this.kindFull = '',
    this.sex = '',
    this.neuter = '',
    this.weight = '',
    this.foundDate,
    this.foundLat,
    this.foundLng,
    this.foundAddress = '',
    this.distKm,
    this.shelterName = '',
    this.shelterPhone = '',
    this.shelterAddress = '',
    this.orgName = '',
    this.processState = '',
    this.noticeStart,
    this.noticeEnd,
    this.noticeUrl = '',
    this.source = 'seed',
  });

  String? get displayPhotoUrl => photoProxyUrl ?? photoUrl;
  String? get displayPhotoFallback => photo2ProxyUrl ?? photoUrl2;

  static DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse('$v');

  static String? _abs(String? path, String? base) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http') || base == null) return path;
    return '$base$path';
  }

  static double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse('$v');
  }

  factory BrowseNotice.fromJson(Map<String, dynamic> j, {String? baseUrl}) {
    return BrowseNotice(
      noticeId: '${j['notice_id']}',
      noticeNo: (j['notice_no'] as String?) ?? '',
      photoUrl: j['photo_url'] as String?,
      photoUrl2: j['photo_url2'] as String?,
      photoProxyUrl: _abs(j['photo_proxy_url'] as String?, baseUrl),
      photo2ProxyUrl: _abs(j['photo2_proxy_url'] as String?, baseUrl),
      breed: (j['breed'] as String?) ?? '',
      color: (j['color'] as String?) ?? '',
      age: j['age'] as String?,
      features: (j['features'] as String?) ?? '',
      kindFull: (j['kind_full'] as String?) ?? '',
      sex: (j['sex'] as String?) ?? '',
      neuter: (j['neuter'] as String?) ?? '',
      weight: (j['weight'] as String?) ?? '',
      foundDate: _date(j['found_date']),
      foundLat: _num(j['found_lat']),
      foundLng: _num(j['found_lng']),
      foundAddress: (j['found_address'] as String?) ?? '',
      distKm: _num(j['dist_km']),
      shelterName: (j['shelter_name'] as String?) ?? '',
      shelterPhone: (j['shelter_phone'] as String?) ?? '',
      shelterAddress: (j['shelter_address'] as String?) ?? '',
      orgName: (j['org_name'] as String?) ?? '',
      processState: (j['process_state'] as String?) ?? '',
      noticeStart: _date(j['notice_start']),
      noticeEnd: _date(j['notice_end']),
      noticeUrl: (j['notice_url'] as String?) ?? '',
      source: (j['source'] as String?) ?? 'seed',
    );
  }
}

class NearbyPage {
  final double originLat;
  final double originLng;
  final String originLabel;
  final int total;
  final int page;
  final int pageSize;
  final List<BrowseNotice> items;

  const NearbyPage({
    required this.originLat,
    required this.originLng,
    required this.originLabel,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.items,
  });
}
