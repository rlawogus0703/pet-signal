"""멀티모달 점수 융합."""

DEFAULT_WEIGHTS = {
    "breed": 0.15,
    "color": 0.12,
    "distance": 0.15,
    "date": 0.10,
    "features": 0.10,
    "age": 0.08,
    "image": 0.18,
    "text": 0.12,
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
