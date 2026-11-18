from __future__ import annotations

import io
import math
import random
import re
from dataclasses import dataclass, field
from datetime import date, timedelta

from app.services.geo import SIDO_ALIASES, _regions
from app.services.normalizer import color_set, norm_breed, parse_age_years, parse_weight_kg

SEED = 20261115
LEVELS = ("easy", "medium", "hard")

BREED_VARIANTS = {
    "mix": ["믹스", "잡종", "믹스견", "혼종"],
    "poodle": ["토이푸들", "푸들", "푸우들*"],
    "maltese": ["말티즈", "말티스", "몰티즈*"],
    "jindo": ["진돗개", "진도", "진도믹스"],
    "pomeranian": ["포메", "포메라니안", "포메리안*"],
    "bichon": ["비숑", "비숑프리제"],
    "chihuahua": ["치와와", "치와와믹스"],
    "shiba": ["시바", "시바견", "시바이누"],
    "retriever": ["리트리버", "골든리트리버", "골든*"],
    "labrador": ["래브라도", "래브라도 리트리버", "라브라도*"],
    "corgi": ["코기", "웰시코기"],
    "spitz": ["스피츠", "재패니즈 스피츠"],
    "husky": ["허스키", "시베리안허스키"],
    "border_collie": ["보더콜리"],
    "yorkie": ["요크셔", "요키*"],
    "shih_tzu": ["시츄", "시추"],
    "french_bulldog": ["프렌치불독", "프불*"],
}
BELIEVED = {
    ("white", "small"): ["말티즈", "말티즈 믹스", "비숑"],
    ("white", "large"): ["진돗개", "백구*", "진도믹스"],
    ("cream", "small"): ["푸들", "포메라니안", "말티즈"],
    ("cream", "large"): ["진돗개", "황구*", "리트리버 믹스"],
    ("yellow", "small"): ["포메라니안", "푸들"],
    ("yellow", "large"): ["황구*", "누렁이*", "진돗개"],
    ("brown", "small"): ["푸들", "포메라니안", "치와와"],
    ("brown", "large"): ["황구*", "진돗개", "시고르자브종*"],
    ("black", "small"): ["푸들", "치와와 믹스"],
    ("black", "large"): ["흑구*", "래브라도 믹스", "시고르자브종*"],
}
UNKNOWN_BREED = ["모름", "시고르자브종*", "똥개*"]

COLOR_WORDS = {
    "white": ["흰색", "하얀색", "화이트", "백색"],
    "cream": ["크림색", "아이보리", "베이지", "살구색*"],
    "yellow": ["노란색", "황색", "금색", "누런색*"],
    "brown": ["갈색", "브라운", "밤색", "초코색", "황갈색"],
    "black": ["검정색", "검은색", "까만색", "블랙"],
    "gray": ["회색", "그레이", "은색*"],
    "tricolor": ["삼색"],
    "spotted": ["얼룩", "점박이"],
}
COLOR_NEIGHBOR = {
    "white": ["cream", "gray"],
    "cream": ["white", "yellow"],
    "yellow": ["cream", "brown"],
    "brown": ["yellow", "black"],
    "black": ["brown", "gray"],
    "gray": ["white", "black"],
    "tricolor": ["brown"],
    "spotted": ["white"],
}

PARAPHRASE = [
    ("목줄", "목걸이"), ("인식표", "목걸이"), ("미착용", "안 하고 있음"), ("착용", "하고 있음"),
    ("온순함", "착해요"), ("온순", "순해요"), ("순함", "순한 편"), ("사람을 좋아함", "사람 잘 따라요"),
    ("경계심", "낯가림 있음"), ("경계", "낯가림"), ("겁이 많음", "겁많음"), ("활발", "에너지 넘침"),
    ("소형", "작은 편"), ("중형", "중간 크기"), ("대형", "덩치 큼"),
]
OWNER_NOISE = ["이름 부르면 옴", "산책하다 놓침", "집 앞에서 나감", "간식 좋아함", "문 열린 사이 나감", "겁먹으면 숨음"]
SHELTER_ONLY = re.compile(r"(접종|구충|키트|인계|마을배회|배회|해당없음|미등록|칩|내장|양호|체형|\d+월\d+일|^\.$)")


def _clean_word(w: str) -> str:
    return w.rstrip("*")


@dataclass
class Query:
    qid: str
    level: str
    true_id: str
    breed: str
    color: str
    age: str | None
    features: str
    lost_date: date
    lat: float
    lng: float
    region: tuple[str, str]
    shift_km: float
    day_gap: int
    photo_kind: str
    photo_url: str | None
    tags: list[str] = field(default_factory=list)


def size_of(n: dict) -> str:
    kg = parse_weight_kg(n.get("weight"))
    return "small" if (kg is not None and kg <= 8) else "large"


def nearest_region(lat: float, lng: float) -> tuple[str, str]:
    best, bd = None, 1e9
    for r in _regions():
        d = (r["lat"] - lat) ** 2 + ((r["lng"] - lng) * math.cos(math.radians(lat))) ** 2
        if d < bd:
            best, bd = r, d
    return (best["sido"], best["sigungu"]) if best else ("", "")


def owner_region(n: dict, lat: float, lng: float) -> tuple[str, str]:
    here = nearest_region(lat, lng)
    if here == nearest_region(n["found_lat"], n["found_lng"]):
        return notice_region(n) if notice_region(n)[0] else here
    return here


def notice_region(n: dict) -> tuple[str, str]:
    toks = (n.get("org_nm") or "").split()
    if not toks:
        return ("", "")
    sido = toks[0]
    for k in sorted(SIDO_ALIASES, key=len, reverse=True):
        if sido.startswith(k):
            sido = SIDO_ALIASES[k]
            break
    return (sido, toks[1] if len(toks) > 1 else "")


def shift_point(lat: float, lng: float, km: float, rng: random.Random) -> tuple[float, float]:
    th = rng.uniform(0, 2 * math.pi)
    return (lat + km * math.cos(th) / 111.0, lng + km * math.sin(th) / (111.0 * math.cos(math.radians(lat))))


def _pick(rng, xs):
    return rng.choice(xs)


def owner_breed(n: dict, level: str, rng: random.Random, tags: list[str]) -> str:
    raw = n["breed"]
    canon = norm_breed(raw)
    cs = color_set(n["color"]) or ["white"]
    believed = BELIEVED.get((cs[0], size_of(n)), ["믹스"])
    variants = BREED_VARIANTS.get(canon)
    u = rng.random()
    if level == "easy":
        if u < 0.7 or not variants:
            tags.append("breed:exact")
            return raw
        tags.append("breed:variant")
        return _pick(rng, variants)
    if level == "medium":
        if u < 0.2:
            tags.append("breed:exact")
            return raw
        if u < 0.7 and variants:
            v = _pick(rng, variants)
            if canon != "mix" and rng.random() < 0.3:
                v = _clean_word(v) + " 믹스"
            tags.append("breed:variant" + ("_unknown" if v.endswith("*") else ""))
            return v
        if canon == "mix":
            tags.append("breed:believed")
            return _pick(rng, believed)
        tags.append("breed:mix")
        return "믹스"
    if u < 0.3:
        tags.append("breed:unknown")
        return _pick(rng, UNKNOWN_BREED)
    if u < 0.7 and canon == "mix":
        tags.append("breed:believed")
        return _pick(rng, believed)
    if variants:
        tags.append("breed:variant")
        return _pick(rng, variants)
    tags.append("breed:believed")
    return _pick(rng, believed)


def owner_color(n: dict, level: str, rng: random.Random, tags: list[str]) -> str:
    raw = n["color"]
    cs = color_set(raw)
    if not cs:
        tags.append("color:exact")
        return raw
    main = cs[0]
    rest = cs[1:]
    u = rng.random()
    if level == "easy":
        if u < 0.5:
            tags.append("color:exact")
            return raw
        words = [_pick(rng, COLOR_WORDS.get(main, [raw]))]
        if rest and rng.random() < 0.5:
            words.append(_pick(rng, COLOR_WORDS.get(rest[0], [""])))
        tags.append("color:synonym")
        return " ".join(words)
    if level == "medium":
        if u < 0.6:
            words = [_pick(rng, COLOR_WORDS.get(main, [raw]))]
            if rest and rng.random() < 0.5:
                words.append(_pick(rng, COLOR_WORDS.get(rest[0], [""])))
            tags.append("color:synonym")
        else:
            words = [_pick(rng, COLOR_WORDS[_pick(rng, COLOR_NEIGHBOR.get(main, [main]))])]
            tags.append("color:neighbor")
        return " ".join(words)
    if u < 0.6:
        tags.append("color:neighbor")
        return _pick(rng, COLOR_WORDS[_pick(rng, COLOR_NEIGHBOR.get(main, [main]))])
    tags.append("color:synonym")
    return _pick(rng, COLOR_WORDS.get(main, [raw]))


def owner_age(n: dict, level: str, rng: random.Random) -> str | None:
    fd = date.fromisoformat(n["found_date"])
    y = parse_age_years(n.get("age"), today=fd)
    if y is None or (level == "hard" and rng.random() < 0.5):
        return None
    jitter = {"easy": 0.0, "medium": 1.0, "hard": 2.0}[level]
    y = max(0.2, y + rng.uniform(-jitter, jitter))
    return f"{max(1, round(y * 12))}개월" if y < 1 else f"{round(y)}살"


def owner_features(n: dict, level: str, rng: random.Random) -> str:
    phrases = [p.strip() for p in re.split(r"[,./·\n]+", n.get("features") or "") if p.strip()]
    phrases = [p for p in phrases if not SHELTER_ONLY.search(p)]
    keep = {"easy": (0.7, 1.0), "medium": (0.3, 0.6), "hard": (0.0, 0.3)}[level]
    k = round(len(phrases) * rng.uniform(*keep))
    kept = rng.sample(phrases, k) if phrases else []
    if level != "easy":
        out = []
        for p in kept:
            for a, b in PARAPHRASE:
                if a in p and rng.random() < 0.7:
                    p = p.replace(a, b)
            out.append(p)
        kept = out
    kg = parse_weight_kg(n.get("weight"))
    if kg is not None and rng.random() < {"easy": 0.5, "medium": 0.5, "hard": 0.4}[level]:
        kept.append("작은 편" if kg <= 7 else ("중간 크기" if kg <= 18 else "덩치 큼"))
    if level != "easy" or rng.random() < 0.3:
        kept.append(_pick(rng, OWNER_NOISE))
    rng.shuffle(kept)
    return ", ".join(kept)


def choose_photo(n: dict, level: str, rng: random.Random) -> tuple[str, str | None]:
    p1, p2 = n.get("photo_url"), n.get("photo_url2")
    has2 = bool(p2 and p2 != p1)
    if level == "easy":
        return "photo1_mild", p1
    if level == "medium":
        if rng.random() < 0.2:
            return "none", None
        return ("photo2", p2) if has2 and rng.random() < 0.6 else ("photo1_moderate", p1)
    if rng.random() < 0.4:
        return "none", None
    return ("photo2_heavy", p2) if has2 and rng.random() < 0.6 else ("photo1_heavy", p1)


def degrade(data: bytes, kind: str, rng: random.Random) -> bytes | None:
    from PIL import Image, ImageEnhance, ImageOps

    try:
        img = Image.open(io.BytesIO(data)).convert("RGB")
    except Exception:
        return None
    strength = {"photo1_mild": 1, "photo2": 1, "photo1_moderate": 2, "photo2_heavy": 2, "photo1_heavy": 3}[kind]
    crop = {1: (0.85, 0.95), 2: (0.70, 0.85), 3: (0.55, 0.75)}[strength]
    jit = {1: 0.10, 2: 0.20, 3: 0.30}[strength]
    rot = {1: 3, 2: 10, 3: 20}[strength]
    w, h = img.size
    s = rng.uniform(*crop)
    cw, ch = int(w * s), int(h * s)
    x0, y0 = rng.randint(0, w - cw), rng.randint(0, h - ch)
    img = img.crop((x0, y0, x0 + cw, y0 + ch))
    img = img.rotate(rng.uniform(-rot, rot), resample=Image.BILINEAR, expand=False, fillcolor=(128, 128, 128))
    if strength >= 2 and rng.random() < 0.5:
        img = ImageOps.mirror(img)
    img = ImageEnhance.Brightness(img).enhance(1 + rng.uniform(-jit, jit))
    img = ImageEnhance.Color(img).enhance(1 + rng.uniform(-jit, jit))
    img = ImageEnhance.Contrast(img).enhance(1 + rng.uniform(-jit, jit))
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality={1: 80, 2: 65, 3: 50}[strength])
    return buf.getvalue()


def eligible(n: dict) -> bool:
    return bool(n.get("found_date") and n.get("found_lat") is not None and n.get("photo_url"))


def build_queries(pool: list[dict], per_level: int = 60, seed: int = SEED) -> list[Query]:
    rng = random.Random(seed)
    cand = sorted((n for n in pool if eligible(n)), key=lambda n: n["notice_id"])
    picked = rng.sample(cand, per_level * len(LEVELS))
    queries: list[Query] = []
    for i, n in enumerate(picked):
        level = LEVELS[i // per_level]
        r = random.Random(f"{seed}-{n['notice_id']}-{level}")
        tags: list[str] = []
        km = r.uniform(*{"easy": (0.5, 1.5), "medium": (1.0, 3.0), "hard": (2.0, 5.0)}[level])
        gap = r.randint(*{"easy": (1, 2), "medium": (1, 4), "hard": (3, 7)}[level])
        lat, lng = shift_point(n["found_lat"], n["found_lng"], km, r)
        kind, url = choose_photo(n, level, r)
        queries.append(
            Query(
                qid=f"q{i:03d}",
                level=level,
                true_id=n["notice_id"],
                breed=_clean_word(owner_breed(n, level, r, tags)),
                color=_clean_word(owner_color(n, level, r, tags)),
                age=owner_age(n, level, r),
                features=owner_features(n, level, r),
                lost_date=date.fromisoformat(n["found_date"]) - timedelta(days=gap),
                lat=lat,
                lng=lng,
                region=owner_region(n, lat, lng),
                shift_km=km,
                day_gap=gap,
                photo_kind=kind,
                photo_url=url,
                tags=tags,
            )
        )
    return queries
