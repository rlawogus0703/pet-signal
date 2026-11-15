import '../models/score_breakdown.dart';
import 'normalizer.dart';
import 'text_similarity.dart';

/// 규칙 점수 100점 (김민재 앱 · 서버 backend/app/services/rule_points.py 와 같은 기준)
///
///   품종 30 · 색상 25 · 지역 20 · 특징 15 · 날짜 10 = 100점
/// 일치 근거를 합산한 점수이며, 동일견일 확률이 아닙니다.
class RulePoints {
  static const points = <String, int>{'breed': 30, 'color': 25, 'region': 20, 'features': 15, 'date': 10};
  static const labels = <String, String>{'breed': '품종', 'color': '색상', 'region': '지역', 'features': '특징', 'date': '날짜'};
  static const maxPoints = 100;

  static const colorLabels = <String, String>{
    'white': '흰색',
    'cream': '크림색',
    'yellow': '노란색',
    'brown': '갈색',
    'black': '검은색',
    'gray': '회색',
    'tricolor': '삼색',
    'spotted': '얼룩',
  };

  static const _sido = <String, String>{
    '서울특별시': '서울', '서울시': '서울', '서울': '서울',
    '부산광역시': '부산', '부산시': '부산', '부산': '부산',
    '대구광역시': '대구', '대구시': '대구', '대구': '대구',
    '인천광역시': '인천', '인천시': '인천', '인천': '인천',
    '광주광역시': '광주', '광주': '광주',
    '대전광역시': '대전', '대전시': '대전', '대전': '대전',
    '울산광역시': '울산', '울산시': '울산', '울산': '울산',
    '세종특별자치시': '세종', '세종시': '세종', '세종': '세종',
    '경기도': '경기', '경기': '경기',
    '강원도': '강원', '강원특별자치도': '강원', '강원': '강원',
    '충청북도': '충북', '충북': '충북',
    '충청남도': '충남', '충남': '충남',
    '전라북도': '전북', '전북특별자치도': '전북', '전북': '전북',
    '전라남도': '전남', '전남': '전남',
    '경상북도': '경북', '경북': '경북',
    '경상남도': '경남', '경남': '경남',
    '제주특별자치도': '제주', '제주도': '제주', '제주': '제주',
  };
  static final _sigungu = RegExp(r'^[가-힣]+(시|군|구)$');
  // 처음 보는 시·도 이름(예: 통합특별시)도 '…도/…시' 꼴이면 그대로 씁니다
  static final _sidoLike = RegExp(r'^[가-힣]{2,}(특별시|광역시|특별자치시|특별자치도|통합특별시|도)$');

  /// 특징 단어 비교에서 빼는 너무 흔한 말 (서버 GENERIC_FEATURE_WORDS 와 같음)
  static const genericFeatureWords = <String>{
    '많음', '많아요', '많고', '많은', '적음', '조금', '약간', '매우', '아주', '편임', '편이에요', '정도',
    '상태', '보통', '양호', '있어요', '없어요', '같아요', '보이는', '추정됨',
  };

  /// '경기도 수원시 영통구 …' → '경기 수원시'. 못 읽으면 null.
  static String? regionKey(String? text) {
    final tokens = (text ?? '').replaceAll(',', ' ').split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return null;
    final sido = _sido[tokens[0]] ?? (_sidoLike.hasMatch(tokens[0]) ? tokens[0] : null);
    if (sido == null) return null;
    for (final t in tokens.skip(1).take(2)) {
      if (_sigungu.hasMatch(t)) return '$sido $t';
    }
    return sido == '세종' ? sido : null;
  }

  static RuleItem _item(String key, bool ok, String reason) {
    final mx = points[key]!;
    return RuleItem(key: key, label: labels[key]!, points: ok ? mx : 0, max: mx, reason: reason);
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static List<RuleItem> compute({
    required String dogBreed,
    required String dogColor,
    required String dogFeatures,
    required DateTime? dogDate,
    required String? dogRegion,
    required String noticeBreed,
    required String noticeColor,
    required String noticeFeatures,
    required DateTime? noticeDate,
    required String? noticeRegion,
  }) {
    final items = <RuleItem>[];

    final nbA = Normalizer.normBreed(dogBreed), nbB = Normalizer.normBreed(noticeBreed);
    final sameBreed = nbA.isNotEmpty && nbA == nbB;
    final shownBreed = (noticeBreed.trim().isNotEmpty ? noticeBreed : dogBreed).trim();
    items.add(_item('breed', sameBreed,
        sameBreed ? '일치 ($shownBreed)' : '다름 (${dogBreed.trim().isEmpty ? '-' : dogBreed.trim()} / ${noticeBreed.trim().isEmpty ? '-' : noticeBreed.trim()})'));

    final ca = Normalizer.colorSet(dogColor), cb = Normalizer.colorSet(noticeColor);
    final common = [for (final c in ca) if (cb.contains(c)) c];
    if (ca.isEmpty || cb.isEmpty) {
      final ta = dogColor.trim(), tb = noticeColor.trim();
      items.add(ta.isNotEmpty && ta == tb
          ? _item('color', true, '공통 색상: $ta')
          : _item('color', false, '공통 색상 없음 (${ta.isEmpty ? '-' : ta} / ${tb.isEmpty ? '-' : tb})'));
    } else if (common.isNotEmpty) {
      items.add(_item('color', true, '공통 색상: ${common.map((c) => colorLabels[c] ?? c).join(', ')}'));
    } else {
      items.add(_item('color', false, '공통 색상 없음 (${dogColor.trim()} / ${noticeColor.trim()})'));
    }

    if (dogRegion == null || noticeRegion == null) {
      items.add(_item('region', false, '시군구 정보 없음 (${dogRegion ?? '-'} / ${noticeRegion ?? '-'})'));
    } else if (dogRegion == noticeRegion) {
      items.add(_item('region', true, '같음 ($dogRegion)'));
    } else {
      items.add(_item('region', false, '다름 ($dogRegion / $noticeRegion)'));
    }

    final words = [
      for (final w in TextSimilarity.keywordMatches(dogFeatures, noticeFeatures))
        if (!genericFeatureWords.contains(w)) w
    ];
    items.add(_item('features', words.isNotEmpty,
        words.isNotEmpty ? '공통 특징 단어: ${words.take(5).join(', ')}' : '공통 특징 단어 없음'));

    if (noticeDate == null || dogDate == null) {
      items.add(_item('date', false, '구조 접수일 정보 없음'));
    } else {
      final nd = DateTime(noticeDate.year, noticeDate.month, noticeDate.day);
      final dd = DateTime(dogDate.year, dogDate.month, dogDate.day);
      items.add(!nd.isBefore(dd)
          ? _item('date', true, '실종일 이후 구조 접수 (${_ymd(nd)})')
          : _item('date', false, '실종일 이전 구조 접수 (${_ymd(nd)})'));
    }
    return items;
  }

  static int total(List<RuleItem> items) => items.fold(0, (s, i) => s + i.points);
}
