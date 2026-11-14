import 'dart:math';

import 'normalizer.dart';

/// 텍스트 기반 유사도 (교수님 피드백: 텍스트 알고리즘 갈래)
///
/// 서버(backend/app/ai/text_similarity.py)와 같은 규칙입니다.
///  1) keyword   단어(키워드) 알고리즘  : 특징 키워드 겹침 (Dice, 동의어·접두 일치)
///  2) semantic  문장 의미 유사도       : 웹은 글자 2-gram 코사인 (서버는 AI 문장 임베딩 가능)
///  3) attribute 문장 속성·성향 분석    : 크기·목걸이·옷·귀·꼬리·털·성향(온순/경계) 비교
class TextSimilarity {
  static const weights = <String, double>{'keyword': 0.4, 'semantic': 0.4, 'attribute': 0.2};

  // ── 1) 키워드 ──
  static bool _tokenMatch(String a, String b) {
    if (a == b) return true;
    final (s, l) = a.length <= b.length ? (a, b) : (b, a);
    return s.length >= 2 && l.startsWith(s) && l.length - s.length <= 2;
  }

  static List<String> _unique(List<String> xs) {
    final seen = <String>{};
    return [for (final x in xs) if (seen.add(x)) x];
  }

  static List<String> keywordMatches(String a, String b) {
    final ta = _unique(Normalizer.featureTokens(a));
    final tb = _unique(Normalizer.featureTokens(b));
    final used = <int>{};
    final common = <String>[];
    for (final x in ta) {
      for (var j = 0; j < tb.length; j++) {
        if (!used.contains(j) && _tokenMatch(x, tb[j])) {
          used.add(j);
          common.add(x.length <= tb[j].length ? x : tb[j]);
          break;
        }
      }
    }
    return common;
  }

  static double keywordScore(String a, String b) {
    final ta = Normalizer.featureTokens(a).toSet();
    final tb = Normalizer.featureTokens(b).toSet();
    if (ta.isEmpty || tb.isEmpty) return 0.1;
    final m = keywordMatches(a, b).length;
    return 2.0 * m / (ta.length + tb.length);
  }

  // ── 2) 문장 의미 (글자 2-gram) ──
  static Map<String, int> _bigrams(String text) {
    final v = <String, int>{};
    for (final tok in Normalizer.featureTokens(text)) {
      final grams = tok.length < 2 ? [tok] : [for (var i = 0; i < tok.length - 1; i++) tok.substring(i, i + 2)];
      for (final g in grams) {
        v[g] = (v[g] ?? 0) + 1;
      }
    }
    return v;
  }

  static double charNgramSimilarity(String a, String b) {
    final va = _bigrams(a), vb = _bigrams(b);
    if (va.isEmpty || vb.isEmpty) return 0.0;
    var dot = 0.0;
    va.forEach((k, v) => dot += v * (vb[k] ?? 0));
    final na = sqrt(va.values.fold<double>(0, (s, v) => s + v * v));
    final nb = sqrt(vb.values.fold<double>(0, (s, v) => s + v * v));
    return (dot / (na * nb)).clamp(0.0, 1.0);
  }

  // ── 3) 문장 속성·성향 ──
  static const _rules = <(String, String, List<String>)>[
    ('size', 'small', ['초소형', '소형', '작은', '작음']),
    ('size', 'medium', ['중형']),
    ('size', 'large', ['대형', '큰 개', '덩치']),
    ('collar', 'yes', ['목걸이', '목줄', '하네스', '인식표', '방울']),
    ('clothes', 'yes', ['옷', '티셔츠', '조끼', '의류']),
    ('ear', 'fold', ['귀가 접', '접힌 귀', '귀 접', '귀가 처', '처진 귀']),
    ('ear', 'erect', ['귀가 서', '선 귀', '쫑긋']),
    ('tail', 'curl', ['꼬리 말', '꼬리가 말', '말린 꼬리']),
    ('tail', 'short', ['꼬리 짧', '꼬리가 짧', '꼬리 없', '단미']),
    ('coat', 'curly', ['곱슬']),
    ('coat', 'long', ['장모', '털이 김', '털 풍성', '털이 긴']),
    ('coat', 'short', ['단모', '털이 짧']),
    ('temper', 'friendly', ['잘 따름', '잘따름', '온순', '순함', '순해', '애교', '친화', '사람을 좋아', '활발']),
    ('temper', 'wary', ['겁', '경계', '예민', '공격', '사나', '입질', '짖음']),
  ];
  static final _negation = RegExp(r'^\s*(없|안\s|미착용|x)');

  static const attributeLabels = <String, String>{
    'size': '크기',
    'collar': '목걸이',
    'clothes': '옷',
    'ear': '귀 모양',
    'tail': '꼬리',
    'coat': '털',
    'temper': '성향',
  };

  static Map<String, String> extractAttributes(String text, {String? weight}) {
    final t = text.toLowerCase();
    final out = <String, String>{};
    for (final (cat, val, keys) in _rules) {
      if (out.containsKey(cat)) continue;
      for (final k in keys) {
        final i = t.indexOf(k);
        if (i < 0) continue;
        final end = min(t.length, i + k.length + 4);
        final after = t.substring(i + k.length, end);
        out[cat] = ((cat == 'collar' || cat == 'clothes') && _negation.hasMatch(after)) ? 'no' : val;
        break;
      }
    }
    if (!out.containsKey('size')) {
      final kg = Normalizer.parseWeightKg(weight);
      if (kg != null) out['size'] = kg <= 7 ? 'small' : (kg <= 18 ? 'medium' : 'large');
    }
    return out;
  }

  /// (점수 또는 null, 일치한 속성 이름)
  static (double?, List<String>) attributeScore(String a, String b, {String? weightB}) {
    final aa = extractAttributes(a);
    final bb = extractAttributes(b, weight: weightB);
    final common = [for (final c in aa.keys) if (bb.containsKey(c)) c];
    if (common.isEmpty) return (null, const []);
    final matched = [for (final c in common) if (aa[c] == bb[c]) c];
    return (matched.length / common.length, [for (final c in matched) attributeLabels[c]!]);
  }

  static double combine(double keyword, double semantic, double? attribute) {
    final parts = <String, double?>{'keyword': keyword, 'semantic': semantic, 'attribute': attribute};
    var s = 0.0, w = 0.0;
    weights.forEach((k, weight) {
      final v = parts[k];
      if (v == null) return;
      s += weight * v;
      w += weight;
    });
    return w == 0 ? 0.0 : (s / w).clamp(0.0, 1.0);
  }

  static String describe(String breed, String color, String? age, String features) =>
      '$color $breed ${age ?? ''} $features'.trim();

  static TextResult compare({
    required String dogFeatures,
    required String dogSentence,
    required String noticeFeatures,
    required String noticeSentence,
    String? noticeWeight,
  }) {
    final kw = keywordScore(dogFeatures, noticeFeatures);
    final sem = charNgramSimilarity(dogSentence, noticeSentence);
    final (attr, matched) = attributeScore(dogFeatures, noticeFeatures, weightB: noticeWeight);
    return TextResult(
      keyword: kw,
      semantic: sem,
      attribute: attr,
      score: combine(kw, sem, attr),
      commonKeywords: keywordMatches(dogFeatures, noticeFeatures),
      matchedAttributes: matched,
    );
  }
}

class TextResult {
  const TextResult({
    required this.keyword,
    required this.semantic,
    required this.attribute,
    required this.score,
    required this.commonKeywords,
    required this.matchedAttributes,
  });
  final double keyword;
  final double semantic;
  final double? attribute;
  final double score;
  final List<String> commonKeywords;
  final List<String> matchedAttributes;
}
