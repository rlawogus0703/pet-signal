"""농림축산식품부 농림축산검역본부 구조동물 조회 서비스 v2 (공공데이터포털 15098931).

https://www.data.go.kr/data/15098931/openapi.do
엔드포인트: {base}/abandonmentPublic_v2
"""

from __future__ import annotations

import logging
from datetime import datetime

import httpx

from app.config import get_settings
from app.services.geo import geocode
from app.sources.base import NoticeRecord, NoticeSource

log = logging.getLogger(__name__)

NOTICE_URL = "https://www.animal.go.kr/front/awtis/protection/protectionList.do"
DOG_UPKIND = "417000"


def parse_ymd(raw) -> "datetime.date | None":
    if not raw:
        return None
    s = str(raw).replace("-", "").replace(".", "")[:8]
    try:
        return datetime.strptime(s, "%Y%m%d").date()
    except Exception:
        return None


def _s(v) -> str:
    return "" if v is None else str(v).strip()


def parse_item(it: dict) -> NoticeRecord | None:
    nid = _s(it.get("desertionNo"))
    if not nid:
        return None
    org = _s(it.get("orgNm"))
    happen = _s(it.get("happenPlace"))
    care_addr = _s(it.get("careAddr"))
    # 발견 위치: 관할(orgNm)+발견장소 → 없으면 보호소 주소
    g = geocode(f"{org} {happen}".strip()) or geocode(care_addr)
    breed = _s(it.get("kindNm")) or _s(it.get("kindCd"))
    kind_full = _s(it.get("kindFullNm"))
    org_toks = org.split()
    if happen and org and not any(t in happen for t in org_toks[1:2]):
        found_address = f"{org} {happen}"
    else:
        found_address = happen or org
    return NoticeRecord(
        notice_id=nid,
        source="animal_api",
        notice_no=_s(it.get("noticeNo")) or nid,
        breed=breed.replace("[개]", "").strip(),
        kind_full=kind_full,
        color=_s(it.get("colorCd")),
        age=_s(it.get("age")) or None,
        weight=_s(it.get("weight")),
        sex=_s(it.get("sexCd")),
        neuter=_s(it.get("neuterYn")),
        features=_s(it.get("specialMark")),
        found_date=parse_ymd(it.get("happenDt")) or parse_ymd(it.get("noticeSdt")),
        found_address=found_address,
        found_lat=g[0] if g else None,
        found_lng=g[1] if g else None,
        geo_level=g[2] if g else "",
        photo_url=_s(it.get("popfile1")) or _s(it.get("popfile")) or _s(it.get("filename")) or None,
        photo_url2=_s(it.get("popfile2")) or None,
        shelter_name=_s(it.get("careNm")),
        shelter_phone=_s(it.get("careTel")),
        care_addr=care_addr,
        org_nm=org,
        process_state=_s(it.get("processState")),
        notice_start=parse_ymd(it.get("noticeSdt")),
        notice_end=parse_ymd(it.get("noticeEdt")),
        notice_url=NOTICE_URL,
        raw=it,
    )


def extract_items(payload: dict) -> tuple[list[dict], int, str, str]:
    resp = payload.get("response", payload)
    header = resp.get("header", {}) or {}
    body = resp.get("body", {}) or {}
    items = (body.get("items") or {}) if isinstance(body.get("items"), dict) else {}
    lst = items.get("item", []) if items else []
    if isinstance(lst, dict):
        lst = [lst]
    total = int(body.get("totalCount") or 0)
    return lst, total, _s(header.get("resultCode")), _s(header.get("resultMsg"))


class AnimalProtectionSource(NoticeSource):
    name = "animal_api"

    def __init__(self, service_key: str | None = None, base: str | None = None, client: httpx.Client | None = None):
        st = get_settings()
        self.service_key = service_key or st.decoded_service_key
        self.base = base or st.public_api_base
        self.client = client

    def enabled(self) -> bool:
        return bool(self.service_key)

    def fetch(self, *, pages: int = 1, rows: int = 100) -> tuple[list[NoticeRecord], dict]:
        if not self.service_key:
            raise RuntimeError("SERVICE_KEY not set")
        url = f"{self.base}/abandonmentPublic_v2"
        out: list[NoticeRecord] = []
        total = 0
        own = self.client is None
        client = self.client or httpx.Client(timeout=30.0)
        try:
            for page in range(1, max(1, pages) + 1):
                params = {
                    "serviceKey": self.service_key,
                    "_type": "json",
                    "upkind": DOG_UPKIND,
                    "state": "notice",
                    "pageNo": page,
                    "numOfRows": rows,
                }
                resp = client.get(url, params=params)
                resp.raise_for_status()
                try:
                    payload = resp.json()
                except ValueError:
                    # 키 오류 등은 XML 로 옵니다 (키는 로그에 남기지 않음)
                    snippet = resp.text[:200].replace(self.service_key, "***")
                    raise RuntimeError(f"공공 API 응답이 JSON 이 아닙니다: {snippet}")
                items, total, code, msg = extract_items(payload)
                if code and code not in ("00", "0"):
                    raise RuntimeError(f"공공 API 오류 {code}: {msg}")
                for it in items:
                    rec = parse_item(it)
                    if rec:
                        out.append(rec)
                if len(items) < rows:
                    break
        finally:
            if own:
                client.close()
        return out, {"source": self.name, "total_count": total}
