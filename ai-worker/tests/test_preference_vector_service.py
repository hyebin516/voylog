from app.services import preference_vector_service


def test_starts_from_zero_vector_when_the_user_has_no_current_embedding():
    result = preference_vector_service.update_preference_embedding(None, [1.0, 0.0], 1.0)
    assert result == [1.0, 0.0]


def test_positive_weight_moves_the_vector_toward_the_place_embedding():
    result = preference_vector_service.update_preference_embedding([1.0, 0.0], [0.0, 1.0], 1.0)
    # normalize(1,0) + 1*(0,1) = normalize(1,1)
    assert round(result[0], 4) == round(result[1], 4) == round(1 / (2**0.5), 4)


def test_negative_weight_moves_the_vector_away_from_the_place_embedding():
    result = preference_vector_service.update_preference_embedding([1.0, 0.0], [1.0, 0.0], -0.5)
    # normalize(1,0) - 0.5*(1,0) = normalize(0.5, 0) = (1, 0)
    assert round(result[0], 4) == 1.0
    assert round(result[1], 4) == 0.0


def test_result_is_always_unit_length():
    result = preference_vector_service.update_preference_embedding([2.0, 0.0], [0.0, 3.0], 0.7)
    magnitude = sum(x * x for x in result) ** 0.5
    assert round(magnitude, 4) == 1.0
