"""Fixed detailed-tag vocabulary shared by LLM place-tag extraction and the
Flutter taste survey (travel_youtube_app/lib/core/constants/
taste_preference_options.dart mirrors this exact list). Keeping both sides
on one fixed list -- instead of letting the LLM invent tags -- is what makes
tag matching between a user's preferences and a place possible without a
normalized tags table (see migration 013's comment).
"""

TAG_CATALOG = {
    "menu": ["베이커리 카페", "소금빵", "크루아상", "케이크", "베이글", "브런치", "스페셜티 커피", "디저트", "맛집"],
    "photo": ["포토존", "통창", "루프탑", "정원", "오션뷰", "야경"],
    "interior": ["감성 인테리어", "화이트톤", "빈티지"],
    "purpose": ["공부 작업", "데이트", "대화하기 좋은 곳", "전시 갤러리"],
    "mood": ["조용한 분위기", "이색적인 곳"],
}

ALL_TAG_CODES = [code for codes in TAG_CATALOG.values() for code in codes]
