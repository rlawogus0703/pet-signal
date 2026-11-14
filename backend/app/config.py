from functools import lru_cache
from urllib.parse import unquote

from pydantic import AliasChoices, Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    database_url: str = "sqlite:///./petsignal.db"
    # 공공데이터포털 일반 인증키 (Decoding 키 권장, Encoding 키를 넣어도 자동 변환)
    service_key: str | None = Field(
        default=None, validation_alias=AliasChoices("SERVICE_KEY", "DATA_GO_KR_SERVICE_KEY")
    )
    public_api_base: str = "https://apis.data.go.kr/1543061/abandonmentPublicService_v2"
    collect_interval_minutes: int = 60
    collect_pages: int = 2  # 수집 1회당 페이지 수
    collect_rows: int = 100  # 페이지당 공고 수 (최대 1000)
    collect_on_startup: bool = True  # 키가 있으면 서버 시작 때 1회 수집
    embed_images_on_collect: bool = True  # 수집하면서 공고 사진 임베딩까지 계산
    image_fetch_timeout: float = 8.0
    image_workers: int = 8
    match_image_top_k: int = 40  # 매칭 때 사진 임베딩이 없으면 상위 K개만 즉석 계산
    enable_scheduler: bool = True
    cors_origins: str = "*"

    @property
    def decoded_service_key(self) -> str | None:
        k = (self.service_key or "").strip()
        if not k or not k.isascii() or k.lower() in {"your_key_here", "changeme"}:
            return None
        return unquote(k) if "%" in k else k


@lru_cache
def get_settings() -> Settings:
    return Settings()
