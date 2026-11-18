from __future__ import annotations

from app.sources.animal_api import AnimalProtectionSource
from app.sources.base import NoticeSource


def available_sources() -> list[NoticeSource]:
    return [AnimalProtectionSource()]
