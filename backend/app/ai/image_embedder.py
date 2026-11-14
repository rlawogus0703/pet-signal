"""이미지 기반 유사도 (교수님 피드백: 이미지 갈래).

- AI 모드: open_clip(ViT-B-32) 또는 sentence-transformers CLIP 으로 사진 임베딩 → 코사인
  (requirements-ai.txt 를 설치했을 때)
- 기본(경량) 모드: Pillow 만으로 동작하는 '색상 히스토그램 + 차이 해시(dHash)' 특징
  → 노트북(Windows, Python 3.10)에서 무거운 모델 없이도 시연 가능
  웹(web/lib/matching/image_features.dart)도 같은 경량 알고리즘을 씁니다.

임베딩은 방식(method)과 함께 저장하고, 방식이 다른 벡터끼리는 비교하지 않습니다.
"""

from __future__ import annotations

import hashlib
import io
import logging
import math
from pathlib import Path
from typing import Sequence

import httpx

log = logging.getLogger(__name__)

METHOD_CLIP = "clip"
METHOD_LIGHT = "color-hist+dhash"

_CLIP = None
_CLIP_OK: bool | None = None
_FORCE_LIGHT = False

CACHE_DIR = Path(__file__).resolve().parents[2] / "data" / "image_cache"
HTTP_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
    "Referer": "https://www.animal.go.kr/",
}


def force_light_mode(on: bool = True) -> None:
    """테스트·저사양 시연용: CLIP 이 설치돼 있어도 경량 방식만 사용."""
    global _FORCE_LIGHT
    _FORCE_LIGHT = on


def clip_available() -> bool:
    global _CLIP_OK
    if _FORCE_LIGHT:
        return False
    if _CLIP_OK is not None:
        return _CLIP_OK
    try:
        import torch  # noqa: F401
        from PIL import Image  # noqa: F401

        try:
            import open_clip  # noqa: F401
        except Exception:
            from sentence_transformers import SentenceTransformer  # noqa: F401
        _CLIP_OK = True
    except Exception:
        _CLIP_OK = False
    return _CLIP_OK


# 예전 이름 호환
ai_available = clip_available


def current_method() -> str:
    return METHOD_CLIP if clip_available() else METHOD_LIGHT


def pillow_available() -> bool:
    try:
        from PIL import Image  # noqa: F401

        return True
    except Exception:
        return False


def _load_clip():
    global _CLIP
    if _CLIP is not None:
        return _CLIP
    try:
        import open_clip

        model, _, preprocess = open_clip.create_model_and_transforms("ViT-B-32-quickgelu", pretrained="openai")
        model.eval()
        _CLIP = ("open_clip", model, preprocess)
    except Exception:
        from sentence_transformers import SentenceTransformer

        _CLIP = ("st", SentenceTransformer("clip-ViT-B-32"), None)
    return _CLIP


# ── 경량 특징: 64칸 색상 히스토그램 + 64비트 dHash ────────────────
def light_features_from_rgb(pixels: Sequence[tuple[int, int, int]], w: int, h: int) -> list[float]:
    """80x80 RGB 픽셀 → 가운데 64x64 를 잘라 특징 128개.

    앞 64개: R,G,B 각 4단계(4x4x4) 결합 히스토그램 (합 1)
    뒤 64개: 9x8 회색조 격자에서 가로 밝기 차이 비트 (dHash)
    """
    ox, oy = (w - 64) // 2, (h - 64) // 2
    hist = [0.0] * 64
    gray_sum = [[0.0] * 9 for _ in range(8)]
    gray_cnt = [[0] * 9 for _ in range(8)]
    for y in range(64):
        row = (oy + y) * w
        gy = y * 8 // 64
        for x in range(64):
            r, g, b = pixels[row + ox + x][:3]
            hist[(r >> 6) * 16 + (g >> 6) * 4 + (b >> 6)] += 1.0
            gx = x * 9 // 64
            gray_sum[gy][gx] += 0.299 * r + 0.587 * g + 0.114 * b
            gray_cnt[gy][gx] += 1
    total = 64.0 * 64.0
    hist = [v / total for v in hist]
    bits: list[float] = []
    for gy in range(8):
        avg = [gray_sum[gy][gx] / max(1, gray_cnt[gy][gx]) for gx in range(9)]
        for gx in range(8):
            bits.append(1.0 if avg[gx] > avg[gx + 1] else 0.0)
    return hist + bits


def light_features_from_bytes(data: bytes) -> list[float] | None:
    try:
        from PIL import Image

        img = Image.open(io.BytesIO(data)).convert("RGB").resize((80, 80), Image.BILINEAR)
        return light_features_from_rgb(list(img.getdata()), 80, 80)
    except Exception as e:  # 손상 이미지 등
        log.debug("light feature failed: %s", e)
        return None


def light_similarity(a: Sequence[float], b: Sequence[float]) -> float:
    """히스토그램 교집합 0.7 + dHash 유사도 0.3 (우연 수준 0.5 를 0 으로)."""
    inter = sum(min(a[i], b[i]) for i in range(64))
    same = sum(1 for i in range(64, 128) if a[i] == b[i])
    dh = max(0.0, (same / 64.0 - 0.5) * 2.0)
    return max(0.0, min(1.0, 0.7 * inter + 0.3 * dh))


# ── 공통 ──────────────────────────────────────────────────
def embed_bytes(data: bytes) -> tuple[list[float] | None, str]:
    """사진 바이트 → (임베딩, 방식)."""
    if clip_available():
        try:
            from PIL import Image

            kind, model, preprocess = _load_clip()
            img = Image.open(io.BytesIO(data)).convert("RGB")
            if kind == "open_clip":
                import torch

                with torch.no_grad():
                    feat = model.encode_image(preprocess(img).unsqueeze(0))
                    feat = feat / feat.norm(dim=-1, keepdim=True)
                    return [float(x) for x in feat[0].tolist()], METHOD_CLIP
            emb = model.encode([img], normalize_embeddings=True)[0]
            return [float(x) for x in emb], METHOD_CLIP
        except Exception as e:
            log.warning("CLIP embedding failed, falling back: %s", e)
    return light_features_from_bytes(data), METHOD_LIGHT


def similarity(a: Sequence[float] | None, b: Sequence[float] | None, method: str) -> float | None:
    if not a or not b:
        return None
    if method == METHOD_LIGHT:
        if len(a) != 128 or len(b) != 128:
            return None
        return light_similarity(a, b)
    c = cosine(a, b)
    if c is None:
        return None
    # CLIP: 강아지 사진끼리는 0.55 이하가 거의 없어 0.55~0.95 → 0~1 로 폅니다
    return max(0.0, min(1.0, (c - 0.55) / 0.40))


def cosine(a: Sequence[float] | None, b: Sequence[float] | None) -> float | None:
    if a is None or b is None:
        return None
    n = min(len(a), len(b))
    if n == 0:
        return None
    dot = sum(a[i] * b[i] for i in range(n))
    na = math.sqrt(sum(a[i] * a[i] for i in range(n))) or 1.0
    nb = math.sqrt(sum(b[i] * b[i] for i in range(n))) or 1.0
    return max(0.0, min(1.0, float(dot / (na * nb))))


# ── 다운로드 + 디스크 캐시 ─────────────────────────────────
def cache_path_for(url: str) -> Path:
    return CACHE_DIR / (hashlib.sha1(url.encode("utf-8")).hexdigest() + ".img")


def fetch_bytes(
    url: str | None, *, timeout: float = 8.0, client: httpx.Client | None = None, cache: bool = True
) -> bytes | None:
    """URL 또는 로컬 경로의 사진 바이트. 실패하면 None (예외를 밖으로 던지지 않음)."""
    if not url:
        return None
    if not url.startswith("http"):
        p = Path(url)
        try:
            return p.read_bytes() if p.is_file() else None
        except Exception:
            return None
    cp = cache_path_for(url)
    if cp.is_file() and cp.stat().st_size > 0:
        try:
            cached = cp.read_bytes()
            if looks_like_image(cached):
                return cached
        except Exception:
            pass
    for u in candidate_urls(url):
        try:
            if client is not None:
                r = client.get(u, timeout=timeout, follow_redirects=True, headers=HTTP_HEADERS)
            else:
                r = httpx.get(u, timeout=timeout, follow_redirects=True, headers=HTTP_HEADERS)
            if r.status_code != 200 or not r.content:
                continue
            ctype = (r.headers.get("content-type") or "").lower()
            if ("html" in ctype or "xml" in ctype or "json" in ctype or "text/" in ctype) and not looks_like_image(r.content):
                continue
            if not looks_like_image(r.content):
                continue
            if cache:  # 대량 임베딩 때는 디스크에 쌓지 않음 (웹 사진 프록시만 캐시)
                CACHE_DIR.mkdir(parents=True, exist_ok=True)
                cp.write_bytes(r.content)
            return r.content
        except Exception as e:
            log.debug("image fetch failed %s: %s", u, e)
    return None


def looks_like_image(data: bytes | None) -> bool:
    if not data or len(data) < 24:
        return False
    if data[:3] == b"\xff\xd8\xff":
        return True
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return True
    if data[:4] == b"GIF8":
        return True
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return True
    return False


def candidate_urls(url: str) -> list[str]:
    """http/https 를 모두 시도합니다. animal.go.kr 는 http 가 500 을 주는 경우가 많아 https 를 먼저."""
    out: list[str] = []

    def add(u: str) -> None:
        if u and u not in out:
            out.append(u)

    if url.startswith("http://"):
        add("https://" + url[len("http://") :])
        add(url)
    elif url.startswith("https://"):
        add(url)
        add("http://" + url[len("https://") :])
    else:
        add(url)
    return out


def embed_image_url(url: str | None) -> list[float] | None:
    """예전 API 호환: URL → 임베딩."""
    data = fetch_bytes(url)
    if data is None:
        return None
    emb, _ = embed_bytes(data)
    return emb
