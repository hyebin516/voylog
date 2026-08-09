from typing import List, Optional

from app.utils.vector_math import add_scaled, normalize


def update_preference_embedding(
    current: Optional[List[float]], place_embedding: List[float], weight: float
) -> List[float]:
    """new = normalize(current + weight * place_embedding). When the user has
    no embedding yet (skipped the survey but has behavior history), starts
    from a zero vector so the first behavior alone seeds their preference."""
    base = current if current else [0.0] * len(place_embedding)
    updated = add_scaled(base, weight, place_embedding)
    return normalize(updated)
