const sharedRouteRepository = require('../repositories/shared-route.repository');
const routeLikeRepository = require('../repositories/route-like.repository');
const tastePreferenceRepository = require('../repositories/taste-preference.repository');
const behaviorService = require('./behavior.service');
const { callAiWorker } = require('./aiWorkerClient');
const AppError = require('../utils/AppError');
const isUuid = require('../utils/isUuid');

function withoutMatchPercent(rows) {
  return rows.map((row) => ({ ...row, match_percent: null }));
}

// "취향 일치 N%" mirrors the FR-18 "취향이 비슷한 사람들" chip already shown
// right above this feed on the home screen (same clamp-to-[0,1]-then-round
// treatment) -- here it's author-vs-viewer taste similarity rather than
// place-vs-viewer, since a shared route has no single embedding of its own.
// The feed includes the viewer's own posts (so they can see/manage what
// they've published), but self-similarity is meaningless, so the viewer is
// excluded from the AI Worker batch -- their row just never gets a match_percent.
async function getSharedRouteFeed({ viewerUserId, limit }) {
  const rows = await sharedRouteRepository.findFeed({ viewerUserId, limit });
  if (!viewerUserId || rows.length === 0) {
    return withoutMatchPercent(rows);
  }

  const myPreference = await tastePreferenceRepository.find(viewerUserId);
  if (!myPreference || !myPreference.embedding) {
    return withoutMatchPercent(rows);
  }

  const authorIds = [...new Set(rows.map((row) => row.user_id))].filter((id) => id !== viewerUserId);
  const authorPreferences = await tastePreferenceRepository.findByUserIds(authorIds);
  if (authorPreferences.length === 0) {
    return withoutMatchPercent(rows);
  }

  const similarityResult = await callAiWorker(
    '/embeddings/similarity',
    {
      embeddingA: myPreference.embedding,
      embeddingsB: authorPreferences.map((pref) => ({ key: pref.user_id, embedding: pref.embedding })),
    },
    10000
  );

  const scoreByAuthorId = new Map(similarityResult.similarities.map((s) => [s.key, s.score]));

  return rows.map((row) => {
    const score = scoreByAuthorId.get(row.user_id);
    return {
      ...row,
      match_percent: score != null ? Math.round(Math.min(1, Math.max(0, score)) * 100) : null,
    };
  });
}

async function getOwnedSharedRoute(userId, sharedRouteId) {
  const route = await sharedRouteRepository.findById(sharedRouteId);
  if (!route || route.user_id !== userId) {
    throw new AppError(404, 'SHARED_ROUTE_NOT_FOUND', 'Shared route not found');
  }
  return route;
}

async function updateTitle(userId, sharedRouteId, title) {
  await getOwnedSharedRoute(userId, sharedRouteId);
  return sharedRouteRepository.updateTitle(sharedRouteId, title);
}

async function unpublish(userId, sharedRouteId) {
  await getOwnedSharedRoute(userId, sharedRouteId);
  await sharedRouteRepository.softDelete(sharedRouteId);
}

// A route-like is treated as liking each of its constituent places -- it
// reuses the exact same FR-15 pipeline (recommendation_behaviors row +
// decayed preference-embedding/tag_scores nudge) a direct place "like"
// would trigger, since the route_data snapshot kept each place's id
// specifically for this (see route-snapshot.js).
//
// Walking-course routes can include Kakao 상권 검색 candidates that were
// never actually saved to `places` (FR-17) -- their id isn't a real
// `places.place_id` UUID at all (e.g. "kakao:7913306"), so it's filtered
// out here rather than sent into a `place_id = ANY($1::uuid[])` query that
// would throw. Best-effort beyond that too: the "like" itself must never
// fail just because the taste-weight nudge couldn't be applied (AI Worker
// hiccup, a place missing its embedding, etc.) -- same philosophy as
// embedding generation elsewhere in this codebase never blocking the main flow.
function routePlaceIds(route) {
  return (route.route_data || [])
    .filter((point) => point.type === 'place' && point.placeId && isUuid(point.placeId))
    .map((point) => point.placeId);
}

async function applyTasteWeightForRouteLike(userId, route) {
  try {
    await Promise.all(
      routePlaceIds(route).map((placeId) =>
        behaviorService.recordBehavior(userId, { placeId, action: 'like', screen: 'shared_route_feed' })
      )
    );
  } catch (err) {
    console.warn('shared-route like: taste-weight update failed (non-fatal)', err);
  }
}

// Undoes `applyTasteWeightForRouteLike` (best-effort, same non-fatal
// philosophy) -- see behavior.service.js's `reverseScopedBehavior` doc
// comment for why this is an approximation rather than a mathematically
// exact undo once other actions have happened in between.
async function reverseTasteWeightForRouteUnlike(userId, route) {
  try {
    await Promise.all(
      routePlaceIds(route).map((placeId) =>
        behaviorService.reverseScopedBehavior(userId, placeId, 'like', 'shared_route_feed')
      )
    );
  } catch (err) {
    console.warn('shared-route unlike: taste-weight reversal failed (non-fatal)', err);
  }
}

async function like(userId, sharedRouteId) {
  const route = await sharedRouteRepository.findById(sharedRouteId);
  if (!route) {
    throw new AppError(404, 'SHARED_ROUTE_NOT_FOUND', 'Shared route not found');
  }
  if (route.user_id === userId) {
    throw new AppError(400, 'INVALID_REQUEST', 'Cannot like your own shared route');
  }

  await routeLikeRepository.like(userId, sharedRouteId);
  await applyTasteWeightForRouteLike(userId, route);
}

async function unlike(userId, sharedRouteId) {
  await routeLikeRepository.unlike(userId, sharedRouteId);

  const route = await sharedRouteRepository.findById(sharedRouteId);
  if (route) {
    await reverseTasteWeightForRouteUnlike(userId, route);
  }
}

module.exports = { getSharedRouteFeed, getOwnedSharedRoute, updateTitle, unpublish, like, unlike };
