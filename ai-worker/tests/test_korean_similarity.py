from app.utils.korean_similarity import similar_written_words, sound_similarity


def test_a_misheard_vowel_or_final_consonant_stays_close():
    assert sound_similarity("소배", "소베") >= 0.7
    assert sound_similarity("보음바", "보흔바") >= 0.7
    assert sound_similarity("몬도카츠", "몬도 카츠") == 1.0


def test_different_words_are_far_apart():
    assert sound_similarity("소배", "소품샵") < 0.7
    assert sound_similarity("소배", "서문시장") < 0.7


def test_similar_written_words_finds_the_written_spelling_in_a_title():
    title = "나혼자 대구 당일치기••기차타고 뚜벅이 여행,혼술🍺,소품샵 투어,서문시장 납작만두 먹고 소베,히오리"

    assert similar_written_words("소배", title) == ["소베"]
    assert similar_written_words("히오이", title) == ["히오리"]
    assert similar_written_words("서문시장", title) == []  # the same word isn't an alternative


def test_names_plausibly_same_accepts_branches_spacing_and_landmark_variants():
    from app.utils.korean_similarity import names_plausibly_same

    assert names_plausibly_same("몬도 카츠", "몬도카츠 범어점")
    assert names_plausibly_same("데코와 삼덕점", "데코와 삼덕점")
    assert names_plausibly_same("따끈따끈 베이커리", "따끈따끈베이커리")
    assert names_plausibly_same("남산서울타워", "N서울타워")
    assert names_plausibly_same("해운대해수욕장", "해운대해수욕장")


def test_names_plausibly_same_rejects_a_different_business():
    from app.utils.korean_similarity import names_plausibly_same

    assert not names_plausibly_same("vaca", "보카바카 현대백화점 대구점")
    assert not names_plausibly_same("보흔바", "봄바")
