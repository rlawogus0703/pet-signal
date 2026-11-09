"""텍스트 임베딩 — sentence-transformers 사용, 없으면 키워드 벡터 fallback."""

from __future__ import annotations

import hashlib
import math
from typing import Sequence

from app.services.normalizer import feature_tokens

_MODEL = None
_MODEL_NAME = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
_AVAILABLE: bool | None = None


def ai_available() -> bool:
    global _AVAILABLE
    if _AVAILABLE is not None:
        return _AVAILABLE
    try:
        import sentence_transformers  # noqa: F401

        _AVAILABLE = True
    except Exception:
        _AVAILABLE = False
    return _AVAILABLE


def _get_model():
    global _MODEL
    if _MODEL is None:
        from sentence_transformers import SentenceTransformer

        _MODEL = SentenceTransformer(_MODEL_NAME)
    return _MODEL


def _hash_vec(tokens: Sequence[str], dim: int = 64) -> list[float]:
    vec = [0.0] * dim
    if not tokens:
        return vec
    for t in tokens:
        h = int(hashlib.md5(t.encode("utf-8")).hexdigest(), 16)
        vec[h % dim] += 1.0
    # L2 norm
    n = math.sqrt(sum(x * x for x in vec)) or 1.0
    return [x / n for x in vec]


def embed_text(text: str) -> list[float]:
    text = (text or "").strip()
    if ai_available() and text:
        try:
            model = _get_model()
            emb = model.encode([text], normalize_embeddings=True)[0]
            return [float(x) for x in emb]
        except Exception:
            pass
    return _hash_vec(feature_tokens(text))


def cosine(a: Sequence[float], b: Sequence[float]) -> float:
    if not a or not b:
        return 0.0
    n = min(len(a), len(b))
    if n == 0:
        return 0.0
    dot = sum(a[i] * b[i] for i in range(n))
    na = math.sqrt(sum(a[i] * a[i] for i in range(n))) or 1.0
    nb = math.sqrt(sum(b[i] * b[i] for i in range(n))) or 1.0
    return max(0.0, min(1.0, dot / (na * nb)))
