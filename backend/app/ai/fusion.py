RULE_WEIGHTS = {"breed": 0.25, "color": 0.25, "distance": 0.25, "date": 0.15, "age": 0.10}
MODAL_WEIGHTS = {"rule": 0.45, "text": 0.25, "image": 0.30}
MISSING_IMAGE_NEUTRAL = 0.40

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
