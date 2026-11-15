"""규칙 점수 100점 (김민재 앱과 같은 기준) 테스트."""

from datetime import date

from app.services.rule_points import MAX_POINTS, compute_rule_points, notice_region, region_key


def _pts(**kw):
    base = dict(
        dog_breed="포메라니안", dog_color="흰색", dog_features="빨간 목줄, 겁이 많음",
        dog_date=date(2026, 11, 1), dog_region="경기 오산시",
        notice_breed="포메라니안", notice_color="흰색", notice_features="온순함",
        notice_date=date(2026, 11, 4), notice_region="경기 연천군",
    )
    base.update(kw)
    return compute_rule_points(**base)


def test_app_example_65():
    """앱 상세 화면 예: 품종 30 · 색상 25 · 지역 0 · 특징 0 · 날짜 10 = 65."""
    p = _pts()
    assert MAX_POINTS == 100
    assert p.total == 65
    got = {i.key: (i.points, i.max, i.reason) for i in p.items}
    assert got["breed"] == (30, 30, "일치 (포메라니안)")
    assert got["color"] == (25, 25, "공통 색상: 흰색")
    assert got["region"] == (0, 20, "다름 (경기 오산시 / 경기 연천군)")
    assert got["features"] == (0, 15, "공통 특징 단어 없음")
    assert got["date"] == (10, 10, "실종일 이후 구조 접수 (2026-11-04)")
    assert [i.label for i in p.items] == ["품종", "색상", "지역", "특징", "날짜"]


def test_full_and_zero():
    full = _pts(notice_region="경기 오산시", notice_features="목걸이 있음, 겁많음")
    assert full.total == 100
    assert full.item("features").reason.startswith("공통 특징 단어:")
    zero = _pts(notice_breed="진돗개", notice_color="검정", notice_date=date(2026, 10, 20))
    assert zero.item("breed").points == 0 and zero.item("breed").reason == "다름 (포메라니안 / 진돗개)"
    assert zero.item("color").points == 0
    assert zero.item("date").points == 0 and zero.item("date").reason.startswith("실종일 이전")
    assert zero.total == 0


def test_partial_colour_share_counts():
    p = _pts(dog_color="흰색", notice_color="검정&흰색")
    assert p.item("color").points == 25 and p.item("color").reason == "공통 색상: 흰색"


def test_same_day_counts_and_missing_info():
    assert _pts(notice_date=date(2026, 11, 1)).item("date").points == 10
    p = _pts(notice_date=None, notice_region=None)
    assert p.item("date").points == 0 and p.item("region").points == 0


def test_region_key_parsing():
    assert region_key("경기도 오산시 오산동 123") == "경기 오산시"
    assert region_key("경기도 수원시 영통구 매탄동") == "경기 수원시"
    assert region_key("서울특별시 강남구") == "서울 강남구"
    assert region_key("서울 서초구 동산로9 (양재동)") == "서울 서초구"
    assert region_key("전북특별자치도 전주시 완산구") == "전북 전주시"
    assert region_key("세종특별자치시") == "세종"
    assert region_key("상적동 96-7") is None
    assert region_key("") is None
    # 공고는 관할 기관(orgNm)을 먼저 봅니다
    assert notice_region("경기도 연천군", "대신면 무촌리") == "경기 연천군"
    assert notice_region("", "경기도 성남시 상적동 96-7") == "경기 성남시"
    # 처음 보는 시·도 이름도 그대로 비교
    assert region_key("전남광주통합특별시 장흥군") == "전남광주통합특별시 장흥군"


def test_generic_feature_words_do_not_count():
    p = _pts(dog_features="소형, 겁이 많음", notice_features="경계심 많음")
    assert p.item("features").points == 0
    p = _pts(dog_features="소형, 겁이 많음", notice_features="겁이 많아요")
    assert p.item("features").points == 15 and p.item("features").reason == "공통 특징 단어: 겁이"
