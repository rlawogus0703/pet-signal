from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "sqlite:///./petsignal.db"
    service_key: str | None = None
    public_api_base: str = (
        "https://apis.data.go.kr/1543061/abandonmentPublicService_v2"
    )
    collect_interval_minutes: int = 60
    enable_scheduler: bool = True
    cors_origins: str = "*"


@lru_cache
def get_settings() -> Settings:
    return Settings()
