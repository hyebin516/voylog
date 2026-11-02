// 컨트롤러가 실제로 응답을 만들어 내보내는지 본다.
//
// 서비스 테스트만 있던 탓에 `success(res, data)` 헬퍼를 객체 생성 함수처럼
// 쓴 것(`res.json(success({...}))`)이 배포될 때까지 드러나지 않았다. 서버는
// 500 "res.status is not a function"을 돌려주고 있었다.
jest.mock('../src/services/place-search.service');
jest.mock('../src/services/place-summary.service');

const placeSearchService = require('../src/services/place-search.service');
const controller = require('../src/controllers/place.controller');

function fakeRes() {
  const res = {};
  res.statusCode = 200;
  res.body = null;
  res.status = jest.fn((code) => {
    res.statusCode = code;
    return res;
  });
  res.json = jest.fn((payload) => {
    res.body = payload;
    return res;
  });
  return res;
}

beforeEach(() => jest.resetAllMocks());

describe('GET /places/search', () => {
  it('표준 성공 응답 형태로 내보낸다', async () => {
    placeSearchService.searchForFolder.mockResolvedValue([{ origin: 'kakao', name: '전주객사' }]);
    const res = fakeRes();

    await controller.search({ user: { userId: 'u1' }, query: { query: '전주' } }, res, jest.fn());

    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual({
      success: true,
      data: { places: [{ origin: 'kakao', name: '전주객사' }] },
    });
  });

  it('결과가 없어도 배열 필드는 존재한다', async () => {
    // CLAUDE.md: 배열 필드는 비어 있어도 [] 로 존재해야 한다.
    placeSearchService.searchForFolder.mockResolvedValue([]);
    const res = fakeRes();

    await controller.search({ user: { userId: 'u1' }, query: { query: 'zzz' } }, res, jest.fn());

    expect(res.body.data.places).toEqual([]);
  });

  it('서비스가 실패하면 에러 처리로 넘긴다', async () => {
    placeSearchService.searchForFolder.mockRejectedValue(new Error('boom'));
    const next = jest.fn();

    await controller.search({ user: { userId: 'u1' }, query: { query: '전주' } }, fakeRes(), next);

    expect(next).toHaveBeenCalledWith(expect.any(Error));
  });
});
