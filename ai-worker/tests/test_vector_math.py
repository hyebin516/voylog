from app.utils.vector_math import add_scaled, cosine_similarity, normalize


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


def test_add_scaled_adds_the_other_vector_scaled_by_scale():
    assert add_scaled([1.0, 2.0], 0.5, [2.0, 4.0]) == [2.0, 4.0]


def test_add_scaled_with_a_negative_scale_subtracts():
    assert add_scaled([1.0, 1.0], -1.0, [1.0, 1.0]) == [0.0, 0.0]


def test_normalize_scales_a_vector_to_unit_length():
    result = normalize([3.0, 4.0])
    assert round(result[0], 4) == 0.6
    assert round(result[1], 4) == 0.8


def test_normalize_leaves_a_zero_vector_unchanged():
    assert normalize([0.0, 0.0]) == [0.0, 0.0]
