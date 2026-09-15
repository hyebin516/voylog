/**
 * The text a place's embedding is generated from. One definition shared by
 * every path that embeds places (video analysis, lazy embedding of
 * public-dataset places), so the same place always gets the same vector and
 * `place_embeddings.source_text_hash` stays comparable.
 */
function buildPlaceEmbeddingText(place) {
  return [place.name, place.category, place.address].filter(Boolean).join(' | ');
}

module.exports = { buildPlaceEmbeddingText };
