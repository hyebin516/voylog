const bookmarkRepository = require('../repositories/bookmark.repository');
const { callAiWorker } = require('./aiWorkerClient');

// 카카오에서 받아올 개수. 화면에 한 번에 보여줄 만큼만 -- 더 받아봐야
// 스크롤 아래로 내려가고 호출 비용만 늘어난다.
const KAKAO_RESULT_SIZE = 10;

/**
 * 폴더에 장소를 넣을 때 쓰는 검색.
 *
 * 한 번의 검색으로 두 가지를 돌려준다 -- 이미 북마크해 둔 장소 중 이름이나
 * 주소가 걸리는 것과, 카카오 키워드 검색 결과. 화면에 검색창이 하나뿐이라
 * 사용자는 "내가 담아둔 곳"과 "새로 찾는 곳"을 구분해 생각할 필요가 없다.
 *
 * 이미 북마크한 장소가 카카오 결과에도 있으면 북마크 쪽만 남긴다. 같은
 * 가게가 두 줄로 보이면 어느 쪽을 눌러야 하는지 알 수 없다.
 */
async function searchForFolder(userId, query) {
  const needle = query.trim().toLowerCase();

  const bookmarks = await bookmarkRepository.findAllByUser(userId);
  const matchedBookmarks = bookmarks
    .filter((row) => {
      const name = (row.name || '').toLowerCase();
      const address = (row.address || '').toLowerCase();
      return name.includes(needle) || address.includes(needle);
    })
    .map((row) => ({
      origin: 'bookmark',
      bookmarkId: row.bookmark_id,
      placeId: row.place_id,
      kakaoPlaceId: row.source === 'kakao_local' ? row.external_id : null,
      name: row.name,
      address: row.address,
      latitude: row.latitude != null ? Number(row.latitude) : null,
      longitude: row.longitude != null ? Number(row.longitude) : null,
      category: row.category,
    }));

  let candidates = [];
  try {
    const result = await callAiWorker('/geocode/search', { query, size: KAKAO_RESULT_SIZE }, 10000);
    candidates = result.candidates || [];
  } catch (err) {
    // 카카오가 답하지 않아도 북마크 쪽 결과는 보여준다. 검색 전체가
    // 실패하는 것보다 반쪽이라도 쓰는 편이 낫다.
    candidates = [];
  }

  const bookmarkedKakaoIds = new Set(matchedBookmarks.map((b) => b.kakaoPlaceId).filter(Boolean));
  const bookmarkedNames = new Set(matchedBookmarks.map((b) => (b.name || '').trim()));

  const fromKakao = candidates
    .filter((c) => !bookmarkedKakaoIds.has(c.placeId) && !bookmarkedNames.has((c.name || '').trim()))
    .map((c) => ({
      origin: 'kakao',
      bookmarkId: null,
      placeId: null,
      kakaoPlaceId: c.placeId,
      name: c.name,
      address: c.address ?? null,
      latitude: c.latitude,
      longitude: c.longitude,
      category: null,
    }));

  return [...matchedBookmarks, ...fromKakao];
}

module.exports = { searchForFolder, KAKAO_RESULT_SIZE };
