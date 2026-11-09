"""이미지 임베딩 — CLIP 또는 open_clip, 없으면 색상 히스토그램 fallback."""

from __future__ import annotations

import io
import math
from typing import Sequence

import httpx

_CLIP = None
_AVAILABLE: bool | None = None


def ai_available() -> bool:
    global _AVAILABLE
    if _AVAILABLE is not None:
        return _AVAILABLE
    try:
        import open_clip  # noqa: F401
        import torch  # noqa: F401
        from PIL import Image  # noqa: F401

        _AVAILABLE = True
    except Exception:
        try:
            from sentence_transformers import SentenceTransformer  # noqa: F401

            _AVAILABLE = True
        except Exception:
            _AVAILABLE = False
    return _AVAILABLE


def _load_clip():
    global _CLIP
    if _CLIP is not None:
        return _CLIP
    try:
        import open_clip
        import torch

        model, _, preprocess = open_clip.create_model_and_transforms(
            "ViT-B-32", pretrained="openai"
        )
        model.eval()
        _CLIP = ("open_clip", model, preprocess, torch)
        return _CLIP
    except Exception:
        from sentence_transformers import SentenceTransformer

        model = SentenceTransformer("clip-ViT-B-32")
        _CLIP = ("st", model, None, None)
        return _CLIP


def _histogram_from_bytes(data: bytes, bins: int = 16) -> list[float]:
    """간단한 RGB 히스토그램 (모델 없을 때)."""
    try:
        from PIL import Image
    except Exception:
        # Pillow 없으면 URL 해시 기반 의사 벡터
        import hashlib

        h = hashlib.sha256(data).digest()
        return [b / 255.0 for b in h[:64]]

    img = Image.open(io.BytesIO(data)).convert("RGB").resize((64, 64))
    pixels = list(img.getdata())
    hist = [0.0] * (bins * 3)
    for r, g, b in pixels:
        hist[r * bins // 256] += 1
        hist[bins + g * bins // 256] += 1
        hist[2 * bins + b * bins // 256] += 1
    n = math.sqrt(sum(x * x for x in hist)) or 1.0
    return [x / n for x in hist]


def _fetch_bytes(url: str) -> bytes | None:
    if not url:
        return None
    try:
        r = httpx.get(url, timeout=10.0, follow_redirects=True)
        if r.status_code == 200:
            return r.content
    except Exception:
        return None
    return None


def embed_image_url(url: str | None) -> list[float] | None:
    if not url:
        return None
    data = _fetch_bytes(url)
    if data is None:
        return None
    if ai_available():
        try:
            kind, model, preprocess, torch = _load_clip()
            from PIL import Image

            img = Image.open(io.BytesIO(data)).convert("RGB")
            if kind == "open_clip":
                import torch as th

                with th.no_grad():
                    t = preprocess(img).unsqueeze(0)
                    feat = model.encode_image(t)
                    feat = feat / feat.norm(dim=-1, keepdim=True)
                    return [float(x) for x in feat[0].tolist()]
            else:
                emb = model.encode([img], normalize_embeddings=True)[0]
                return [float(x) for x in emb]
        except Exception:
            pass
    return _histogram_from_bytes(data)


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
