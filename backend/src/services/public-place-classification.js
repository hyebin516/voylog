/**
 * Decides which public-dataset rows become Voylog places (FR-15/FR-17 cold
 * start), and translates each dataset's own classification into the app's
 * category strings and fixed tag vocabulary.
 *
 * Categories must be ones the recommendation scoring understands
 * (ai-worker recommendation_scoring_policy._TIME_OF_DAY_CATEGORY_HINTS and
 * walking_course_service._DWELL_MINUTES_BY_CATEGORY): cafe, bakery,
 * restaurant, dessert, bar, museum, gallery, attraction, shopping, beach,
 * night_view.
 *
 * Tags must be codes from ai-worker/app/constants/tag_catalog.py -- a tag
 * outside that list can never match a user's taste. Tags are only assigned
 * where the classification genuinely implies them (a palace is traditional,
 * a gallery is an exhibition); nothing is guessed from a name.
 *
 * Every function returns null for rows that shouldn't be places at all.
 * Allowlists rather than blocklists: both datasets are mostly things nobody
 * travels to (pharmacies, gyms, study rooms, nightclubs), so anything not
 * explicitly chosen is left out.
 */

// ---- 한국관광공사 TourAPI ----------------------------------------------

// Content types the importer requests. 숙박(32), 레포츠(28), 여행코스(25) and
// 축제(15) aren't places to drop into a walk or a nearby list.
const TOUR_API_CONTENT_TYPES = ['12', '14', '38', '39'];

// Keyed by TourAPI's 신분류체계 (lclsSystm1/2/3, from lclsSystmCode2). List
// items leave the old cat1/cat2/cat3 fields empty, so only these codes are
// usable. Rules are checked most-specific first: a 3rd-level code, then its
// 2nd-level prefix, then its 1st-level prefix.
const TOUR_API_RULES = {
  // 음식 (FD)
  FD030100: { category: 'bakery', tags: [] }, // 제과
  FD040300: null, // 클럽
  FD040200: { category: 'bar', tags: ['활기찬 분위기'] }, // 생맥주전문점
  FD040400: { category: 'bar', tags: ['전통적인 분위기'] }, // 전통주/민속주점
  FD01: { category: 'restaurant', tags: [] }, // 한식
  FD02: { category: 'restaurant', tags: [] }, // 외국식
  FD03: { category: 'restaurant', tags: [] }, // 간이음식
  FD04: { category: 'bar', tags: [] }, // 주점
  FD05: { category: 'cafe', tags: [] }, // 카페/찻집

  // 역사관광 (HS)
  HS011100: { category: 'attraction', tags: [] }, // 근대건축물
  HS01: { category: 'attraction', tags: ['전통적인 분위기'] }, // 고궁, 성곽, 고택, 민속마을...
  HS02: { category: 'attraction', tags: ['전통적인 분위기'] }, // 탑, 비석, 불상
  HS03: { category: 'attraction', tags: [] }, // 종교성지
  HS04: { category: 'attraction', tags: [] }, // 안보관광지

  // 자연관광 (NA)
  NA020800: { category: 'beach', tags: ['오션뷰'] }, // 해안절경
  NA020900: { category: 'beach', tags: ['오션뷰'] }, // 해변, 해수욕장
  NA040700: { category: 'attraction', tags: ['정원'] }, // 수목원, 정원
  NA: { category: 'attraction', tags: [] },

  // 문화관광 (VE)
  VE010200: { category: 'night_view', tags: ['야경'] }, // 타워/전망대
  VE01: { category: 'attraction', tags: [] }, // 랜드마크 (건물, 다리, 분수...)
  VE02: { category: 'attraction', tags: [] }, // 테마파크, 동물원, 수족관
  VE030200: null, // 소공원
  VE030300: null, // 어린이공원
  VE03: { category: 'attraction', tags: [] }, // 시민·근린·주제공원
  VE040100: { category: 'attraction', tags: ['로컬스러운 분위기'] }, // 골목길, 문화거리
  VE040200: { category: 'attraction', tags: ['로컬스러운 분위기'] }, // 마을관광지
  VE04: { category: 'attraction', tags: [] }, // 둘레길
  VE050100: { category: 'attraction', tags: [] }, // 관광단지
  VE06: { category: 'attraction', tags: [] }, // 공연장, 영화관
  VE070100: { category: 'museum', tags: ['전시 갤러리'] }, // 박물관
  VE070200: { category: 'museum', tags: [] }, // 기념관
  VE070300: { category: 'museum', tags: ['전시 갤러리'] }, // 전시관
  VE070500: { category: 'museum', tags: [] }, // 과학관
  VE070600: { category: 'gallery', tags: ['전시 갤러리'] }, // 미술관/화랑
  VE090300: { category: 'attraction', tags: ['조용한 분위기'] }, // 도서관
  VE090400: { category: 'attraction', tags: ['전통적인 분위기'] }, // 문화전수시설
  VE120100: { category: 'shopping', tags: ['조용한 분위기'] }, // 서점
  VE120300: { category: 'attraction', tags: [] }, // 기타문화시설
  // Everything else under VE -- 리조트, 컨벤션센터, 연회장, 문화원, 어학당,
  // 학교, 스포츠센터, 공항·역·터미널, 카지노 -- is left out.

  // 쇼핑 (SH) -- 대형마트(SH03) and 면세점(SH04) are left out
  SH01: { category: 'shopping', tags: [] }, // 백화점
  SH02: { category: 'shopping', tags: [] }, // 복합쇼핑몰, 아웃렛
  SH050100: { category: 'shopping', tags: ['감성적인 분위기'] }, // 공방/공예품점
  SH050300: { category: 'shopping', tags: ['로컬스러운 분위기'] }, // 기념품/특산물
  SH05: { category: 'shopping', tags: [] }, // 전문상가
  SH06: { category: 'shopping', tags: ['로컬스러운 분위기', '활기찬 분위기'] }, // 시장
  SH07: { category: 'shopping', tags: [] },

  // 체험관광 (EX) -- 산업관광(EX06) and medical/beauty wellness are left out
  EX01: { category: 'attraction', tags: ['전통적인 분위기'] }, // 전통체험
  EX02: { category: 'attraction', tags: [] }, // 공예체험
  EX03: { category: 'attraction', tags: ['로컬스러운 분위기'] }, // 농·산·어촌 체험
  EX04: { category: 'attraction', tags: ['전통적인 분위기', '조용한 분위기'] }, // 템플스테이
  EX050100: { category: 'attraction', tags: [] }, // 온천/사우나/스파
  EX050200: { category: 'attraction', tags: [] }, // 찜질방
  EX07: { category: 'attraction', tags: [] }, // 유람선, 기타체험
};

/**
 * @param {{lclsSystm1?: string, lclsSystm2?: string, lclsSystm3?: string}} item
 * @returns {{category: string, tags: string[]} | null}
 */
function classifyTourApiItem(item) {
  const codes = [item.lclsSystm3, item.lclsSystm2, item.lclsSystm1].filter(Boolean);
  for (const code of codes) {
    // An explicit null is a deliberate exclusion and wins over a broader rule.
    if (Object.prototype.hasOwnProperty.call(TOUR_API_RULES, code)) {
      return TOUR_API_RULES[code];
    }
  }
  return null;
}

// ---- 소상공인시장진흥공단 상가(상권)정보 --------------------------------

const RESTAURANT = { category: 'restaurant', tags: [] };

// 상권업종소분류코드 -> classification. Codes not listed are skipped.
const SEMAS_RULES = {
  // 한식
  I20101: RESTAURANT, // 백반/한정식
  I20102: RESTAURANT, // 국/탕/찌개류
  I20103: RESTAURANT, // 족발/보쌈
  I20104: RESTAURANT, // 전/부침개
  I20105: RESTAURANT, // 국수/칼국수
  I20106: RESTAURANT, // 냉면/밀면
  I20107: RESTAURANT, // 돼지고기 구이/찜
  I20108: RESTAURANT, // 소고기 구이/찜
  I20109: RESTAURANT, // 곱창 전골/구이
  I20110: RESTAURANT, // 닭/오리고기 구이/찜
  I20111: RESTAURANT, // 횟집
  I20112: RESTAURANT, // 해산물 구이/찜
  I20113: RESTAURANT, // 복 요리 전문
  I20199: RESTAURANT, // 기타 한식
  // 중식 · 일식 · 서양식 · 아시아 · 기타 외국식
  I20201: RESTAURANT,
  I20202: RESTAURANT,
  I20301: RESTAURANT,
  I20302: RESTAURANT,
  I20303: RESTAURANT,
  I20399: RESTAURANT,
  I20401: RESTAURANT,
  I20402: RESTAURANT,
  I20403: RESTAURANT,
  I20499: RESTAURANT,
  I20501: RESTAURANT,
  I20599: RESTAURANT,
  I20601: RESTAURANT,
  I20702: RESTAURANT, // 뷔페 (구내식당 I20701 is not a destination)
  // 간이 음식
  I21001: { category: 'bakery', tags: [] }, // 빵/도넛
  I21002: { category: 'dessert', tags: ['전통적인 분위기'] }, // 떡/한과
  I21003: RESTAURANT, // 피자
  I21004: RESTAURANT, // 버거
  I21005: RESTAURANT, // 토스트/샌드위치/샐러드
  I21006: RESTAURANT, // 치킨
  I21007: RESTAURANT, // 김밥/만두/분식
  I21008: { category: 'dessert', tags: ['디저트'] }, // 아이스크림/빙수
  // 주점 (일반/무도 유흥주점 I21101/I21102 are excluded)
  I21103: { category: 'bar', tags: ['활기찬 분위기'] }, // 생맥주 전문
  I21104: { category: 'bar', tags: [] }, // 요리 주점
  // 카페
  I21201: { category: 'cafe', tags: [] },
  // 놀거리 · 소품샵 · 서점 -- stricter than food, see NON_FOOD_RULE_NOTE.
  // 노래방, PC방, 헬스장, 독서실, 복권방 are never included. 전자 게임장
  // (R10404) and 기타 오락장 (R10405) are left out too: sampled nationwide
  // they were almost all 오락실, 인형뽑기방, 홀덤·마작, PC방 -- nothing a
  // walking course or a nearby list should send someone to.
  // No mood tag: with one, a "활기찬" course in 서면 became five bowling alleys.
  R10309: { category: 'attraction', tags: [], standardIndustry: 'R91134' }, // 볼링장
  R10409: { category: 'attraction', tags: [], standardIndustry: 'R91239' }, // 수상/해양 레저업
  G21301: {
    category: 'shopping',
    tags: ['조용한 분위기'],
    standardIndustry: 'G47611',
    // Book distributors and learning-material sellers share the code.
    excludedNamePattern: /교육|에듀|학습|신문|출판|닷컴/,
  }, // 서점
  G21801: { category: 'shopping', tags: ['감성적인 분위기'], standardIndustry: 'G47841' }, // 예술품 소매업
  G21802: { category: 'shopping', tags: ['로컬스러운 분위기'], standardIndustry: 'G47842' }, // 기념품점
};

// NON_FOOD_RULE_NOTE: for non-food codes the listing's name is all a user
// sees, and these codes are full of registrations that aren't a place to
// visit -- "킴스코퍼레이션" and "케이에스티엘산업" filed as 볼링장, consulting
// firms as 예술품 소매업. So a non-food row must (1) also carry the matching
// 표준산업분류 code, not just the 상권업종 code, and (2) not be named like a
// company. Food rows skip the name check: there a corporate prefix is
// usually a real franchise operator ("커피빈코리아").
const COMPANY_NAME_PATTERN =
  /코퍼레이션|컴퍼니|상사|산업|인베스트|글로벌|인터내셔널|유통|무역|엔터프라이즈|엔터테인먼트|주식회사|\(주\)|㈜|협동조합|컨설팅|수산|개발|건설|홀딩스|에이전시|이엔티$|코리아$/;

/**
 * @param {string} subcategoryCode 상권업종소분류코드
 * @param {{standardIndustryCode?: string, name?: string}} [row]
 * @returns {{category: string, tags: string[]} | null}
 */
function classifySemasRow(subcategoryCode, { standardIndustryCode, name = '' } = {}) {
  const rule = SEMAS_RULES[subcategoryCode];
  if (!rule) return null;
  if (rule.standardIndustry) {
    if (standardIndustryCode !== rule.standardIndustry) return null;
    if (COMPANY_NAME_PATTERN.test(name)) return null;
    if (rule.excludedNamePattern && rule.excludedNamePattern.test(name)) return null;
  }
  return { category: rule.category, tags: rule.tags };
}

/**
 * Tag list in the places.tags JSONB shape. Dataset classifications are
 * editorial facts rather than LLM guesses, so they carry full confidence.
 */
function toPlaceTags(tags) {
  return tags.map((code) => ({ code, confidence: 1 }));
}

module.exports = {
  TOUR_API_CONTENT_TYPES,
  classifyTourApiItem,
  classifySemasRow,
  toPlaceTags,
};
