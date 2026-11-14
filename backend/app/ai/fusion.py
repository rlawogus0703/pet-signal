"""멀티모달 점수 융합.

final = 규칙(rule) 0.45 + 텍스트(text) 0.25 + 이미지(image) 0.30
  - rule  = 품종 0.25 · 색상 0.25 · 거리 0.25 · 날짜 0.15 · 나이 0.10
  - text  = 키워드 0.4 · 문장 의미 0.4 · 문장 속성/성향 0.2   (app/ai/text_similarity.py)
  - image = 사진 임베딩 유사도                                  (app/ai/image_embedder.py)
사용자가 사진을 올리지 않았으면 이미지 갈래는 빼고 나머지 가중치로 다시 나눕니다.
사용자 사진은 있는데 공고 사진이 없거나 못 받으면 중립값(0.40)을 넣어
'사진 없는 공고'가 오히려 유리해지지 않게 합니다 (image_score 자체는 null 로 표시).

웹(web/lib/matching/scorer.dart)도 똑같은 가중치를 씁니다.
"""

RULE_WEIGHTS = {"breed": 0.25, "color": 0.25, "distance": 0.25, "date": 0.15, "age": 0.10}
MODAL_WEIGHTS = {"rule": 0.45, "text": 0.25, "image": 0.30}
MISSING_IMAGE_NEUTRAL = 0.40

# 예전 이름 호환 (항목별 가중치를 한 표로 보고 싶을 때)
DEFAULT_WEIGHTS = {
    **{k: v * MODAL_WEIGHTS["rule"] for k, v in RULE_WEIGHTS.items()},
    "text": MODAL_WEIGHTS["text"],
    "image": MODAL_WEIGHTS["image"],
}


def fuse(parts: dict[str, float | None], weights: dict[str, float] | None = None) -> float:
    w = weights or DEFAULT_WEIGHTS
    s = 0.0
    wsum = 0.0
    for k, weight in w.items():
        v = parts.get(k)
        if v is None:
            continue
        s += weight * float(v)
        wsum += weight
    if wsum == 0:
        return 0.0
    return max(0.0, min(1.0, s / wsum))


def rule_score(parts: dict[str, float]) -> float:
    return fuse(parts, RULE_WEIGHTS)


def final_score(rule: float, text: float | None, image: float | None) -> float:
    return fuse({"rule": rule, "text": text, "image": image}, MODAL_WEIGHTS)
