from datetime import date

from app.models.db_models import NoticeRow
from app.services.chat_search import parse_message
from tests.test_nearby import _client
from app.database import get_db
from app.main import app


def test_parse_message():
    q = parse_message("수원 갈색 푸들 찾아줘")
    assert (q.sido, q.sigungu, q.color, q.kind, q.species) == ("경기도", "수원시", "갈색", "푸들", "dog")
    q = parse_message("서울 강남 흰색 고양이")
    assert (q.sigungu, q.color, q.species) == ("강남구", "흰색", "cat")
    q = parse_message("치즈냥이 부산")
    assert (q.sido, q.color, q.species) == ("부산광역시", "치즈", "cat")
    assert parse_message("안녕").empty()


def test_chat_endpoint(tmp_path):
    client, TS = _client(tmp_path)
    try:
        db = TS()
        d = date(2026, 11, 14)
        db.add_all([
            NoticeRow(notice_id="A", source="animal_api", breed="푸들", color="갈색", found_date=d,
                      found_lat=37.27, found_lng=127.01, found_address="경기도 수원시 팔달구", org_nm="경기도 수원시"),
            NoticeRow(notice_id="B", source="animal_api", breed="푸들", color="흰색", found_date=d,
                      found_lat=37.27, found_lng=127.01, found_address="수원시 이하 미상", org_nm="경기도 수원시"),
            NoticeRow(notice_id="C", source="animal_api", breed="푸들", color="갈색", found_date=d,
                      found_lat=37.5, found_lng=127.0, found_address="서울특별시 강남구", org_nm="서울특별시 강남구"),
            NoticeRow(notice_id="D", source="animal_api", species="cat", breed="한국 고양이", color="노랑",
                      found_date=d, found_lat=35.1, found_lng=129.0, found_address="부산광역시 사하구", org_nm="부산광역시 사하구"),
        ])
        db.commit()
        db.close()
        r = client.post("/api/v1/chat", json={"message": "수원 갈색 푸들 찾아줘"})
        assert r.status_code == 200, r.text
        b = r.json()
        assert [i["notice_id"] for i in b["items"]] == ["A"]
        assert "수원시" in b["reply"] and "1건" in b["reply"]
        b = client.post("/api/v1/chat", json={"message": "부산 치즈 고양이"}).json()
        assert [i["notice_id"] for i in b["items"]] == ["D"]
        b = client.post("/api/v1/chat", json={"message": "대전 검은색 푸들"}).json()
        assert b["total"] == 0 and "찾지 못했어요" in b["reply"]
        b = client.post("/api/v1/chat", json={"message": "안녕"}).json()
        assert b["matched"] is False
        r = client.get("/api/v1/notices/map", params={"region": "경기도 수원시", "limit": 400})
        assert r.status_code == 200 and r.json()["total"] == 4
    finally:
        app.dependency_overrides.pop(get_db, None)


def test_chat_widens_to_sido(tmp_path):
    client, TS = _client(tmp_path)
    try:
        db = TS()
        db.add(NoticeRow(notice_id="E", source="animal_api", species="cat", breed="한국 고양이", color="흰색",
                         found_date=date(2026, 11, 14), found_lat=37.6, found_lng=127.0,
                         found_address="서울특별시 노원구", org_nm="서울특별시 노원구"))
        db.commit()
        db.close()
        b = client.post("/api/v1/chat", json={"message": "서울 강남 흰색 고양이"}).json()
        assert [i["notice_id"] for i in b["items"]] == ["E"]
        assert b["reply"].startswith("강남구에는 없어서 서울특별시에서")
    finally:
        app.dependency_overrides.pop(get_db, None)
