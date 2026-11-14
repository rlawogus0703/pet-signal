"""성능평가용 가상 신고 생성기: 같은 시드면 같은 문제, 정답 공고와 앞뒤가 맞는지."""

from datetime import date

from eval.synth import build_queries, owner_region


def _pool(n=30):
    out = []
    for i in range(n):
        out.append({
            "notice_id": f"N{i:03d}", "breed": "믹스견" if i % 3 else "말티즈", "color": "흰색&갈색" if i % 2 else "검정색",
            "age": "2022(년생)", "weight": f"{3 + i}(Kg)", "features": "온순함, 목줄 착용, 꼬리 짧음",
            "found_date": "2026-11-0" + str(1 + i % 9), "found_lat": 37.15, "found_lng": 127.07,
            "org_nm": "경기도 오산시", "photo_url": f"http://example.invalid/{i}.jpg", "photo_url2": None,
        })
    return out


def test_queries_are_deterministic_and_consistent():
    pool = _pool()
    a = build_queries(pool, per_level=3)
    b = build_queries(pool, per_level=3)
    assert [vars(x) for x in a] == [vars(x) for x in b]
    assert [q.level for q in a] == ["easy"] * 3 + ["medium"] * 3 + ["hard"] * 3
    by_id = {n["notice_id"]: n for n in pool}
    for q in a:
        found = date.fromisoformat(by_id[q.true_id]["found_date"])
        assert 1 <= (found - q.lost_date).days <= 7
        assert 0.5 <= q.shift_km <= 5.0
        assert q.photo_kind == "none" or q.photo_url
        assert "*" not in q.breed and "*" not in q.color


def test_owner_region_keeps_notice_jurisdiction_for_small_shift():
    n = _pool(1)[0]
    assert owner_region(n, 37.151, 127.071) == ("경기도", "오산시")
