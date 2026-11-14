from datetime import date, datetime

from pydantic import BaseModel, Field


class LostDogCreate(BaseModel):
    photo_url: str | None = None
    # 업로드 사진 (base64 또는 data:image/...;base64,...) — 이미지 유사도 계산에 사용
    photo_data: str | None = None
    breed: str
    color: str
    features: str = ""
    age: str | None = None
    lost_date: date
    lost_lat: float
    lost_lng: float
    lost_address: str = ""


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


class ScoreBreakdown(BaseModel):
    # 규칙 기반 항목
    breed: float = 0
    color: float = 0
    distance: float = 0
    date: float = 0
    features: float = 0  # = text_keyword (예전 필드 호환)
    age: float = 0
    # 세 갈래 + 최종
    rule: float | None = None  # 규칙 점수 (품종·색상·거리·날짜·나이)
    text: float | None = None  # 텍스트 점수 (키워드 + 문장 의미 + 속성/성향)
    image: float | None = None  # 이미지 점수 (사진 임베딩), 사진이 없으면 null
    total: float = 0  # 멀티모달 최종 점수
    # 텍스트 세부
    text_keyword: float | None = None
    text_semantic: float | None = None
    text_attribute: float | None = None
    text_method: str | None = None  # sentence-transformers | char-ngram
    # 이미지 세부
    image_method: str | None = None  # clip | color-hist+dhash
    image_status: str | None = None  # ok | no_user_photo | no_notice_photo | fetch_failed


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
    # 멀티모달 요약 (score 안의 값과 같음)
    rule_score: float | None = None
    text_score: float | None = None
    image_score: float | None = None
    final_score: float = 0
    # 공고 상세 (공공 API)
    source: str = "seed"
    photo_url2: str | None = None
    photo_proxy_url: str | None = None  # 웹에서 CORS 없이 보는 서버 경유 사진 주소
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
