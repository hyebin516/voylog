// 카카오 검색으로 찾은 장소를 폴더에 넣는 경로.
jest.mock('../src/repositories/bookmark-folder.repository');
jest.mock('../src/repositories/bookmark.repository');
jest.mock('../src/repositories/kakao-place.repository');

const folderRepository = require('../src/repositories/bookmark-folder.repository');
const bookmarkRepository = require('../src/repositories/bookmark.repository');
const kakaoPlaceRepository = require('../src/repositories/kakao-place.repository');
const service = require('../src/services/bookmark-folder.service');

const PLACE = {
  kakaoPlaceId: '1234',
  name: '카페덕덕',
  address: '강원 강릉시',
  latitude: 37.79,
  longitude: 128.91,
};

beforeEach(() => {
  jest.resetAllMocks();
  folderRepository.findById.mockResolvedValue({ folder_id: 'f1', user_id: 'u1' });
  kakaoPlaceRepository.upsertAll.mockResolvedValue(new Map([['1234', 'p-new']]));
  folderRepository.addItem.mockResolvedValue(undefined);
});

describe('addSearchedPlaceToFolder', () => {
  it('장소를 적재하고 북마크를 만들어 폴더에 넣는다', async () => {
    bookmarkRepository.findByUserAndPlace.mockResolvedValue(null);
    bookmarkRepository.create.mockResolvedValue({ bookmark_id: 'b-new' });

    const result = await service.addSearchedPlaceToFolder('u1', 'f1', PLACE);

    expect(kakaoPlaceRepository.upsertAll).toHaveBeenCalledWith([
      expect.objectContaining({ externalId: '1234', name: '카페덕덕' }),
    ]);
    expect(folderRepository.addItem).toHaveBeenCalledWith('f1', 'b-new');
    expect(result).toEqual({ bookmarkId: 'b-new', placeId: 'p-new' });
  });

  it('이미 북마크한 장소면 그 북마크를 다시 쓴다', async () => {
    // 폴더는 북마크를 가리키는 다대다 태그라, 같은 장소로 북마크가 둘
    // 생기면 한쪽만 폴더에 들어간 것처럼 보인다.
    bookmarkRepository.findByUserAndPlace.mockResolvedValue({ bookmark_id: 'b-old' });

    const result = await service.addSearchedPlaceToFolder('u1', 'f1', PLACE);

    expect(bookmarkRepository.create).not.toHaveBeenCalled();
    expect(folderRepository.addItem).toHaveBeenCalledWith('f1', 'b-old');
    expect(result.bookmarkId).toBe('b-old');
  });

  it('남의 폴더에는 넣지 못한다', async () => {
    folderRepository.findById.mockResolvedValue({ folder_id: 'f1', user_id: 'someone-else' });

    await expect(service.addSearchedPlaceToFolder('u1', 'f1', PLACE)).rejects.toMatchObject({
      statusCode: 404,
      code: 'FOLDER_NOT_FOUND',
    });
    expect(kakaoPlaceRepository.upsertAll).not.toHaveBeenCalled();
  });
});
