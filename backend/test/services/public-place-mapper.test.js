const {
  tourApiItemToPlace,
  parseCsvLine,
  semasColumnIndex,
  semasRowToPlace,
} = require('../../src/services/public-place-mapper');
const { classifyTourApiItem, classifySemasRow } = require('../../src/services/public-place-classification');

describe('classifyTourApiItem', () => {
  it('uses the most specific lclsSystm code that has a rule', () => {
    expect(classifyTourApiItem({ lclsSystm1: 'VE', lclsSystm2: 'VE07', lclsSystm3: 'VE070600' })).toEqual({
      category: 'gallery',
      tags: ['전시 갤러리'],
    });
  });

  it('falls back to the 2nd-level code', () => {
    expect(classifyTourApiItem({ lclsSystm1: 'FD', lclsSystm2: 'FD02', lclsSystm3: 'FD020100' })).toEqual({
      category: 'restaurant',
      tags: [],
    });
  });

  it('lets an explicit exclusion win over a broader rule', () => {
    // 클럽 sits under 주점, which is otherwise imported as bars.
    expect(classifyTourApiItem({ lclsSystm1: 'FD', lclsSystm2: 'FD04', lclsSystm3: 'FD040300' })).toBeNull();
  });

  it('skips classifications nobody travels to', () => {
    expect(classifyTourApiItem({ lclsSystm1: 'SH', lclsSystm2: 'SH03', lclsSystm3: 'SH030100' })).toBeNull(); // 대형마트
    expect(classifyTourApiItem({ lclsSystm1: 'AC', lclsSystm2: 'AC01', lclsSystm3: 'AC010100' })).toBeNull(); // 호텔
    expect(classifyTourApiItem({})).toBeNull();
  });
});

describe('classifySemasRow', () => {
  it('maps allowlisted subcategories', () => {
    expect(classifySemasRow('I21201')).toEqual({ category: 'cafe', tags: [] });
    expect(classifySemasRow('I21001')).toEqual({ category: 'bakery', tags: [] });
  });

  it('skips everything not allowlisted, including 유흥주점 and 구내식당', () => {
    expect(classifySemasRow('I21101')).toBeNull();
    expect(classifySemasRow('I20701')).toBeNull();
    expect(classifySemasRow('R10407')).toBeNull(); // 노래방
    expect(classifySemasRow('')).toBeNull();
  });
});

describe('tourApiItemToPlace', () => {
  const item = {
    contentid: '2785729',
    title: '갤러리&카페 라안',
    addr1: '경상남도 사천시 백천길 331 (백천동)',
    addr2: '',
    mapx: '128.0918611430',
    mapy: '34.9983771977',
    lclsSystm1: 'FD',
    lclsSystm2: 'FD05',
    lclsSystm3: 'FD050100',
  };

  it('builds a place row with mapx as longitude and mapy as latitude', () => {
    expect(tourApiItemToPlace(item)).toEqual({
      source: 'tour_api',
      externalId: '2785729',
      name: '갤러리&카페 라안',
      address: '경상남도 사천시 백천길 331 (백천동)',
      latitude: 34.9983771977,
      longitude: 128.091861143,
      category: 'cafe',
      tags: [],
    });
  });

  it('rejects items without usable coordinates', () => {
    expect(tourApiItemToPlace({ ...item, mapx: '', mapy: '' })).toBeNull();
    expect(tourApiItemToPlace({ ...item, mapx: '0', mapy: '0' })).toBeNull();
  });

  it('rejects unclassified items', () => {
    expect(tourApiItemToPlace({ ...item, lclsSystm1: 'AC', lclsSystm2: 'AC01', lclsSystm3: 'AC010100' })).toBeNull();
  });
});

describe('parseCsvLine', () => {
  it('splits quoted fields', () => {
    expect(parseCsvLine('"a","b c",""')).toEqual(['a', 'b c', '']);
  });

  it('keeps commas and escaped quotes inside quoted fields', () => {
    expect(parseCsvLine('"a, b","say ""hi""",c')).toEqual(['a, b', 'say "hi"', 'c']);
  });
});

describe('semasRowToPlace', () => {
  const header = [
    '상가업소번호', '상호명', '지점명', '상권업종소분류코드', '지번주소', '도로명주소', '경도', '위도',
  ];
  const index = semasColumnIndex(header);
  const row = ['MA0101', '스타벅스', '판교점', 'I21201', '성남시 백현동 1', '성남시 판교역로 1', '127.11', '37.39'];

  it('builds a place row, naming it with the branch', () => {
    expect(semasRowToPlace(row, index)).toEqual({
      source: 'semas',
      externalId: 'MA0101',
      name: '스타벅스 판교점',
      address: '성남시 판교역로 1',
      latitude: 37.39,
      longitude: 127.11,
      category: 'cafe',
      tags: [],
    });
  });

  it('falls back to the lot address and omits an empty branch', () => {
    const place = semasRowToPlace(['MA0102', '동네빵집', '', 'I21001', '성남시 백현동 2', '', '127.11', '37.39'], index);
    expect(place.name).toBe('동네빵집');
    expect(place.address).toBe('성남시 백현동 2');
  });

  it('skips rows outside the allowlist or without coordinates', () => {
    expect(semasRowToPlace([...row.slice(0, 3), 'R10407', ...row.slice(4)], index)).toBeNull();
    expect(semasRowToPlace([...row.slice(0, 6), '', ''], index)).toBeNull();
  });

  it('fails loudly when a column is missing from the header', () => {
    expect(() => semasColumnIndex(header.slice(1))).toThrow('상가업소번호');
  });
});

describe('broken names', () => {
  const { isBrokenPlaceName, isBrokenBranchName } = require('../../src/services/public-place-mapper');

  it('flags names cut off mid-bracket or with a dangling connector', () => {
    expect(isBrokenPlaceName('타르틴(타르틴베이커리서울 코리아')).toBe(true);
    expect(isBrokenPlaceName('앤디관)')).toBe(true);
    expect(isBrokenPlaceName('분식·')).toBe(true);
    expect(isBrokenPlaceName('&마왕푸드 동대문')).toBe(true);
  });

  it('keeps short but real names', () => {
    ['별', '강릉의 밤', '모주체험 여', '[착한가게] 덤', '카페 봄(春)', '에이플러스;A+'].forEach((name) =>
      expect(isBrokenPlaceName(name)).toBe(false)
    );
  });

  it('flags a one-syllable 지점명 but not real branch names', () => {
    expect(isBrokenBranchName('대')).toBe(true);
    expect(isBrokenBranchName('명지')).toBe(false);
    expect(isBrokenBranchName('판교점')).toBe(false);
  });

  it('skips SEMAS rows with a broken name or branch at import', () => {
    const header = ['상가업소번호', '상호명', '지점명', '상권업종소분류코드', '지번주소', '도로명주소', '경도', '위도'];
    const index = semasColumnIndex(header);
    expect(semasRowToPlace(['A1', '스타벅스', '대', 'I21201', '', '서울', '127.1', '37.5'], index)).toBeNull();
    expect(semasRowToPlace(['A2', '비어링(세계맥', '', 'I21103', '', '서울', '127.1', '37.5'], index)).toBeNull();
  });
});
