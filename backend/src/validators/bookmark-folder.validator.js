const AppError = require('../utils/AppError');
const isUuid = require('../utils/isUuid');

function validateCreateFolder(req, res, next) {
  const { name } = req.body;
  if (!name || typeof name !== 'string' || !name.trim()) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A non-empty folder name is required'));
  }
  return next();
}

function validateFolderId(req, res, next) {
  if (!isUuid(req.params.id)) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A valid folder id is required'));
  }
  return next();
}

function validateFolderBookmarkBody(req, res, next) {
  // 폴더에 넣는 방법은 두 가지다. 이미 북마크한 장소를 고르거나
  // (bookmarkId), 카카오 검색 결과를 그대로 넣거나(place). 후자는 아직
  // places에 없는 장소라 서버가 적재한 뒤 북마크까지 만들어 준다.
  const { bookmarkId, place } = req.body;

  if (place !== undefined) {
    if (!place || typeof place !== 'object') {
      return next(new AppError(400, 'INVALID_REQUEST', 'place must be an object'));
    }
    if (typeof place.name !== 'string' || place.name.trim().length === 0) {
      return next(new AppError(400, 'INVALID_REQUEST', 'place.name is required'));
    }
    if (typeof place.kakaoPlaceId !== 'string' || place.kakaoPlaceId.trim().length === 0) {
      return next(new AppError(400, 'INVALID_REQUEST', 'place.kakaoPlaceId is required'));
    }
    // 좌표가 없으면 지도에도 못 찍고 동선에도 못 넣는다.
    if (!Number.isFinite(place.latitude) || !Number.isFinite(place.longitude)) {
      return next(new AppError(400, 'INVALID_REQUEST', 'place.latitude and place.longitude are required'));
    }
    return next();
  }

  if (!isUuid(bookmarkId)) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A valid bookmarkId or place is required'));
  }
  return next();
}

function validateFolderBookmarkId(req, res, next) {
  if (!isUuid(req.params.bookmarkId)) {
    return next(new AppError(400, 'INVALID_REQUEST', 'A valid bookmark id is required'));
  }
  return next();
}

module.exports = { validateCreateFolder, validateFolderId, validateFolderBookmarkBody, validateFolderBookmarkId };
