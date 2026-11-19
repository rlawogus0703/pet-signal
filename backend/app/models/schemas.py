from datetime import date, datetime

from typing import Literal

from pydantic import BaseModel, Field

Species = Literal["dog", "cat"]


class LostDogCreate(BaseModel):
    photo_url: str | None = None
    photo_data: str | None = None
    breed: str
    color: str
    features: str = ""
    age: str | None = None
    lost_date: date
    lost_lat: float
    lost_lng: float
    lost_address: str = ""
    species: Species = "dog"


class LostDogOut(BaseModel):
    id: str
    user_id: str | None = None
    photo_url: str | None = None
    breed: str
    color: str
    features: str = ""
    age: str | None = None
    lost_date: date
    lost_lat: float
    lost_lng: float
    lost_address: str = ""
    created_at: datetime
    has_photo: bool = False
    photo_proxy_url: str | None = None
    image_method: str | None = None
    species: str = "dog"


class RuleItemOut(BaseModel):
    key: str
    label: str
    points: int
    max: int
    reason: str


class ScoreBreakdown(BaseModel):
    points: int | None = None
    max_points: int = 100
    items: list[RuleItemOut] = Field(default_factory=list)
    caption: str | None = None
    note: str | None = None
    breed: float = 0
    color: float = 0
    distance: float = 0
    date: float = 0
    features: float = 0
    age: float = 0
    rule: float | None = None
    text: float | None = None
    image: float | None = None
    total: float = 0
    text_keyword: float | None = None
    text_semantic: float | None = None
    text_attribute: float | None = None
    text_method: str | None = None
    image_method: str | None = None
    image_status: str | None = None


class CandidateOut(BaseModel):
    notice_id: str
    notice_no: str = ""
    photo_url: str | None = None
    breed: str = ""
    color: str = ""
    age: str | None = None
    features: str = ""
    found_date: date | None = None
    found_lat: float | None = None
    found_lng: float | None = None
    found_address: str = ""
    shelter_name: str = ""
    shelter_phone: str = ""
    notice_url: str = ""
    score: ScoreBreakdown
    reasons: list[str] = Field(default_factory=list)
    rank: int = 0
    rule_score: float | None = None
    text_score: float | None = None
    image_score: float | None = None
    final_score: float = 0
    source: str = "seed"
    photo_url2: str | None = None
    photo_proxy_url: str | None = None
    photo2_proxy_url: str | None = None
    kind_full: str = ""
    sex: str = ""
    neuter: str = ""
    weight: str = ""
    shelter_address: str = ""
    org_name: str = ""
    process_state: str = ""
    notice_start: date | None = None
    notice_end: date | None = None
    species: str = "dog"
    common_keywords: list[str] = Field(default_factory=list)
    matched_attributes: list[str] = Field(default_factory=list)
    dist_km: float | None = None
    day_diff: int | None = None


class CandidateListOut(BaseModel):
    lost_dog_id: str
    disclaimer: str = (
        "결과는 유사 후보이며 동일 개체로 단정하지 않습니다. "
        "공고 원문과 사진을 직접 확인해 주세요."
    )
    total: int
    items: list[CandidateOut]


class NotificationOut(BaseModel):
    id: str
    lost_dog_id: str
    notice_id: str
    title: str
    body: str
    created_at: datetime
    read: bool = False


class NotificationListOut(BaseModel):
    lost_dog_id: str
    items: list[NotificationOut]


class SignupRequest(BaseModel):
    email: str
    password: str
    name: str = ""
    phone: str | None = None


class LoginRequest(BaseModel):
    email: str
    password: str


class UserOut(BaseModel):
    id: str
    email: str
    name: str = ""
    phone: str | None = None
    created_at: datetime


class AuthTokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


class NearbyNoticeOut(BaseModel):
    notice_id: str
    notice_no: str = ""
    photo_url: str | None = None
    photo_url2: str | None = None
    photo_proxy_url: str | None = None
    photo2_proxy_url: str | None = None
    breed: str = ""
    color: str = ""
    age: str | None = None
    features: str = ""
    kind_full: str = ""
    sex: str = ""
    neuter: str = ""
    weight: str = ""
    found_date: date | None = None
    found_lat: float | None = None
    found_lng: float | None = None
    found_address: str = ""
    dist_km: float | None = None
    shelter_name: str = ""
    shelter_phone: str = ""
    shelter_address: str = ""
    org_name: str = ""
    process_state: str = ""
    notice_start: date | None = None
    notice_end: date | None = None
    notice_url: str = ""
    source: str = "seed"
    species: str = "dog"


class NearbyNoticeListOut(BaseModel):
    origin_lat: float
    origin_lng: float
    origin_label: str
    total: int
    page: int
    page_size: int
    items: list[NearbyNoticeOut]
