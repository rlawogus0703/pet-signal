"""품종·색상·나이 표기 정규화."""

BREED_SYNONYMS = {
    "말티즈": "maltese",
    "말티스": "maltese",
    "maltese": "maltese",
    "믹스": "mix",
    "믹스견": "mix",
    "잡종": "mix",
    "혼종": "mix",
    "푸들": "poodle",
    "토이푸들": "poodle",
    "포메라니안": "pomeranian",
    "포메": "pomeranian",
    "시츄": "shih_tzu",
    "시추": "shih_tzu",
    "치와와": "chihuahua",
    "진도": "jindo",
    "진돗개": "jindo",
    "리트리버": "retriever",
    "골든리트리버": "retriever",
    "비글": "beagle",
    "요크셔테리어": "yorkie",
    "요크셔": "yorkie",
    "비숑": "bichon",
    "웰시코기": "corgi",
    "코기": "corgi",
    "닥스훈트": "dachshund",
}

COLOR_SYNONYMS = {
    "흰색": "white",
    "화이트": "white",
    "백색": "white",
    "크림": "cream",
    "크림색": "cream",
    "아이보리": "cream",
    "베이지": "cream",
    "검정": "black",
    "검은색": "black",
    "블랙": "black",
    "갈색": "brown",
    "브라운": "brown",
    "황색": "yellow",
    "노란색": "yellow",
    "회색": "gray",
    "그레이": "gray",
    "삼색": "tricolor",
    "얼룩": "spotted",
    "점박이": "spotted",
}

COLOR_NEIGHBORS = {
    "white": {"cream"},
    "cream": {"white", "yellow"},
    "yellow": {"cream", "brown"},
    "brown": {"yellow", "black"},
}


def norm_breed(raw: str) -> str:
    t = (raw or "").strip().lower().replace(" ", "")
    for k, v in BREED_SYNONYMS.items():
        if k.lower() in t:
            return v
    return t


def norm_color(raw: str) -> str:
    t = (raw or "").strip().lower().replace(" ", "")
    for k, v in COLOR_SYNONYMS.items():
        if k.lower() in t:
            return v
    return t


def parse_age_years(raw: str | None) -> float | None:
    if not raw:
        return None
    import re

    nums = [float(x) for x in re.findall(r"(\d+(?:\.\d+)?)", raw)]
    if not nums:
        if any(x in raw for x in ("개월", "puppy", "새끼")):
            return 0.5
        return None
    if "개월" in raw:
        return nums[0] / 12.0
    if len(nums) >= 2:
        return (nums[0] + nums[1]) / 2.0
    return nums[0]


def feature_tokens(text: str) -> list[str]:
    import re

    cleaned = re.sub(r"[^\w가-힣\s]", " ", (text or "").lower())
    stop = {"에", "의", "을", "를", "이", "가", "은", "는", "과", "와", "및", "등", "있음", "없음", "한", "함"}
    return [t for t in cleaned.split() if len(t) >= 2 and t not in stop]
