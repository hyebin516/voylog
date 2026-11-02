// 폴더에 장소를 넣기 위한 검색: 내 북마크와 카카오 결과를 한 번에 돌려준다.
jest.mock('../src/repositories/bookmark.repository');
jest.mock('../src/services/aiWorkerClient');

const bookmarkRepository = require('../src/repositories/bookmark.repository');
const { callAiWorker } = require('../src/services/aiWorkerClient');
const placeSearchService = require('../src/services/place-search.service');

const bookmarkRow = (over = {}) => ({
  bookmark_id: 'b1',
  place_id: 'p1',
  name: '초당순두부',
  address: '강원 강릉시',
  latitude: 37.8,
  longitude: 128.9,
  category: 'restaurant',
  source: 'transcript',
  external_id: null,
  ...over,
});

const kakaoCandidate = (over = {}) => ({
  placeId: '1234',
  name: '카페덕덕',
  address: '강원 강릉시',
  latitude: 37.79,
  longitude: 128.91,
  ...over,
});

beforeEach(() => jest.resetAllMocks());

describe('searchForFolder', () => {
  it('내 북마크와 카카오 결과를 함께 돌려준다', async () => {
    bookmarkRepository.findAllByUser.mockResolvedValue([bookmarkRow()]);
    callAiWorker.mockResolvedValue({ candidates: [kakaoCandidate()] });

    const results = await placeSearchService.searchForFolder('u1', '초당');

    expect(results.map((r) => r.origin)).toEqual(['bookmark', 'kakao']);
    expect(results[0].bookmarkId).toBe('b1');
    expect(results[1].kakaoPlaceId).toBe('1234');
  });

  it('이미 북마크한 곳은 카카오 결과에서 뺀다', async () => {
    // 같은 가게가 두 줄로 보이면 어느 쪽을 눌러야 하는지 알 수 없다.
    bookmarkRepository.findAllByUser.mockResolvedValue([
      bookmarkRow({ name: '카페덕덕', source: 'kakao_local', external_id: '1234' }),
    ]);
    callAiWorker.mockResolvedValue({ candidates: [kakaoCandidate()] });

    const results = await placeSearchService.searchForFolder('u1', '카페덕덕');

    expect(results).toHaveLength(1);
    expect(results[0].origin).toBe('bookmark');
  });

  it('검색어와 상관없는 북마크는 빼고 보여준다', async () => {
    bookmarkRepository.findAllByUser.mockResolvedValue([
      bookmarkRow({ name: '경포대' }),
      bookmarkRow({ bookmark_id: 'b2', place_id: 'p2', name: '초당순두부' }),
    ]);
    callAiWorker.mockResolvedValue({ candidates: [] });

    const results = await placeSearchService.searchForFolder('u1', '순두부');

    expect(results.map((r) => r.name)).toEqual(['초당순두부']);
  });

  it('카카오가 실패해도 북마크 결과는 보여준다', async () => {
    // 검색 전체가 실패하는 것보다 반쪽이라도 쓰는 편이 낫다.
    bookmarkRepository.findAllByUser.mockResolvedValue([bookmarkRow()]);
    callAiWorker.mockRejectedValue(new Error('kakao down'));

    const results = await placeSearchService.searchForFolder('u1', '초당');

    expect(results).toHaveLength(1);
    expect(results[0].origin).toBe('bookmark');
  });
});
