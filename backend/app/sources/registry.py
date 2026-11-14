"""사용할 공고 출처 목록. 새 공공 API 를 추가할 때 여기에 등록하세요."""

from __future__ import annotations

from app.sources.animal_api import AnimalProtectionSource
from app.sources.base import NoticeSource


def available_sources() -> list[NoticeSource]:
    return [AnimalProtectionSource()]
