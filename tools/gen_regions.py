import json
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
URL = "https://raw.githubusercontent.com/southkorea/southkorea-maps/master/kostat/2013/json/skorea_municipalities_geo_simple.json"

SIDO = {
    "11": "서울특별시", "21": "부산광역시", "22": "대구광역시", "23": "인천광역시",
    "24": "광주광역시", "25": "대전광역시", "26": "울산광역시", "29": "세종특별자치시",
    "31": "경기도", "32": "강원특별자치도", "33": "충청북도", "34": "충청남도",
    "35": "전북특별자치도", "36": "전라남도", "37": "경상북도", "38": "경상남도",
    "39": "제주특별자치도",
}
RENAME = {("인천광역시", "남구"): "미추홀구"}


def ring_centroid(ring):
    a = cx = cy = 0.0
    for i in range(len(ring) - 1):
        x0, y0 = ring[i][:2]
        x1, y1 = ring[i + 1][:2]
        cr = x0 * y1 - x1 * y0
        a += cr
        cx += (x0 + x1) * cr
        cy += (y0 + y1) * cr
    if abs(a) < 1e-12:
        xs = [p[0] for p in ring]
        ys = [p[1] for p in ring]
        return sum(xs) / len(xs), sum(ys) / len(ys), 0.0
    a *= 0.5
    return cx / (6 * a), cy / (6 * a), abs(a)


def geom_centroid(g):
    polys = [g["coordinates"]] if g["type"] == "Polygon" else g["coordinates"]
    tx = ty = ta = 0.0
    for poly in polys:
        x, y, a = ring_centroid(poly[0])
        tx += x * a
        ty += y * a
        ta += a
    return (tx / ta, ty / ta) if ta else ring_centroid(polys[0][0])[:2]


def main():
    if len(sys.argv) > 1:
        data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    else:
        data = json.loads(urllib.request.urlopen(URL, timeout=30).read().decode("utf-8"))
    rows = []
    city_acc = {}
    for f in data["features"]:
        code = f["properties"]["code"]
        name = f["properties"]["name"]
        sido = SIDO[code[:2]]
        lng, lat = geom_centroid(f["geometry"])
        if "시" in name[:-1] and name.endswith("구") and code[:2] not in ("11", "21", "22", "23", "24", "25", "26"):
            idx = name.index("시") + 1
            city, gu = name[:idx], name[idx:]
            rows.append({"sido": sido, "sigungu": city, "gu": gu, "lat": round(lat, 4), "lng": round(lng, 4)})
            acc = city_acc.setdefault((sido, city), [0.0, 0.0, 0])
            acc[0] += lat
            acc[1] += lng
            acc[2] += 1
        else:
            name = RENAME.get((sido, name), name)
            rows.append({"sido": sido, "sigungu": name, "gu": "", "lat": round(lat, 4), "lng": round(lng, 4)})
    for (sido, city), (la, ln, n) in city_acc.items():
        rows.append({"sido": sido, "sigungu": city, "gu": "", "lat": round(la / n, 4), "lng": round(ln / n, 4)})
    order = list(SIDO.values())
    rows.sort(key=lambda r: (order.index(r["sido"]), r["sigungu"], r["gu"]))
    (ROOT / "backend/data/regions.json").write_text(json.dumps(rows, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")

    lines = [
        "// 자동 생성 파일: tools/gen_regions.py (직접 수정하지 마세요)",
        "// 전국 시·군·구 중심 좌표 (KOSTAT 2013 경계 기반, 거리 점수용 근사치)",
        "",
        "/// (시·도, 시·군·구, 위도, 경도)",
        "const regionRows = <(String, String, double, double)>[",
    ]
    for r in rows:
        label = r["sigungu"] + (" " + r["gu"] if r["gu"] else "")
        lines.append(f"  ('{r['sido']}', '{label}', {r['lat']}, {r['lng']}),")
    lines += ["];", ""]
    (ROOT / "web/lib/data/regions_data.dart").write_text("\n".join(lines), encoding="utf-8")
    print("ok", len(rows))


if __name__ == "__main__":
    main()
