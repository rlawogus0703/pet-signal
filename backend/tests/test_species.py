from datetime import date
import sqlite3

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

from app.database import get_db, init_db
from app.main import app
from app.models.db_models import NoticeRow
from app.services.normalizer import norm_breed
from app.sources.animal_api import parse_item


def test_parse_cat_item():
    rec = parse_item(
        {"desertionNo": "C1", "upKindCd": "422400", "kindNm": "코리안 숏헤어",
         "kindFullNm": "[고양이] 코리안 숏헤어", "colorCd": "치즈"},
        "cat",
    )
    assert rec.species == "cat"
    assert rec.breed == "코리안 숏헤어"
    dog = parse_item({"desertionNo": "D1", "kindNm": "말티즈", "kindFullNm": "[개] 말티즈"})
    assert dog.species == "dog"


def test_cat_breed_synonyms():
    assert norm_breed("코숏") == norm_breed("코리안 숏헤어") == "korean_shorthair"
    assert norm_breed("브리티시 숏헤어") == "british_shorthair"


def test_existing_rows_default_dog(tmp_path):
    path = tmp_path / "old.db"
    con = sqlite3.connect(path)
    con.execute("CREATE TABLE notices (notice_id VARCHAR(64) PRIMARY KEY, breed VARCHAR(128))")
    con.execute("INSERT INTO notices VALUES ('OLD', '말티즈')")
    con.commit()
    con.close()
    eng = create_engine(f"sqlite:///{path}")
    init_db(eng)
    with eng.connect() as c:
        assert c.execute(text("SELECT species FROM notices WHERE notice_id='OLD'")).scalar() == "dog"


def test_species_filter_and_matching(tmp_path):
    eng = create_engine(f"sqlite:///{tmp_path/'s.db'}", connect_args={"check_same_thread": False})
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
        client = TestClient(app)
        d = date(2026, 11, 10)
        db = TS()
        db.add_all([
            NoticeRow(notice_id="D1", source="animal_api", breed="말티즈", color="흰색", found_date=d,
                      found_lat=37.57, found_lng=126.98, found_address="서울특별시 종로구"),
            NoticeRow(notice_id="C1", source="animal_api", breed="코리안 숏헤어", color="흰색", found_date=d,
                      found_lat=37.57, found_lng=126.98, found_address="서울특별시 종로구", species="cat"),
        ])
        db.commit()
        db.close()

        r = client.get("/api/v1/notices/nearby", params={"species": "cat"})
        assert r.status_code == 200
        assert [i["notice_id"] for i in r.json()["items"]] == ["C1"]
        assert r.json()["items"][0]["species"] == "cat"
        r = client.get("/api/v1/notices/nearby", params={"species": "dog"})
        assert [i["notice_id"] for i in r.json()["items"]] == ["D1"]
        assert client.get("/api/v1/notices/nearby").json()["total"] == 2

        body = {"breed": "코숏", "color": "흰색", "lost_date": "2026-11-09", "lost_lat": 37.57,
                "lost_lng": 126.98, "lost_address": "서울특별시 종로구", "species": "cat"}
        r = client.post("/api/v1/lost-dogs", json=body)
        assert r.status_code == 201, r.text
        assert r.json()["species"] == "cat"
        cands = client.get(f"/api/v1/lost-dogs/{r.json()['id']}/candidates").json()["items"]
        assert [c["notice_id"] for c in cands] == ["C1"]

        body.pop("species")
        body["breed"] = "말티즈"
        r = client.post("/api/v1/lost-dogs", json=body)
        assert r.json()["species"] == "dog"
        cands = client.get(f"/api/v1/lost-dogs/{r.json()['id']}/candidates").json()["items"]
        assert [c["notice_id"] for c in cands] == ["D1"]
    finally:
        app.dependency_overrides.clear()


def test_cat_only_collect_does_not_mark_dogs_stale(tmp_path):
    from app.services import collector
    from app.sources.base import NoticeRecord

    eng = create_engine(f"sqlite:///{tmp_path/'p.db'}")
    init_db(eng)
    db = sessionmaker(bind=eng)()
    db.add(NoticeRow(notice_id="D1", source="animal_api", breed="말티즈", process_state="보호중"))
    db.commit()

    class CatSource:
        name = "animal_api"

        def enabled(self):
            return True

        def iter_pages(self, *, rows, max_pages, states=None):
            yield "notice:cat", [NoticeRecord(notice_id="C1", source="animal_api", breed="믹스묘",
                                              species="cat")], 1, 1

    r = collector.collect_notices(db, sources=[CatSource()], upkinds=["422400"], embed_images=False)
    assert r["upserted"] == 1 and "marked_stale" not in r["sources"][0]
    assert db.get(NoticeRow, "D1").process_state == "보호중"
    assert db.get(NoticeRow, "C1").species == "cat"
