from __future__ import annotations

import math
import re
from dataclasses import dataclass

from app.ai import text_embedder
from app.services.normalizer import feature_tokens, parse_weight_kg

TEXT_WEIGHTS = {"keyword": 0.4, "semantic": 0.4, "attribute": 0.2}


def _token_match(a: str, b: str) -> bool:
    if a == b:
        return True
    short, long_ = (a, b) if len(a) <= len(b) else (b, a)
    return len(short) >= 2 and long_.startswith(short) and len(long_) - len(short) <= 2


def keyword_matches(a: str, b: str) -> list[str]:
    ta = list(dict.fromkeys(feature_tokens(a)))
    tb = list(dict.fromkeys(feature_tokens(b)))
    used: set[int] = set()
    common: list[str] = []
    for x in ta:
        for j, y in enumerate(tb):
            if j not in used and _token_match(x, y):
                used.add(j)
                common.append(x if len(x) <= len(y) else y)
                break
    return common


def keyword_score(a: str, b: str) -> float:
    ta = set(feature_tokens(a))
    tb = set(feature_tokens(b))
    if not ta or not tb:
        return 0.1
    m = len(keyword_matches(a, b))
    return 2.0 * m / (len(ta) + len(tb))


def _bigrams(text: str) -> dict[str, int]:
    vec: dict[str, int] = {}
    for tok in feature_tokens(text):
        grams = [tok] if len(tok) < 2 else [tok[i : i + 2] for i in range(len(tok) - 1)]
        for g in grams:
            vec[g] = vec.get(g, 0) + 1
    return vec


def char_ngram_similarity(a: str, b: str) -> float:
    va, vb = _bigrams(a), _bigrams(b)
    if not va or not vb:
        return 0.0
    dot = sum(v * vb.get(k, 0) for k, v in va.items())
    na = math.sqrt(sum(v * v for v in va.values()))
    nb = math.sqrt(sum(v * v for v in vb.values()))
    return max(0.0, min(1.0, dot / (na * nb)))


def semantic_method() -> str:
    return "sentence-transformers" if text_embedder.ai_available() else "char-ngram"


def semantic_score(
    a: str,
    b: str,
    emb_a: list[float] | None = None,
    emb_b: list[float] | None = None,
) -> tuple[float, str]:
    if text_embedder.ai_available():
        try:
            ea = emb_a if emb_a and len(emb_a) > 64 else text_embedder.embed_text(a)
            eb = emb_b if emb_b and len(emb_b) > 64 else text_embedder.embed_text(b)
            if len(ea) > 64 and len(eb) > 64:
                c = text_embedder.cosine(ea, eb)
                return max(0.0, min(1.0, (c - 0.2) / 0.8)), "sentence-transformers"
        except Exception:
            pass
    return char_ngram_similarity(a, b), "char-ngram"


ATTRIBUTE_RULES: list[tuple[str, str, list[str]]] = [
    ("size", "small", ["초소형", "소형", "작은", "작음"]),
    ("size", "medium", ["중형"]),
    ("size", "large", ["대형", "큰 개", "덩치"]),
    ("collar", "yes", ["목걸이", "목줄", "하네스", "인식표", "방울"]),
    ("clothes", "yes", ["옷", "티셔츠", "조끼", "의류"]),
    ("ear", "fold", ["귀가 접", "접힌 귀", "귀 접", "귀가 처", "처진 귀"]),
    ("ear", "erect", ["귀가 서", "선 귀", "쫑긋"]),
    ("tail", "curl", ["꼬리 말", "꼬리가 말", "말린 꼬리"]),
    ("tail", "short", ["꼬리 짧", "꼬리가 짧", "꼬리 없", "단미"]),
    ("coat", "curly", ["곱슬"]),
    ("coat", "long", ["장모", "털이 김", "털 풍성", "털이 긴"]),
    ("coat", "short", ["단모", "털이 짧"]),
    ("temper", "friendly", ["잘 따름", "잘따름", "온순", "순함", "순해", "애교", "친화", "사람을 좋아", "활발"]),
    ("temper", "wary", ["겁", "경계", "예민", "공격", "사나", "입질", "짖음"]),
]
NEGATION = re.compile(r"^\s*(없|안\s|미착용|x)")

ATTRIBUTE_LABELS = {
    "size": "크기",
    "collar": "목걸이",
    "clothes": "옷",
    "ear": "귀 모양",
    "tail": "꼬리",
    "coat": "털",
    "temper": "성향",
}


def extract_attributes(text: str, weight: str | None = None) -> dict[str, str]:
    t = (text or "").lower()
    out: dict[str, str] = {}
    for cat, val, keys in ATTRIBUTE_RULES:
        if cat in out:
            continue
        for k in keys:
            i = t.find(k)
            if i < 0:
                continue
            after = t[i + len(k) : i + len(k) + 4]
            if cat in ("collar", "clothes") and NEGATION.search(after):
                out[cat] = "no"
            else:
                out[cat] = val
            break
    if "size" not in out:
        kg = parse_weight_kg(weight)
        if kg is not None:
            out["size"] = "small" if kg <= 7 else ("medium" if kg <= 18 else "large")
    return out


def attribute_score(
    a: str, b: str, weight_b: str | None = None
) -> tuple[float | None, list[str]]:
    aa = extract_attributes(a)
    bb = extract_attributes(b, weight_b)
    common = [c for c in aa if c in bb]
    if not common:
        return None, []
    matched = [c for c in common if aa[c] == bb[c]]
    return len(matched) / len(common), [ATTRIBUTE_LABELS[c] for c in matched]


@dataclass
class TextResult:
    keyword: float
    semantic: float
    attribute: float | None
    score: float
    method: str
    common_keywords: list[str]
    matched_attributes: list[str]


def combine_text(keyword: float, semantic: float, attribute: float | None) -> float:
    parts = {"keyword": keyword, "semantic": semantic, "attribute": attribute}
    s = w = 0.0
    for k, weight in TEXT_WEIGHTS.items():
        v = parts[k]
        if v is None:
            continue
        s += weight * v
        w += weight
    return max(0.0, min(1.0, s / w)) if w else 0.0


def describe(breed: str, color: str, age: str | None, features: str) -> str:
    return f"{color} {breed} {age or ''} {features}".strip()


def text_similarity(
    *,
    dog_features: str,
    dog_sentence: str,
    notice_features: str,
    notice_sentence: str,
    notice_weight: str | None = None,
    dog_emb: list[float] | None = None,
    notice_emb: list[float] | None = None,
) -> TextResult:
    kw = keyword_score(dog_features, notice_features)
    sem, method = semantic_score(dog_sentence, notice_sentence, dog_emb, notice_emb)
    attr, matched = attribute_score(dog_features, notice_features, notice_weight)
    return TextResult(
        keyword=kw,
        semantic=sem,
        attribute=attr,
        score=combine_text(kw, sem, attr),
        method=method,
        common_keywords=keyword_matches(dog_features, notice_features),
        matched_attributes=matched,
    )
