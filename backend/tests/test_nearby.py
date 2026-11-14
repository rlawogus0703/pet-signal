"""로그인 없이 주변 공고 조회 + 사진 없이 실종견 등록."""

from datetime import date, timedelta

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.ai.image_embedder import candidate_urls, looks_like_image
from app.database import Base, get_db, init_db
from app.main import app
from app.models.db_models import NoticeRow


def test_candidate_urls_https_first():
    urls = candidate_urls("http://openapi.animal.go.kr/file/a.jpg")
    assert urls[0].startswith("https://")
    assert "http://openapi.animal.go.kr/file/a.jpg" in urls
    urls2 = candidate_urls("https://example.com/x.png")
    assert urls2[0].startswith("https://")
    assert "http://example.com/x.png" in urls2


def test_looks_like_image():
    # JPEG magic
    assert looks_like_image(b"\xff\xd8\xff" + b"\x00" * 30)
    assert looks_like_image(b"\x89PNG\r\n\x1a\n" + b"\x00" * 30)
    assert not looks_like_image(b"<html>not an image</html>")
    assert not looks_like_image(None)
    assert not looks_like_image(b"short")


def _client(tmp_path):
    eng = create_engine(f"sqlite:///{tmp_path/'n.db'}", connect_args={"check_same_thread": False})
    TS = sessionmaker(bind=eng, autocommit=False, autoflush=False)
    init_db(eng)

    def override():
        s = TS()
        try:
            yield s
        finally:
            s.close()

    app.dependency_overrides[get_db] = override
    return TestClient(app), TS


def test_nearby_and_register_without_photo(tmp_path):
    client, TS = _client(tmp_path)
    try:
        db = TS()
        today = date(2026, 11, 14)
        rows = [
            NoticeRow(
                notice_id="N1", source="animal_api", notice_no="서울-1",
                breed="말티즈", color="흰색", found_date=today,
                found_lat=37.57, found_lng=126.98, found_address="서울특별시 종로구",
                shelter_name="서울 보호소", shelter_phone="02-111-1111",
                care_addr="서울특별시 종로구 어딘가",
                notice_start=today, notice_end=today + timedelta(days=7),
                photo_url="https://example.com/a.jpg",
            ),
            NoticeRow(
                notice_id="N2", source="animal_api", notice_no="부산-1",
                breed="믹스견", color="검정", found_date=today - timedelta(days=2),
                found_lat=35.18, found_lng=129.08, found_address="부산광역시 해운대구",
                shelter_name="부산 보호소",
                photo_url=None,
            ),
            NoticeRow(
                notice_id="SEED1", source="seed", breed="푸들", color="갈색",
                found_date=today, found_lat=37.57, found_lng=126.98,
            ),
        ]
        for r in rows:
            db.add(r)
        db.commit()
        db.close()

        r = client.get("/api/v1/notices/nearby", params={"lat": 37.5665, "lng": 126.9780})
        assert r.status_code == 200, r.text
        body = r.json()
        assert body["total"] == 2  # real notices only
        assert [i["notice_id"] for i in body["items"]][0] == "N1"
        assert body["items"][0]["dist_km"] is not None
        assert body["items"][0]["shelter_name"] == "서울 보호소"
        assert body["items"][0]["photo_proxy_url"] == "/api/v1/notices/N1/photo"
        assert "SEED1" not in [i["notice_id"] for i in body["items"]]

        r = client.get("/api/v1/notices/nearby", params={"lat": 37.5665, "lng": 126.9780, "kind": "말티즈"})
        assert r.json()["total"] == 1 and r.json()["items"][0]["notice_id"] == "N1"

        r = client.get("/api/v1/notices/nearby", params={"lat": 37.5665, "lng": 126.9780, "color": "검정"})
        assert r.json()["total"] == 1 and r.json()["items"][0]["notice_id"] == "N2"

        r = client.get("/api/v1/notices/nearby", params={"lat": 37.5665, "lng": 126.9780, "radius": 50})
        assert r.json()["total"] == 1 and r.json()["items"][0]["notice_id"] == "N1"

        r = client.get("/api/v1/notices/nearby", params={"region": "서울특별시", "page": 1, "page_size": 1})
        assert r.status_code == 200
        assert r.json()["page"] == 1 and r.json()["page_size"] == 1 and r.json()["total"] == 2
        assert len(r.json()["items"]) == 1

        r = client.get("/api/v1/notices/N1")
        assert r.status_code == 200
        assert r.json()["shelter_phone"] == "02-111-1111"

        # 사진 없이 등록 → 이미지 갈래 제외
        r = client.post("/api/v1/lost-dogs", json=dict(
            breed="말티즈", color="흰색", features="소형, 목걸이", age="3살",
            lost_date="2026-11-11", lost_lat=37.57, lost_lng=126.98, lost_address="서울 종로구",
        ))
        assert r.status_code == 201, r.text
        dog = r.json()
        assert dog["has_photo"] is False
        items = client.get(f"/api/v1/lost-dogs/{dog['id']}/candidates").json()["items"]
        assert items
        assert all(it["source"] != "seed" for it in items)
        top = items[0]
        assert top["notice_id"] == "N1"
        assert top["image_score"] is None
        assert top["score"]["image_status"] == "no_user_photo"
        assert top["rule_score"] is not None and top["text_score"] is not None
        assert top["final_score"] == top["score"]["total"]
    finally:
        app.dependency_overrides.clear()
