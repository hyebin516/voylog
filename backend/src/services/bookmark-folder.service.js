const folderRepository = require('../repositories/bookmark-folder.repository');
const bookmarkRepository = require('../repositories/bookmark.repository');
const kakaoPlaceRepository = require('../repositories/kakao-place.repository');
const { callAiWorker } = require('./aiWorkerClient');
const AppError = require('../utils/AppError');

async function getOwnedFolder(userId, folderId) {
  const folder = await folderRepository.findById(folderId);
  if (!folder || folder.user_id !== userId) {
    throw new AppError(404, 'FOLDER_NOT_FOUND', 'Bookmark folder not found');
  }
  return folder;
}

async function getOwnedBookmark(userId, bookmarkId) {
  const bookmark = await bookmarkRepository.findById(bookmarkId);
  if (!bookmark || bookmark.user_id !== userId) {
    throw new AppError(404, 'BOOKMARK_NOT_FOUND', 'Bookmark not found');
  }
  return bookmark;
}

async function createFolder(userId, name) {
  return folderRepository.create(userId, name);
}

async function listFolders(userId) {
  return folderRepository.findAllByUser(userId);
}

async function deleteFolder(userId, folderId) {
  await getOwnedFolder(userId, folderId);
  await folderRepository.softDelete(folderId);
}

async function addBookmarkToFolder(userId, folderId, bookmarkId) {
  await getOwnedFolder(userId, folderId);
  await getOwnedBookmark(userId, bookmarkId);
  await folderRepository.addItem(folderId, bookmarkId);
}

/**
 * 카카오 검색으로 찾은 장소를 폴더에 넣는다.
 *
 * 그 장소는 아직 `places`에 없으므로 먼저 적재한다 -- 북마크는 place_id를
 * 가리키는 외래키라 행이 없으면 넣을 수 없다. 적재는 뚜벅이 코스를 보관할
 * 때 쓰는 것과 같은 (source, external_id) 멱등 upsert라, 같은 장소를 두
 * 번 담아도 행이 늘지 않는다.
 *
 * 카테고리와 주소는 검색 결과에 있는 만큼만 채워진다(카카오 키워드 검색은
 * 카테고리를 주지 않는 경우가 있다).
 */
async function addSearchedPlaceToFolder(userId, folderId, place) {
  await getOwnedFolder(userId, folderId);

  const ids = await kakaoPlaceRepository.upsertAll([
    {
      externalId: place.kakaoPlaceId,
      name: place.name,
      address: place.address ?? null,
      latitude: place.latitude,
      longitude: place.longitude,
      category: place.category ?? null,
    },
  ]);
  const placeId = ids.get(place.kakaoPlaceId);

  // 이미 북마크한 장소면 그 북마크를 그대로 쓴다. bookmarkService.addBookmark는
  // 중복이면 409를 던지는데, 여기서는 "이미 담아둔 곳을 폴더에도 넣는" 정상
  // 동작이라 에러가 아니다. 폴더는 북마크를 가리키는 다대다 태그라 같은
  // 장소로 북마크가 둘 생기면 한쪽만 폴더에 들어간 것처럼 보인다.
  const existing = await bookmarkRepository.findByUserAndPlace(userId, placeId);
  const bookmark = existing ?? (await bookmarkRepository.create(userId, placeId));
  await folderRepository.addItem(folderId, bookmark.bookmark_id);
  return { bookmarkId: bookmark.bookmark_id, placeId };
}

async function removeBookmarkFromFolder(userId, folderId, bookmarkId) {
  await getOwnedFolder(userId, folderId);
  await folderRepository.removeItem(folderId, bookmarkId);
}

async function listBookmarksInFolder(userId, folderId) {
  await getOwnedFolder(userId, folderId);
  return folderRepository.findBookmarksInFolder(folderId);
}

// Enough stops to be a route at all, and the ceiling the optimizer works
// within -- same bounds as a trip day's route (FR-07).
const MIN_ROUTE_PLACES = 2;
const MAX_ROUTE_PLACES = 10;

/**
 * Builds a route straight from a folder's bookmarks (FR-11): no hotel and no
 * trip, the folder itself is the plan.
 *
 * The AI Worker orders the places for the least total travel time as an
 * open path -- first and last stop are whichever places make that shortest,
 * not a loop back to some centre point -- and each leg is walked when that
 * takes at most 15 minutes, otherwise taken by bus when there is one (with
 * the bus number and stops). A pure walking route had folders spanning a
 * city asking for hour-long walks between stops.
 * Places without coordinates can't be routed through and are left out.
 */
async function createRouteFromFolder(userId, folderId) {
  await getOwnedFolder(userId, folderId);
  const bookmarks = await folderRepository.findBookmarksInFolder(folderId);

  const places = bookmarks
    .filter((b) => b.latitude != null && b.longitude != null)
    .slice(0, MAX_ROUTE_PLACES)
    .map((b) => ({
      placeId: b.place_id,
      name: b.name,
      latitude: Number(b.latitude),
      longitude: Number(b.longitude),
    }));

  if (places.length < MIN_ROUTE_PLACES) {
    throw new AppError(
      400,
      'INVALID_REQUEST',
      'A route needs at least 2 bookmarked places with coordinates'
    );
  }

  const route = await callAiWorker('/optimize-place-route', { places }, 30000);

  // Shaped like the 뚜벅이 코스 result so the app renders it with the same
  // screen. `recommendations` stays empty: these places were chosen by the
  // user, not scored by us, so there is nothing to explain.
  return { course: route, recommendations: [] };
}

module.exports = {
  getOwnedFolder,
  createRouteFromFolder,
  createFolder,
  listFolders,
  deleteFolder,
  addBookmarkToFolder,
  addSearchedPlaceToFolder,
  removeBookmarkFromFolder,
  listBookmarksInFolder,
};
