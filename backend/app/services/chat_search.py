from __future__ import annotations

import re
from dataclasses import dataclass, field

from app.services.geo import SIDO_ALIASES, _regions, geocode
from app.services.normalizer import BREED_SYNONYMS, COLOR_SYNONYMS

CAT_WORDS = ("고양이", "냥이", "냥", "cat")
DOG_WORDS = ("강아지", "댕댕이", "멍멍이", "개", "견", "dog")
CAT_BREEDS = {
    "british_shorthair", "american_shorthair", "korean_shorthair", "russian_blue", "persian",
    "scottish_fold", "munchkin", "siamese", "ragdoll", "norwegian_forest", "abyssinian",
    "bengal", "turkish_angora", "maine_coon", "sphynx",
}
SUFFIXES = ("에서는", "에서", "근처", "부근", "주변", "쪽", "에", "의", "을", "를", "은", "는", "도")
DOG_COLOR_WORDS = {"백구": "흰색", "흰둥이": "흰색", "황구": "황색", "누렁이": "누렁", "흑구": "검정색", "깜둥이": "검정색"}
FILLER = ("검색", "찾아줘", "찾아", "보여줘", "알려줘", "있어", "있나", "있어요", "공고", "좀", "주세요", "줘")


@dataclass
class ChatQuery:
    sido: str | None = None
    sigungu: str | None = None
    gu: str | None = None
    species: str | None = None
    kind: str | None = None
    color: str | None = None
    words: list[str] = field(default_factory=list)

    @property
    def region_label(self) -> str | None:
        parts = [p for p in (self.sido, self.sigungu, self.gu) if p]
        return " ".join(parts) or None

    @property
    def short_region(self) -> str | None:
        return self.gu or self.sigungu or self.sido

    def empty(self) -> bool:
        return not (self.sido or self.sigungu or self.species or self.kind or self.color)


def _strip(tok: str) -> str:
    for s in SUFFIXES:
        if tok.endswith(s) and len(tok) - len(s) >= 2:
            return tok[: -len(s)]
    return tok


def _sido_from(tok: str) -> str | None:
    if tok in SIDO_ALIASES.values():
        return tok
    for k in sorted(SIDO_ALIASES, key=len, reverse=True):
        if tok == k or tok in (k + "시", k + "도"):
            return SIDO_ALIASES[k]
    return None


def _same_place(tok: str, name: str) -> bool:
    if not name:
        return False
    if tok == name:
        return True
    return len(name) >= 3 and tok == name[:-1]


def _color_of(tok: str) -> str | None:
    t = tok.replace("색", "").replace("털", "")
    for k in sorted(COLOR_SYNONYMS, key=len, reverse=True):
        if t.startswith(k):
            return tok if tok.endswith("색") or k in ("치즈", "고등어", "턱시도", "삼색", "얼룩", "점박이", "바둑") else k
    return None


def _breed_of(tok: str) -> str | None:
    for k in sorted(BREED_SYNONYMS, key=len, reverse=True):
        if k in tok and k not in ("mix",):
            return k
    return None


def parse_message(text: str) -> ChatQuery:
    q = ChatQuery()
    raw = re.sub(r"[^\w가-힣\s]", " ", (text or "").lower())
    toks = [t for t in raw.split() if t]
    regions = _regions()
    rest: list[str] = []
    for tok in toks:
        cat = next((w for w in CAT_WORDS if w in tok), None)
        if cat:
            q.species = "cat"
            left_part = tok.split(cat)[0]
            if len(left_part) >= 2:
                rest.append(left_part)
            continue
        if tok in DOG_WORDS or tok.startswith("강아지") or tok.startswith("댕댕"):
            q.species = q.species or "dog"
            continue
        rest.append(tok)

    left: list[str] = []
    for tok in rest:
        if tok in BREED_SYNONYMS:
            left.append(tok)
            continue
        t = _strip(tok)
        sido = _sido_from(t)
        if sido and not q.sido:
            q.sido = sido
            continue
        hit = None
        for r in regions:
            if q.sido and r["sido"] != q.sido:
                continue
            if not q.sigungu and not r["gu"] and _same_place(t, r["sigungu"]):
                hit = ("sigungu", r)
                break
            if r["gu"] and _same_place(t, r["gu"]) and (not q.sigungu or r["sigungu"] == q.sigungu):
                hit = ("gu", r)
                break
        if hit:
            kind, r = hit
            q.sido = q.sido or r["sido"]
            q.sigungu = q.sigungu or r["sigungu"]
            if kind == "gu":
                q.gu = r["gu"]
            continue
        if q.sido and not q.sigungu:
            for r in regions:
                if r["sido"] == q.sido and r["gu"] == "" and _same_place(t, r["sigungu"]):
                    q.sigungu = r["sigungu"]
                    break
            if q.sigungu:
                continue
        left.append(tok)

    for tok in left:
        if any(tok.startswith(f) for f in FILLER):
            continue
        if tok in DOG_COLOR_WORDS:
            q.species = q.species or "dog"
            q.color = q.color or DOG_COLOR_WORDS[tok]
            continue
        b = _breed_of(tok)
        if b and not q.kind:
            q.kind = b
            if BREED_SYNONYMS[b] in CAT_BREEDS:
                q.species = "cat"
            elif q.species is None and (BREED_SYNONYMS[b] != "mix" or "견" in tok):
                q.species = "dog"
            continue
        c = _color_of(tok)
        if c and not q.color:
            q.color = c
            continue
        q.words.append(tok)
    return q


def area_filter(q: ChatQuery) -> list[list[str]] | None:
    groups: list[list[str]] = []
    if q.sido:
        short = [k for k, v in SIDO_ALIASES.items() if v == q.sido]
        groups.append([q.sido, *short])
    if q.sigungu:
        groups.append([q.sigungu, q.sigungu[:-1]] if len(q.sigungu) >= 3 else [q.sigungu])
    if q.gu:
        groups.append([q.gu])
    return groups or None


def center_of(q: ChatQuery) -> tuple[float, float, int] | None:
    label = q.region_label
    if not label:
        return None
    g = geocode(label)
    if not g:
        return None
    zoom = 12 if (q.gu or q.sigungu) else 9
    return g[0], g[1], zoom


def describe(q: ChatQuery) -> str:
    animal = "고양이" if q.species == "cat" else ("강아지" if q.species == "dog" else "")
    if q.kind and BREED_SYNONYMS.get(q.kind) != "mix":
        animal = ""
    parts = [p for p in (q.color, q.kind, animal) if p]
    return " ".join(parts)


def reply_text(q: ChatQuery, total: int, shown: int, near_me: bool) -> str:
    where = q.short_region or ("내 주변" if near_me else "전국")
    what = describe(q)
    target = f"{what} 공고" if what else "공고"
    if total == 0:
        return f"{where}에서 {target}를 찾지 못했어요. 색상이나 품종을 빼고 다시 말해 보세요."
    msg = f"{where}에서 {target} {total}건 찾았어요."
    if shown < total:
        msg += f" 가까운 {shown}건을 지도에 표시했어요."
    else:
        msg += " 지도에 표시했어요."
    return msg


HELP = "지역이나 색상, 품종을 말해 주세요. 예: '수원 갈색 푸들', '서울 강남 흰색 고양이'"
