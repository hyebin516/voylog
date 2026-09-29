const kakaoPlaceRepository = require('../../src/repositories/kakao-place.repository');
const { materializeRoutePlaces } = require('../../src/services/kakao-place.service');

jest.mock('../../src/repositories/kakao-place.repository');

const place = (overrides = {}) => ({
  order: 1,
  type: 'place',
  name: '전포카페거리',
  latitude: 35.1533,
  longitude: 129.062,
  placeId: 'kakao:25661344',
  ...overrides,
});

beforeEach(() => jest.clearAllMocks());

describe('materializeRoutePlaces', () => {
  it('replaces each Kakao id with the place row written for it', async () => {
    kakaoPlaceRepository.upsertAll.mockResolvedValue(
      new Map([
        ['25661344', 'aaaaaaaa-0000-4000-8000-000000000001'],
        ['140012294', 'aaaaaaaa-0000-4000-8000-000000000002'],
      ])
    );

    const result = await materializeRoutePlaces([
      place(),
      place({ order: 2, placeId: 'kakao:140012294', name: '홈즈앤루팡 서면점' }),
    ]);

    expect(result.map((p) => p.placeId)).toEqual([
      'aaaaaaaa-0000-4000-8000-000000000001',
      'aaaaaaaa-0000-4000-8000-000000000002',
    ]);
    // Everything else about the stop is untouched.
    expect(result[0].name).toBe('전포카페거리');
    expect(result[0].latitude).toBe(35.1533);
  });

  it('leaves a snapshot with no Kakao places alone, without touching the db', async () => {
    // A bookmark-folder route or a trip itinerary is already made of real
    // places -- it must not pay for a query it does not need.
    const routeData = [place({ placeId: 'aaaaaaaa-0000-4000-8000-000000000009' })];

    await expect(materializeRoutePlaces(routeData)).resolves.toBe(routeData);
    expect(kakaoPlaceRepository.upsertAll).not.toHaveBeenCalled();
  });

  it('sends each Kakao place once even when a course visits it twice', async () => {
    // Two rows with the same conflict target make Postgres refuse the whole
    // insert ("cannot affect row a second time").
    kakaoPlaceRepository.upsertAll.mockResolvedValue(
      new Map([['25661344', 'aaaaaaaa-0000-4000-8000-000000000001']])
    );

    await materializeRoutePlaces([place(), place({ order: 2 })]);

    expect(kakaoPlaceRepository.upsertAll).toHaveBeenCalledWith([
      expect.objectContaining({ externalId: '25661344' }),
    ]);
  });

  it('skips a Kakao place with no coordinates rather than writing a placeless row', async () => {
    const routeData = [place({ latitude: null, longitude: null })];

    await expect(materializeRoutePlaces(routeData)).resolves.toBe(routeData);
    expect(kakaoPlaceRepository.upsertAll).not.toHaveBeenCalled();
  });

  it('keeps the Kakao id when the place could not be written', async () => {
    // Better an unbookmarkable stop than a stop pointing at nothing.
    kakaoPlaceRepository.upsertAll.mockResolvedValue(new Map());

    const result = await materializeRoutePlaces([place()]);

    expect(result[0].placeId).toBe('kakao:25661344');
  });

  it('leaves hotel points, which have no placeId, untouched', async () => {
    kakaoPlaceRepository.upsertAll.mockResolvedValue(
      new Map([['25661344', 'aaaaaaaa-0000-4000-8000-000000000001']])
    );

    const result = await materializeRoutePlaces([
      { order: 0, type: 'hotel', hotelId: 'region-center', placeId: null, name: '부산 전포' },
      place({ order: 1 }),
    ]);

    expect(result[0]).toEqual(
      expect.objectContaining({ type: 'hotel', placeId: null })
    );
  });
});
