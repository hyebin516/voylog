import math
from typing import List, Optional


def cosine_similarity(a: List[float], b: List[float]) -> Optional[float]:
    """Returns None (rather than raising) for mismatched/empty vectors, since
    callers treat "can't compare" the same as "no embedding available"."""
    if not a or not b or len(a) != len(b):
        return None

    dot = sum(x * y for x, y in zip(a, b))
    norm_a = math.sqrt(sum(x * x for x in a))
    norm_b = math.sqrt(sum(y * y for y in b))
    if norm_a == 0 or norm_b == 0:
        return None

    return dot / (norm_a * norm_b)


def add_scaled(base: List[float], scale: float, other: List[float]) -> List[float]:
    """base + scale * other, elementwise. Assumes equal-length vectors."""
    return [b + scale * o for b, o in zip(base, other)]


def normalize(vector: List[float]) -> List[float]:
    norm = math.sqrt(sum(x * x for x in vector))
    if norm == 0:
        return vector
    return [x / norm for x in vector]
