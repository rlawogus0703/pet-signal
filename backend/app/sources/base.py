from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date


@dataclass
class NoticeRecord:

    notice_id: str
    source: str
    notice_no: str = ""
    breed: str = ""
    kind_full: str = ""
    color: str = ""
    age: str | None = None
    weight: str = ""
    sex: str = ""
    neuter: str = ""
    features: str = ""
    found_date: date | None = None
    found_address: str = ""
    found_lat: float | None = None
    found_lng: float | None = None
    geo_level: str = ""
    photo_url: str | None = None
    photo_url2: str | None = None
    shelter_name: str = ""
    shelter_phone: str = ""
    care_addr: str = ""
    org_nm: str = ""
    process_state: str = ""
    notice_start: date | None = None
    notice_end: date | None = None
    notice_url: str = ""
    species: str = "dog"
    raw: dict = field(default_factory=dict)


class NoticeSource:

    name: str = "base"

    def enabled(self) -> bool:
        return True

    def fetch(self, *, pages: int, rows: int) -> tuple[list[NoticeRecord], dict]:
        raise NotImplementedError
