/// 품종·색상·나이 표기 정규화 (보호자 vs 보호소 표기 차이 완화)
class Normalizer {
  static const breedSynonyms = <String, String>{
    '말티즈': 'maltese',
    '말티스': 'maltese',
    'maltese': 'maltese',
    '믹스': 'mix',
    '믹스견': 'mix',
    '잡종': 'mix',
    '혼종': 'mix',
    '푸들': 'poodle',
    '토이푸들': 'poodle',
    '포메라니안': 'pomeranian',
    '포메': 'pomeranian',
    '시츄': 'shih_tzu',
    '시추': 'shih_tzu',
    '치와와': 'chihuahua',
    '진도': 'jindo',
    '진돗개': 'jindo',
    '리트리버': 'retriever',
    '골든리트리버': 'retriever',
    '비글': 'beagle',
    '요크셔테리어': 'yorkie',
    '요크셔': 'yorkie',
    '비숑': 'bichon',
    '웰시코기': 'corgi',
    '코기': 'corgi',
    '닥스훈트': 'dachshund',
    '코카스파니엘': 'cocker',
    '불독': 'bulldog',
    '프렌치불독': 'bulldog',
  };

  static const colorSynonyms = <String, String>{
    '흰색': 'white',
    '화이트': 'white',
    '백색': 'white',
    '크림': 'cream',
    '크림색': 'cream',
    '아이보리': 'cream',
    '베이지': 'cream',
    '검정': 'black',
    '검은색': 'black',
    '블랙': 'black',
    '갈색': 'brown',
    '브라운': 'brown',
    '황색': 'yellow',
    '노란색': 'yellow',
    '회색': 'gray',
    '그레이': 'gray',
    '삼색': 'tricolor',
    '얼룩': 'spotted',
    '점박이': 'spotted',
  };

  /// 서로 가까운 색상 그룹 (흰색↔크림 등)
  static const colorNeighbors = <String, Set<String>>{
    'white': {'cream'},
    'cream': {'white', 'yellow'},
    'yellow': {'cream', 'brown'},
    'brown': {'yellow', 'black'},
  };

  static String normBreed(String raw) {
    final t = raw.trim().toLowerCase().replaceAll(' ', '');
    for (final e in breedSynonyms.entries) {
      if (t.contains(e.key.toLowerCase())) return e.value;
    }
    return t;
  }

  static String normColor(String raw) {
    final t = raw.trim().toLowerCase().replaceAll(' ', '');
    for (final e in colorSynonyms.entries) {
      if (t.contains(e.key.toLowerCase())) return e.value;
    }
    return t;
  }

  /// 나이 문자열에서 대략 연수 추출
  static double? parseAgeYears(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final nums = RegExp(r'(\d+(?:\.\d+)?)').allMatches(raw).map((m) => double.parse(m.group(1)!)).toList();
    if (nums.isEmpty) {
      if (raw.contains('개월') || raw.contains('puppy') || raw.contains('새끼')) return 0.5;
      return null;
    }
    if (raw.contains('개월')) return nums.first / 12.0;
    if (nums.length >= 2) return (nums[0] + nums[1]) / 2.0;
    return nums.first;
  }

  static List<String> featureTokens(String text) {
    final cleaned = text.toLowerCase().replaceAll(RegExp(r'[^\w가-힣\s]'), ' ');
    final stop = {'에', '의', '을', '를', '이', '가', '은', '는', '과', '와', '및', '등', '있음', '없음', '한', '함'};
    return cleaned
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 2 && !stop.contains(t))
        .toList();
  }
}
