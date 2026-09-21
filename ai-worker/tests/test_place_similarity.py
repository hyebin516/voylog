from types import SimpleNamespace

from app.utils.place_similarity import collapse_same_spots, is_same_spot, names_overlap


def _place(name, lat, category="attraction", lng=127.0):
    return SimpleNamespace(name=name, latitude=lat, longitude=lng, category=category)


def test_names_overlap_by_containment_or_long_shared_prefix():
    assert names_overlap("케이락", "케이락볼링장")
    assert names_overlap("제주동문시장", "제주동문공설시장")
    assert names_overlap("제주동문수산시장", "제주동문재래야시장")
    assert not names_overlap("부산커피박물관", "부산포민속박물관")
    assert not names_overlap("서울숲아트센터", "서울숲공원")
    assert not names_overlap("카페", "카페봄")  # too short to count as containment
    assert not names_overlap("서울숲", "서울숲아트센터")  # a different place beside the park
    assert not names_overlap("경복궁", "한복남 경복궁점")  # a shop named after the palace


def test_same_spot_needs_same_category_and_proximity():
    assert is_same_spot(_place("케이락", 37.5), _place("케이락볼링장", 37.501))
    assert not is_same_spot(_place("제주동문시장", 37.5, "other"), _place("동문시장 과일모찌", 37.5, "cafe"))
    assert not is_same_spot(_place("케이락", 37.5), _place("케이락볼링장", 37.51))  # ~1.1km


def test_collapse_keeps_the_first_of_each_spot():
    ranked = [_place("제주동문시장", 37.5, "other"), _place("제주동문공설시장", 37.5005, "other"), _place("갤러리", 37.5)]

    assert [p.name for p in collapse_same_spots(ranked)] == ["제주동문시장", "갤러리"]
