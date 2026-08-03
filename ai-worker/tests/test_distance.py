from app.utils.distance import haversine_distance_m


def test_same_point_is_zero_distance():
    assert haversine_distance_m(37.5665, 126.9780, 37.5665, 126.9780) == 0


def test_seoul_to_busan_is_roughly_correct():
    # Seoul City Hall -> Busan City Hall, real-world distance is ~325km great-circle.
    seoul = (37.5665, 126.9780)
    busan = (35.1796, 129.0756)
    distance_m = haversine_distance_m(*seoul, *busan)
    assert 300_000 < distance_m < 350_000


def test_distance_is_symmetric():
    a = (37.5, 127.0)
    b = (35.2, 129.1)
    assert haversine_distance_m(*a, *b) == haversine_distance_m(*b, *a)
