from app.utils.vector_math import cosine_similarity


def test_identical_vectors_have_similarity_one():
    assert cosine_similarity([1.0, 0.0], [1.0, 0.0]) == 1.0


def test_opposite_vectors_have_similarity_negative_one():
    assert cosine_similarity([1.0, 0.0], [-1.0, 0.0]) == -1.0


def test_orthogonal_vectors_have_similarity_zero():
    assert cosine_similarity([1.0, 0.0], [0.0, 1.0]) == 0.0


def test_returns_none_for_empty_vectors():
    assert cosine_similarity([], [1.0, 0.0]) is None
    assert cosine_similarity([1.0, 0.0], []) is None


def test_returns_none_for_mismatched_dimensions():
    assert cosine_similarity([1.0, 0.0], [1.0, 0.0, 0.0]) is None


def test_returns_none_for_a_zero_vector():
    assert cosine_similarity([0.0, 0.0], [1.0, 0.0]) is None
