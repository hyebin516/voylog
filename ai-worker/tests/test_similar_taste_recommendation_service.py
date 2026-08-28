from app.schemas.request_schema import SimilarTastePlaceCandidate, SimilarTasteRequest, SimilarTasteUserInput
from app.services import similar_taste_recommendation_service as svc

MY_EMBEDDING = [1.0, 0.0]
SIMILAR_EMBEDDING = [0.95, 0.05]  # cosine similarity with MY_EMBEDDING is well above the 0.3 floor
DISSIMILAR_EMBEDDING = [-1.0, 0.0]  # opposite direction -- similarity -1.0, well below the floor


def place(place_id, name="Place"):
    return SimilarTastePlaceCandidate(placeId=place_id, name=name, latitude=37.5, longitude=127.0, category="cafe")


def user(user_id, embedding, bookmarked_places):
    return SimilarTasteUserInput(userId=user_id, embedding=embedding, bookmarkedPlaces=bookmarked_places)


def test_recommends_places_bookmarked_by_similar_users():
    request = SimilarTasteRequest(
        userEmbedding=MY_EMBEDDING,
        otherUsers=[user("u1", SIMILAR_EMBEDDING, [place("p1")])],
    )

    result = svc.score_similar_taste(request)

    assert [r.placeId for r in result.recommendations] == ["p1"]
    assert result.recommendations[0].contributorCount == 1


def test_excludes_bookmarks_from_users_below_the_similarity_floor():
    request = SimilarTasteRequest(
        userEmbedding=MY_EMBEDDING,
        otherUsers=[user("u1", DISSIMILAR_EMBEDDING, [place("p1")])],
    )

    result = svc.score_similar_taste(request)

    assert result.recommendations == []


def test_skips_other_users_with_no_embedding_at_all():
    request = SimilarTasteRequest(
        userEmbedding=MY_EMBEDDING,
        otherUsers=[user("u1", None, [place("p1")])],
    )

    result = svc.score_similar_taste(request)

    assert result.recommendations == []


def test_a_place_bookmarked_by_multiple_similar_users_scores_higher_and_reports_the_contributor_count():
    popular = place("popular")
    niche = place("niche")
    request = SimilarTasteRequest(
        userEmbedding=MY_EMBEDDING,
        otherUsers=[
            user("u1", SIMILAR_EMBEDDING, [popular]),
            user("u2", SIMILAR_EMBEDDING, [popular, niche]),
        ],
    )

    result = svc.score_similar_taste(request)

    by_id = {r.placeId: r for r in result.recommendations}
    assert by_id["popular"].contributorCount == 2
    assert by_id["niche"].contributorCount == 1
    assert by_id["popular"].score > by_id["niche"].score
    assert result.recommendations[0].placeId == "popular"  # sorted score descending


def test_the_reason_mentions_the_contributor_count():
    request = SimilarTasteRequest(
        userEmbedding=MY_EMBEDDING,
        otherUsers=[user("u1", SIMILAR_EMBEDDING, [place("p1")]), user("u2", SIMILAR_EMBEDDING, [place("p1")])],
    )

    result = svc.score_similar_taste(request)

    assert "2명" in result.recommendations[0].reason


def test_respects_the_limit():
    others = [user(f"u{i}", SIMILAR_EMBEDDING, [place(f"p{i}")]) for i in range(5)]
    request = SimilarTasteRequest(userEmbedding=MY_EMBEDDING, otherUsers=others, limit=2)

    result = svc.score_similar_taste(request)

    assert len(result.recommendations) == 2
