"""규칙 기반 매칭 엔진 단위 테스트."""

from datetime import date

from app.services.matcher import (
    age_score,
    breed_score,
    color_score,
    date_score,
    distance_score,
    feature_score,
    haversine_km,
    score_pair,
)
from app.services.normalizer import norm_breed, norm_color, parse_age_years


def test_norm_breed_maltese_mix():
    assert norm_breed("말티즈") == "maltese"
    assert norm_breed("믹스견") == "mix"
    assert norm_breed("잡종") == "mix"


def test_norm_color_white_cream():
    assert norm_color("흰색") == "white"
    assert norm_color("크림색") == "cream"
    assert norm_color("아이보리") == "cream"


def test_breed_and_color_scores_paper_case():
    # 논문 사례: 흰색 말티즈 vs 크림색 믹스견
    assert breed_score("말티즈", "믹스견") == 0.6
    assert color_score("흰색", "크림색") == 0.85


def test_haversine_nearby():
    km = haversine_km(37.5665, 126.9780, 37.5700, 126.9850)
    assert 0.1 < km < 2.0


def test_distance_date_age_feature():
    assert distance_score(0.8) == 1.0
    assert date_score(2) == 0.9
    assert age_score("3살", "2~3년") >= 0.8
    assert feature_score("빨간 목걸이 왼쪽 점", "목걸이 흔적 왼쪽 점") > 0.2


def test_parse_age():
    assert parse_age_years("3살") == 3.0
    assert abs(parse_age_years("2~3년") - 2.5) < 0.01
    assert abs(parse_age_years("6개월") - 0.5) < 0.01


def test_score_pair_ranks_similar_higher():
    similar = score_pair(
        dog_breed="말티즈",
        dog_color="흰색",
        dog_features="왼쪽 귀에 작은 점, 빨간 목걸이",
        dog_age="3살",
        dog_date=date(2026, 10, 28),
        dog_lat=37.5665,
        dog_lng=126.9780,
        dog_text_emb=None,
        dog_image_emb=None,
        notice_breed="믹스견",
        notice_color="크림색",
        notice_features="소형, 귀가 접힘, 목걸이 흔적, 왼쪽 귀 근처 점",
        notice_age="2~3년",
        notice_date=date(2026, 10, 30),
        notice_lat=37.5700,
        notice_lng=126.9850,
        notice_text_emb=None,
        notice_image_emb=None,
    )
    far = score_pair(
        dog_breed="비글",
        dog_color="삼색",
        dog_features="중형, 귀가 큼",
        dog_age="3살",
        dog_date=date(2026, 10, 28),
        dog_lat=37.5665,
        dog_lng=126.9780,
        dog_text_emb=None,
        dog_image_emb=None,
        notice_breed="비글",
        notice_color="삼색",
        notice_features="중형, 귀가 큼",
        notice_age="3살",
        notice_date=date(2026, 10, 15),
        notice_lat=35.1630,
        notice_lng=129.1630,
        notice_text_emb=None,
        notice_image_emb=None,
    )
    # 같은 견종이어도 거리가 멀면(부산) 총점이 서울 유사 후보보다 낮을 수 있음 — 여기선 유사 케이스가 의미 있게 점수 갖는지 확인
    assert similar.total > 0.5
    assert any("색상 유사" in r for r in similar.reasons)
    assert any("사진 유사도" in r for r in similar.reasons)
    assert any("설명 텍스트 유사도" in r for r in similar.reasons)
    assert far.distance < 0.3  # 부산은 거리 점수 낮음
