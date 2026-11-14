/// 품종·색상·나이·특징 표기 정규화 (보호자 vs 보호소 표기 차이 완화)
///
/// 서버(backend/app/services/normalizer.py)와 같은 규칙입니다. 한쪽을 고치면 다른 쪽도 고쳐 주세요.
class Normalizer {
  /// 순서 중요: 앞의 키가 먼저 매칭됩니다.
  static const breedSynonyms = <String, String>{
    '말티즈': 'maltese',
    '말티스': 'maltese',
    'maltese': 'maltese',
    '토이푸들': 'poodle',
    '푸들': 'poodle',
    '포메라니안': 'pomeranian',
    '포메': 'pomeranian',
    '시츄': 'shih_tzu',
    '시추': 'shih_tzu',
    '치와와': 'chihuahua',
    '진돗개': 'jindo',
    '진도': 'jindo',
    '래브라도': 'labrador',
    '리트리버': 'retriever',
    '비글': 'beagle',
    '요크셔': 'yorkie',
    '비숑': 'bichon',
    '코기': 'corgi',
    '닥스훈트': 'dachshund',
    '시바': 'shiba',
    '코카': 'cocker',
    '프렌치불독': 'french_bulldog',
    '불독': 'bulldog',
    '슈나우저': 'schnauzer',
    '스피츠': 'spitz',
    '페키니즈': 'pekingese',
    '보더콜리': 'border_collie',
    '셰퍼드': 'shepherd',
    '세퍼드': 'shepherd',
    '허스키': 'husky',
    '사모예드': 'samoyed',
    '풍산': 'pungsan',
    '삽살': 'sapsal',
    '퍼그': 'pug',
    '핀셔': 'minpin',
    '미니핀': 'minpin',
    '파피용': 'papillon',
    '잭러셀': 'jack_russell',
    '말라뮤트': 'malamute',
    '도베르만': 'doberman',
    '믹스': 'mix',
    '잡종': 'mix',
    '혼종': 'mix',
    'mix': 'mix',
  };

  static const colorSynonyms = <String, String>{
    '흰': 'white',
    '하얀': 'white',
    '화이트': 'white',
    '백색': 'white',
    '크림': 'cream',
    '아이보리': 'cream',
    '베이지': 'cream',
    '노란': 'yellow',
    '노랑': 'yellow',
    '누렁': 'yellow',
    '황': 'yellow',
    '골드': 'yellow',
    '금색': 'yellow',
    '적갈': 'brown',
    '갈': 'brown',
    '브라운': 'brown',
    '초코': 'brown',
    '밤색': 'brown',
    '레드': 'brown',
    '검': 'black',
    '흑': 'black',
    '블랙': 'black',
    '까만': 'black',
    '회': 'gray',
    '그레이': 'gray',
    '실버': 'gray',
    '삼색': 'tricolor',
    '얼룩': 'spotted',
    '점박이': 'spotted',
    '바둑': 'spotted',
  };

  static const _neighborPairs = <(String, String)>[
    ('white', 'cream'),
    ('cream', 'yellow'),
    ('yellow', 'brown'),
    ('brown', 'black'),
    ('white', 'gray'),
    ('gray', 'black'),
  ];

  /// 서로 가까운 색상 그룹 (흰색↔크림 등)
  static final Map<String, Set<String>> colorNeighbors = () {
    final m = <String, Set<String>>{};
    for (final (a, b) in _neighborPairs) {
      m.putIfAbsent(a, () => {}).add(b);
      m.putIfAbsent(b, () => {}).add(a);
    }
    return m;
  }();

  static const stopwords = {
    '에', '의', '을', '를', '이', '가', '은', '는', '과', '와', '및', '등', '있음', '없음', '한', '함',
    '있고', '있는', '있어요', '같음', '보임', '추정',
  };

  static const featureSynonyms = <String, String>{
    '목줄': '목걸이',
    '인식표': '목걸이',
    '소형견': '소형',
    '초소형': '소형',
    '중형견': '중형',
    '대형견': '대형',
    '옷을': '옷',
    '의류': '옷',
    '착용': '옷',
    '처짐': '접힘',
    '처진': '접힘',
    '접힌': '접힘',
  };

  static String _clean(String raw) => raw.trim().toLowerCase().replaceAll(' ', '');

  static String normBreed(String raw) {
    final t = _clean(raw);
    for (final e in breedSynonyms.entries) {
      if (t.contains(e.key.toLowerCase())) return e.value;
    }
    return t;
  }

  /// 색상 코드 목록 (문자열에 나온 순서)
  static List<String> colorSet(String raw) {
    final t = _clean(raw);
    final found = <(int, String)>[];
    for (final e in colorSynonyms.entries) {
      final i = t.indexOf(e.key.toLowerCase());
      if (i >= 0 && !found.any((f) => f.$2 == e.value)) found.add((i, e.value));
    }
    found.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final f in found) f.$2];
  }

  static String normColor(String raw) {
    final cs = colorSet(raw);
    return cs.isNotEmpty ? cs.first : _clean(raw);
  }

  /// '3살', '2~3년', '6개월', '2023(년생)' → 나이(년)
  static double? parseAgeYears(String? raw, {DateTime? today}) {
    if (raw == null || raw.trim().isEmpty) return null;
    if (raw.contains('일미만') || raw.contains('일 미만')) return 0.1;
    final nums = RegExp(r'(\d+(?:\.\d+)?)').allMatches(raw).map((m) => double.parse(m.group(1)!)).toList();
    if (nums.isEmpty) {
      if (raw.contains('개월') || raw.contains('puppy') || raw.contains('새끼') || raw.contains('자견')) return 0.5;
      return null;
    }
    if (nums.first >= 1990 && (raw.contains('년생') || nums.first <= 2100)) {
      final ref = (today ?? DateTime.now()).year;
      final v = ref - nums.first;
      return v < 0.25 ? 0.25 : v;
    }
    if (raw.contains('개월')) return nums.first / 12.0;
    if (nums.length >= 2) return (nums[0] + nums[1]) / 2.0;
    return nums.first;
  }

  static double? parseWeightKg(String? raw) {
    if (raw == null) return null;
    final m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(raw);
    return m == null ? null : double.parse(m.group(1)!);
  }

  static List<String> featureTokens(String text) {
    // 파이썬 \w 와 같게: 문자·숫자·밑줄·한글
    final cleaned = text.toLowerCase().replaceAll(RegExp(r'[^\w가-힣\s]', unicode: true), ' ');
    final out = <String>[];
    for (final t in cleaned.split(RegExp(r'\s+'))) {
      if (t.length < 2 || stopwords.contains(t)) continue;
      out.add(featureSynonyms[t] ?? t);
    }
    return out;
  }
}
