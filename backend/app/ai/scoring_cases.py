"""서버 ↔ 웹 점수 일치 확인용 기준 사례.

scripts/export_scoring_fixture.py 가 이 사례들의 서버 계산값을
web/test/fixtures/scoring_cases.json 으로 내보내고, 웹 테스트(scorer_alignment_test.dart)가
같은 값을 내는지 검사합니다. (AI 모델 없이 경량 방식 기준)
"""

from __future__ import annotations

from datetime import date

from app.ai import image_embedder, text_embedder
from app.ai.fusion import MISSING_IMAGE_NEUTRAL, final_score
from app.services.matcher import score_pair
from app.services.rule_points import region_key

DOG = dict(
    breed="말티즈",
    color="흰색",
    features="소형, 귀가 접힘, 빨간 목걸이, 왼쪽 귀 근처 점, 사람을 잘 따름",
    age="3살",
    lost_date="2026-11-01",
    lat=37.1934,
    lng=127.0225,
    address="경기도 오산시 양산동",
)

NOTICES = [
    dict(breed="믹스견", color="크림색", age="2~3년", features="소형, 귀가 접힘, 빨간 목걸이 흔적, 왼쪽 귀 근처 점, 사람을 잘 따름",
         found_date="2026-11-02", lat=37.1499, lng=127.0697, address="경기도 오산시 원동", weight=""),
    dict(breed="말티즈", color="흰색", age="3살", features="소형견, 빨간 목걸이, 겁이 많음",
         found_date="2026-11-03", lat=37.2167, lng=126.9487, address="경기도 화성시 봉담읍", weight=""),
    dict(breed="진돗개", color="황색", age="3살", features="중형, 경계심 많음, 왼쪽 뒷다리 절뚝임",
         found_date="2026-10-25", lat=37.0080, lng=127.2797, address="경기도 오산시 세교동", weight=""),
    dict(breed="믹스견", color="검정&흰색", age="4살", features="음식점앞 가방 패드포함 유기, 목줄 없음",
         found_date="2026-11-05", lat=37.4135, lng=127.1267, address="경기도 성남시 상적동", weight="12(Kg)"),
    dict(breed="웰시 코기 펨브로크", color="갈색&흰색", age="6개월", features="",
         found_date="2026-11-14", lat=35.8242, lng=127.1480, address="전북특별자치도 전주시 완산구", weight="4.1(Kg)"),
    dict(breed="푸들", color="적갈색", age="5살", features="곱슬 털, 파란 옷 착용, 온순함",
         found_date="2026-11-01", lat=None, lng=None, address="", weight=""),
]

IMAGE_VALUES = [0.8, None, 0.3, None, 0.55, None]


def synthetic_pixels(seed: int) -> list[tuple[int, int, int]]:
    """80x80 결정적 테스트 이미지 (웹 테스트도 같은 식으로 만듭니다)."""
    px = []
    for y in range(80):
        for x in range(80):
            r = (x * 3 + y * seed) % 256
            g = (x * seed + y * 5 + 40) % 256
            b = ((x ^ y) * (seed + 1)) % 256
            px.append((r, g, b))
    return px


def compute_cases() -> dict:
    text_embedder._AVAILABLE = False  # 경량(char-ngram) 기준
    image_embedder.force_light_mode(True)
    out = []
    d = DOG
    for i, n in enumerate(NOTICES):
        ms = score_pair(
            dog_breed=d["breed"], dog_color=d["color"], dog_features=d["features"], dog_age=d["age"],
            dog_date=date.fromisoformat(d["lost_date"]), dog_lat=d["lat"], dog_lng=d["lng"],
            dog_text_emb=None, dog_image_emb=None,
            notice_breed=n["breed"], notice_color=n["color"], notice_features=n["features"], notice_age=n["age"],
            notice_date=date.fromisoformat(n["found_date"]), notice_lat=n["lat"], notice_lng=n["lng"],
            notice_text_emb=None, notice_image_emb=None, notice_weight=n["weight"] or None,
            dog_region=region_key(d["address"]), notice_region=region_key(n["address"]),
        )
        img = IMAGE_VALUES[i]
        out.append(dict(
            notice=n,
            image=img,
            expected=dict(
                points=ms.points.total,
                point_items=[i.points for i in ms.points.items],
                breed=ms.breed, color=ms.color, distance=ms.distance, date=ms.date, age=ms.age,
                rule=ms.rule, keyword=ms.text_keyword, semantic=ms.text_semantic,
                attribute=ms.text_attribute, text=ms.text,
                final_no_photo=ms.total,
                final_with_photo=final_score(ms.rule, ms.text, img if img is not None else MISSING_IMAGE_NEUTRAL),
            ),
        ))
    fa = image_embedder.light_features_from_rgb(synthetic_pixels(7), 80, 80)
    fb = image_embedder.light_features_from_rgb(synthetic_pixels(11), 80, 80)
    image_embedder.force_light_mode(False)
    text_embedder._AVAILABLE = None
    return dict(
        dog=d,
        cases=out,
        image=dict(seed_a=7, seed_b=11, features_a=fa, similarity=image_embedder.light_similarity(fa, fb),
                   self_similarity=image_embedder.light_similarity(fa, fa)),
    )
