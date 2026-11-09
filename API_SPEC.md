# 펫 시그널 (Pet Signal) — 공유 REST API 명세 (초안)

> 팀: **10조** · 클라이언트: 재현(웹), 민재(앱) · 백엔드: FastAPI (담당 TBD)
>
> **중요**: 매칭 결과는 동일 개체로 단정하지 않으며 항상 **「유사 후보」**로 표시한다.
> 최종 확인은 공고 원문·사진을 본 보호자와 보호소가 수행한다.

- Base URL (로컬): `http://127.0.0.1:8000`
- Content-Type: `application/json`
- 인증: 시연용은 없음 (추후 보호자 계정 추가 예정)

---

## 공통 타입

### LostDog (실종견)

| 필드 | 타입 | 설명 |
|------|------|------|
| id | string (uuid) | 서버 발급 |
| photo_url | string \| null | 사진 URL (시연은 플레이스홀더 가능) |
| breed | string | 품종 (예: 말티즈) |
| color | string | 색상 (예: 흰색) |
| features | string | 특징 문구 |
| age | string \| null | 나이/연령대 (예: `3살`, `2~3년`) |
| lost_date | string (YYYY-MM-DD) | 실종 날짜 |
| lost_lat | number | 실종 위치 위도 |
| lost_lng | number | 실종 위치 경도 |
| lost_address | string | 주소 텍스트 |
| created_at | string (ISO8601) | 등록 시각 |

### ScoreBreakdown (항목별 점수, 0~1)

| 필드 | 설명 |
|------|------|
| breed | 품종 유사도 |
| color | 색상 유사도 |
| distance | 거리 점수 (가까울수록 높음) |
| date | 날짜 점수 (차이 작을수록 높음) |
| features | 특징 키워드/텍스트 유사도 |
| age | 나이 유사도 |
| image | 사진(이미지) 유사도 (AI, 없으면 null) |
| text | 설명 문장 임베딩 유사도 (AI, 없으면 null) |
| total | 융합 최종 점수 |

### Candidate (유사 후보)

| 필드 | 타입 | 설명 |
|------|------|------|
| notice_id | string | 공고 식별자 (desertionNo 등) |
| notice_no | string | 공고 번호 |
| photo_url | string \| null | 공고 사진 |
| breed | string | 공고 품종 |
| color | string | 공고 색상 |
| age | string \| null | 공고 나이 |
| features | string | 특징/특이사항 |
| found_date | string (YYYY-MM-DD) | 구조/발견일 |
| found_lat / found_lng | number \| null | 구조 위치 |
| found_address | string | 구조 장소 |
| shelter_name | string | 보호소명 |
| shelter_phone | string | 보호소 전화 |
| notice_url | string | animal.go.kr 원문 링크 |
| score | ScoreBreakdown | 항목별·총점 |
| reasons | string[] | 한국어 추천 이유 |
| rank | int | 순위 (1부터) |

### NotificationItem

| 필드 | 타입 | 설명 |
|------|------|------|
| id | string | 알림 id |
| lost_dog_id | string | 대상 실종견 |
| notice_id | string | 신규 후보 공고 |
| title | string | 알림 제목 |
| body | string | 본문 |
| created_at | string (ISO8601) | 시각 |
| read | boolean | 읽음 여부 |

---

## 0. 인증 (회원가입 / 로그인)

### `POST /auth/signup`

```json
{
  "email": "jaehyun@example.com",
  "password": "pass1234",
  "name": "재현",
  "phone": "010-1111-2222"
}
```

### Response `201`

```json
{
  "access_token": "<jwt>",
  "token_type": "bearer",
  "user": {
    "id": "u-uuid",
    "email": "jaehyun@example.com",
    "name": "재현",
    "phone": "010-1111-2222",
    "created_at": "2026-11-09T13:00:00"
  }
}
```

### `POST /auth/login`

```json
{ "email": "jaehyun@example.com", "password": "pass1234" }
```

응답 형식은 signup과 동일.

### `GET /auth/me`

Header: `Authorization: Bearer <token>`

실종견 등록(`POST /api/v1/lost-dogs`) 시 Bearer 토큰이 있으면 `user_id`가 연결된다.

---

## 1. 실종견 등록

`POST /api/v1/lost-dogs`

### Request

```json
{
  "photo_url": "https://example.com/my-dog.jpg",
  "breed": "말티즈",
  "color": "흰색",
  "features": "왼쪽 귀에 작은 점, 빨간 목걸이",
  "age": "3살",
  "lost_date": "2026-10-28",
  "lost_lat": 37.5665,
  "lost_lng": 126.9780,
  "lost_address": "서울특별시 중구 명동"
}
```

### Response `201`

```json
{
  "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "photo_url": "https://example.com/my-dog.jpg",
  "breed": "말티즈",
  "color": "흰색",
  "features": "왼쪽 귀에 작은 점, 빨간 목걸이",
  "age": "3살",
  "lost_date": "2026-10-28",
  "lost_lat": 37.5665,
  "lost_lng": 126.9780,
  "lost_address": "서울특별시 중구 명동",
  "created_at": "2026-11-09T13:00:00+09:00"
}
```

---

## 2. 실종견 조회

`GET /api/v1/lost-dogs/{lost_dog_id}`

### Response `200` — LostDog 객체

---

## 3. 유사 후보 목록 (점수 순)

`GET /api/v1/lost-dogs/{lost_dog_id}/candidates?limit=20`

결과는 **유사 후보**이며 동일 견 단정이 아님.

### Response `200`

```json
{
  "lost_dog_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "disclaimer": "결과는 유사 후보이며 동일 개체로 단정하지 않습니다. 공고 원문과 사진을 직접 확인해 주세요.",
  "total": 2,
  "items": [
    {
      "notice_id": "N20261101001",
      "notice_no": "서울-중구-2026-00123",
      "photo_url": null,
      "breed": "믹스견",
      "color": "크림색",
      "age": "2~3년",
      "features": "소형, 귀가 접힘, 목걸이 흔적",
      "found_date": "2026-10-30",
      "found_lat": 37.5700,
      "found_lng": 126.9850,
      "found_address": "서울특별시 중구 을지로",
      "shelter_name": "중구 동물보호센터",
      "shelter_phone": "02-1234-5678",
      "notice_url": "https://www.animal.go.kr/front/awtis/protection/protectionList.do",
      "score": {
        "breed": 0.6,
        "color": 0.85,
        "distance": 0.92,
        "date": 0.9,
        "features": 0.55,
        "age": 0.8,
        "image": 0.82,
        "text": 0.71,
        "total": 0.78
      },
      "reasons": [
        "색상 유사 (흰색 ↔ 크림색)",
        "품종 유사 (말티즈 ↔ 믹스견)",
        "실종 지점과 약 0.8km",
        "날짜 차이 2일",
        "나이 유사 (3살 ↔ 2~3년)",
        "사진 유사도 0.82",
        "설명 텍스트 유사도 0.71"
      ],
      "rank": 1
    }
  ]
}
```

---

## 4. 후보 상세 (항목별 점수 + 추천 이유)

`GET /api/v1/lost-dogs/{lost_dog_id}/candidates/{notice_id}`

### Response `200` — Candidate 단일 객체 (위 items[0]과 동일 스키마)

---

## 5. 신규 후보 알림 목록

`GET /api/v1/lost-dogs/{lost_dog_id}/notifications`

### Response `200`

```json
{
  "lost_dog_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "items": [
    {
      "id": "ntf-001",
      "lost_dog_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "notice_id": "N20261101001",
      "title": "새로운 유사 후보가 있습니다",
      "body": "크림색 믹스견 공고가 유사 후보로 추가되었습니다. (총점 0.78)",
      "created_at": "2026-11-01T09:15:00+09:00",
      "read": false
    }
  ]
}
```

`POST /api/v1/notifications/{id}/read` — 읽음 처리 (`{"ok": true}`)

---

## 6. 공고 시드/수집 (서버 운영)

- `POST /api/v1/admin/seed` — 예시 공고 적재 (키 없이 시연)
- `POST /api/v1/admin/collect` — 공공 API 수집 (`SERVICE_KEY` 필요)
  - 엔드포인트: `https://apis.data.go.kr/1543061/abandonmentPublicService_v2/abandonmentPublic_v2`
  - 포털: https://www.data.go.kr/data/15098931/openapi.do

---

## 점수 융합 (멀티모달)

최종 `total`은 규칙 항목(품종·색상·거리·날짜·특징·나이)과 AI 항목(이미지·텍스트)을 가중 합산한다.
AI 모델이 없으면 규칙 기반만으로 동작하며 `image`/`text`는 null이 될 수 있다.

가중치 예 (시연용, 조정 가능):

| 항목 | 가중치 |
|------|--------|
| breed | 0.15 |
| color | 0.12 |
| distance | 0.15 |
| date | 0.10 |
| features | 0.10 |
| age | 0.08 |
| image | 0.18 |
| text | 0.12 |

---

## 에러

| 코드 | 의미 |
|------|------|
| 400 | 잘못된 요청 |
| 404 | 실종견/공고 없음 |
| 500 | 서버 오류 |

```json
{ "detail": "lost dog not found" }
```
