import base64
import json
from datetime import date
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.ai import image_embedder, text_similarity
from app.ai.fusion import MISSING_IMAGE_NEUTRAL, final_score
from app.ai.scoring_cases import compute_cases
from app.services.geo import geocode
from app.services.normalizer import color_set, norm_breed, parse_age_years
from app.sources.animal_api import extract_items, parse_item
from app.sources.base import NoticeRecord, NoticeSource

ROOT = Path(__file__).resolve().parents[2]
DOGS = ROOT / "web" / "assets" / "dogs"

SAMPLE_ITEM = {
    "desertionNo": "441378202601713",
    "happenDt": "20261114",
    "happenPlace": "상적동 96-7",
    "kindFullNm": "[개] 믹스견",
    "kindNm": "믹스견",
    "colorCd": "검정&흰색",
    "age": "2023(년생)",
    "weight": "12(Kg)",
    "noticeNo": "경기-성남-2026-00571",
    "noticeSdt": "20261114",
    "noticeEdt": "20261124",
    "popfile1": "http://openapi.animal.go.kr/openapi/service/rest/fileDownloadSrvc/files/shelter/2026/10/a.jpg",
    "popfile2": "http://openapi.animal.go.kr/openapi/service/rest/fileDownloadSrvc/files/shelter/2026/10/b.jpg",
    "processState": "보호중",
    "sexCd": "M",
    "neuterYn": "U",
    "specialMark": "음식점앞 가방 패드포함 유기",
    "careNm": "펫앤쉘터동물병원",
    "careTel": "031-714-8392",
    "careAddr": "경기도 성남시 분당구 불정로 266 (수내동, 유신제일조합) ",
    "orgNm": "경기도 성남시",
}


@pytest.fixture(autouse=True)
def light_mode():
    image_embedder.force_light_mode(True)
    yield
    image_embedder.force_light_mode(False)


def test_parse_public_api_item_keeps_all_fields():
    rec = parse_item(SAMPLE_ITEM)
    assert rec.photo_url.endswith("a.jpg") and rec.photo_url2.endswith("b.jpg")
    assert rec.breed == "믹스견" and rec.color == "검정&흰색"
    assert rec.weight == "12(Kg)" and rec.sex == "M"
    assert rec.shelter_name == "펫앤쉘터동물병원" and rec.shelter_phone == "031-714-8392"
    assert rec.care_addr.startswith("경기도 성남시 분당구")
    assert rec.notice_start == date(2026, 11, 14) and rec.notice_end == date(2026, 11, 24)
    assert rec.found_address == "경기도 성남시 상적동 96-7"
    assert rec.found_lat and 37.3 < rec.found_lat < 37.5


def test_extract_items_single_and_list():
    payload = {"response": {"header": {"resultCode": "00"}, "body": {"items": {"item": SAMPLE_ITEM}, "totalCount": 1}}}
    items, total, code, _ = extract_items(payload)
    assert len(items) == 1 and total == 1 and code == "00"
    empty = {"response": {"header": {"resultCode": "00"}, "body": {"items": "", "totalCount": 0}}}
    assert extract_items(empty)[0] == []


def test_normalizer_real_api_values():
    assert set(color_set("검정&흰색")) == {"black", "white"}
    assert color_set("황갈색") == ["yellow", "brown"]
    assert norm_breed("웰시 코기 펨브로크") == "corgi"
    assert norm_breed("래브라도 리트리버") == "labrador"
    age = parse_age_years("2023(년생)", today=date(2026, 11, 14))
    assert age == 3
    assert parse_age_years("2026(60일미만)(년생)") == 0.1


def test_geocode_levels():
    assert geocode("경기도 성남시 분당구 불정로 266")[2] == "경기도 성남시 분당구"
    assert geocode("전라북도 전주시 완산구 서원로")[2] == "전북특별자치도 전주시 완산구"
    assert geocode("서울특별시 중구 명동")[2] == "서울특별시 중구"
    assert geocode("상적동 96-7") is None


def test_text_branch_parts():
    a = "소형, 귀가 접힘, 빨간 목걸이, 사람을 잘 따름"
    b = "소형견, 빨간 목줄 착용, 온순함"
    kw = text_similarity.keyword_score(a, b)
    assert kw > 0.3
    attr, matched = text_similarity.attribute_score(a, b)
    assert attr == 1.0 and "성향" in matched and "목걸이" in matched
    attr2, _ = text_similarity.attribute_score("목걸이 있음", "목줄 없음")
    assert attr2 == 0.0
    sem = text_similarity.char_ngram_similarity(a, b)
    assert 0 < sem < 1


def test_light_image_features_from_real_photos():
    a = (DOGS / "maltese_white.jpg").read_bytes()
    fa, m = image_embedder.embed_bytes(a)
    assert m == image_embedder.METHOD_LIGHT and len(fa) == 128
    assert abs(sum(fa[:64]) - 1.0) < 1e-6
    assert image_embedder.similarity(fa, fa, m) == pytest.approx(1.0)
    fb, _ = image_embedder.embed_bytes((DOGS / "mix_black.jpg").read_bytes())
    fc, _ = image_embedder.embed_bytes((DOGS / "bichon.jpg").read_bytes())
    s_black = image_embedder.similarity(fa, fb, m)
    s_white = image_embedder.similarity(fa, fc, m)
    assert s_white > s_black


def test_fetch_failure_is_graceful():
    assert image_embedder.fetch_bytes("https://invalid.invalid/x.jpg", timeout=1) is None
    assert image_embedder.fetch_bytes(None) is None
    assert image_embedder.light_features_from_bytes(b"not an image") is None


def test_https_first_for_animal_go_kr():
    urls = image_embedder.candidate_urls("http://openapi.animal.go.kr/x.jpg")
    assert urls[0].startswith("https://")


def test_fusion_rules():
    assert final_score(0.8, 0.6, None) == pytest.approx((0.45 * 0.8 + 0.25 * 0.6) / 0.70)
    assert final_score(0.8, 0.6, 0.9) == pytest.approx(0.45 * 0.8 + 0.25 * 0.6 + 0.30 * 0.9)
    assert MISSING_IMAGE_NEUTRAL == 0.40


def test_web_fixture_is_up_to_date():
    saved = json.loads((ROOT / "web" / "test" / "fixtures" / "scoring_cases.json").read_text(encoding="utf-8"))
    now = json.loads(json.dumps(compute_cases(), ensure_ascii=False))
    for a, b in zip(saved["cases"], now["cases"]):
        for k, v in b["expected"].items():
            if v is None:
                assert a["expected"][k] is None
            else:
                assert a["expected"][k] == pytest.approx(v, abs=1e-9), k
    assert saved["image"]["similarity"] == pytest.approx(now["image"]["similarity"])


class FakeSource(NoticeSource):
    name = "fake"

    def fetch(self, *, pages, rows):
        rec = parse_item(SAMPLE_ITEM)
        rec.photo_url = str(DOGS / "mix_black.jpg")
        rec.photo_url2 = None
        rec2 = NoticeRecord(
            notice_id="FAKE2", source="fake", breed="말티즈", color="흰색", age="3살",
            features="소형, 빨간 목걸이, 사람을 잘 따름", found_date=date(2026, 11, 12),
            found_lat=37.42, found_lng=127.12, photo_url=str(DOGS / "maltese_white.jpg"),
            shelter_name="테스트 보호소", care_addr="경기도 성남시", org_nm="경기도 성남시", notice_start=date(2026, 11, 12),
            notice_end=date(2026, 11, 22),
        )
        return [rec, rec2], {"total_count": 2}


def test_api_flow_with_photo_and_collect(tmp_path, monkeypatch):
    from app.database import Base, get_db, init_db
    from app.main import app
    from app.services import collector

    eng = create_engine(f"sqlite:///{tmp_path/'t.db'}", connect_args={"check_same_thread": False})
    TS = sessionmaker(bind=eng, autocommit=False, autoflush=False)
    init_db(eng)

    def override():
        s = TS()
        try:
            yield s
        finally:
            s.close()

    app.dependency_overrides[get_db] = override
    try:
        c = TestClient(app)
        db = TS()
        res = collector.collect_notices(db, sources=[FakeSource()], embed_images=True)
        db.close()
        assert res["ok"] and res["fetched"] == 2 and res["images"]["embedded"] == 2

        photo = base64.b64encode((DOGS / "my_maltese.jpg").read_bytes()).decode()
        r = c.post("/api/v1/lost-dogs", json=dict(
            photo_data="data:image/jpeg;base64," + photo, breed="말티즈", color="흰색",
            features="소형, 빨간 목걸이, 사람을 잘 따름", age="3살", lost_date="2026-11-11",
            lost_lat=37.41, lost_lng=127.12, lost_address="경기도 성남시"))
        assert r.status_code == 201, r.text
        dog = r.json()
        assert dog["has_photo"] and dog["photo_proxy_url"]
        items = c.get(f"/api/v1/lost-dogs/{dog['id']}/candidates").json()["items"]
        assert [it["notice_id"] for it in items][0] == "FAKE2"
        assert all(it["source"] != "seed" for it in items)
        top = items[0]
        sc = top["score"]
        assert sc["max_points"] == 100
        assert [it["key"] for it in sc["items"]] == ["breed", "color", "region", "features", "date"]
        assert [it["max"] for it in sc["items"]] == [30, 25, 20, 15, 10]
        assert sc["points"] == sum(it["points"] for it in sc["items"]) == 100
        assert sc["items"][2]["reason"] == "같음 (경기 성남시)"
        assert sc["caption"].startswith("일치 근거를 합산한 점수")
        assert top["final_score"] == pytest.approx(1.0)
        assert top["image_score"] is None and top["text_score"] is None
        second = items[1]["score"]
        assert second["points"] == 55
        assert items[1]["rank"] == 2
        assert top["notice_start"] == "2026-11-12" and top["shelter_address"] == "경기도 성남시"
        assert any(x.startswith("품종 30/30점") for x in top["reasons"])
        d = c.get(f"/api/v1/lost-dogs/{dog['id']}/candidates/{top['notice_id']}").json()
        assert d["rank"] == 1 and d["score"]["points"] == 100
        p = c.get(top["photo_proxy_url"])
        assert p.status_code == 200 and p.headers["content-type"] == "image/jpeg"
        assert c.get(dog["photo_proxy_url"]).status_code == 200
        info = c.get("/api/v1/system").json()
        assert info["pipeline"]["rule_points"] == {"breed": 30, "color": 25, "region": 20, "features": 15, "date": 10}
    finally:
        app.dependency_overrides.clear()
