from __future__ import annotations

import logging
import time
from datetime import datetime, timedelta, timezone

import httpx

from app.config import get_settings
from app.services.geo import geocode
from app.sources.base import NoticeRecord, NoticeSource

log = logging.getLogger(__name__)

NOTICE_URL = "https://www.animal.go.kr/front/awtis/protection/protectionList.do"
DOG_UPKIND = "417000"
KST = timezone(timedelta(hours=9))


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

    def _get_page(self, client: httpx.Client, params: dict) -> tuple[list[dict], int]:
        url = f"{self.base}/abandonmentPublic_v2"
        last: Exception | None = None
        for attempt in range(3):
            try:
                resp = client.get(url, params=params)
                resp.raise_for_status()
                try:
                    payload = resp.json()
                except ValueError:
                    snippet = resp.text[:200].replace(self.service_key, "***")
                    raise RuntimeError(f"공공 API 응답이 JSON 이 아닙니다: {snippet}")
                items, total, code, msg = extract_items(payload)
                if code and code not in ("00", "0"):
                    raise RuntimeError(f"공공 API 오류 {code}: {msg}")
                return items, total
            except (httpx.TimeoutException, httpx.TransportError, httpx.HTTPStatusError) as e:
                last = RuntimeError(str(e).replace(self.service_key, "***"))
                time.sleep(2 * (attempt + 1))
        raise last or RuntimeError("공공 API 요청 실패")

    def state_params(self, state: str) -> dict:
        p: dict = {"state": state}
        if state == "protect":
            st = get_settings()
            today = datetime.now(KST).date()
            p["bgnde"] = (today - timedelta(days=max(1, st.collect_protect_days))).strftime("%Y%m%d")
            p["endde"] = today.strftime("%Y%m%d")
        return p

    def iter_pages(self, *, states: list[str] | None = None, rows: int = 1000, max_pages: int = 20):
        if not self.service_key:
            raise RuntimeError("SERVICE_KEY not set")
        states = states or list(get_settings().collect_state_list)
        rows = max(1, min(1000, rows))
        own = self.client is None
        client = self.client or httpx.Client(timeout=60.0)
        try:
            for state in states:
                for page in range(1, max(1, max_pages) + 1):
                    params = {
                        "serviceKey": self.service_key,
                        "_type": "json",
                        "upkind": DOG_UPKIND,
                        "pageNo": page,
                        "numOfRows": rows,
                        **self.state_params(state),
                    }
                    items, total = self._get_page(client, params)
                    recs = [r for r in (parse_item(it) for it in items) if r]
                    yield state, recs, total, page
                    if len(items) < rows or page * rows >= total:
                        break
        finally:
            if own:
                client.close()

    def fetch(self, *, pages: int = 1, rows: int = 100) -> tuple[list[NoticeRecord], dict]:
        out: list[NoticeRecord] = []
        totals: dict = {}
        for state, recs, total, _ in self.iter_pages(rows=rows, max_pages=pages):
            out.extend(recs)
            totals[state] = total
        return out, {"source": self.name, "total_count": sum(totals.values()), "totals": totals}
