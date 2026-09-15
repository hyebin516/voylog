/**
 * Loads 한국관광공사 TourAPI places nationwide into `places` (FR-15/FR-17
 * cold start, migration 025).
 *
 *   node scripts/import-tour-api.js
 *
 * Needs TOUR_API_KEY in backend/.env. Safe to re-run: existing rows are
 * refreshed, not duplicated. A full run is ~60 API calls, well inside the
 * development key's 1,000/day quota.
 *
 * Data: 한국관광공사 TourAPI (공공누리 제1유형, 출처표시). Images are not
 * imported -- their licenses vary per item (cpyrhtDivCd).
 */
const axios = require('axios');
const env = require('../src/config/env');
const pool = require('../src/config/db');
const publicPlaceRepository = require('../src/repositories/public-place.repository');
const { tourApiItemToPlace } = require('../src/services/public-place-mapper');
const { TOUR_API_CONTENT_TYPES } = require('../src/services/public-place-classification');

const BASE_URL = 'https://apis.data.go.kr/B551011/KorService2';
const PAGE_SIZE = 1000;
const MAX_ATTEMPTS = 3;

// data.go.kr hands out an "Encoding" and a "Decoding" key. axios encodes
// params itself, so an already-encoded key would be encoded twice (403).
function serviceKey() {
  const key = env.tourApiKey;
  if (!key) throw new Error('TOUR_API_KEY is not set in backend/.env');
  return key.includes('%') ? decodeURIComponent(key) : key;
}

async function fetchPage(contentTypeId, pageNo) {
  for (let attempt = 1; ; attempt += 1) {
    try {
      // eslint-disable-next-line no-await-in-loop
      const { data } = await axios.get(`${BASE_URL}/areaBasedList2`, {
        params: {
          serviceKey: serviceKey(),
          MobileOS: 'ETC',
          MobileApp: 'Voylog',
          _type: 'json',
          contentTypeId,
          numOfRows: PAGE_SIZE,
          pageNo,
          arrange: 'C',
        },
        timeout: 60000,
      });
      const body = data && data.response && data.response.body;
      if (!body) throw new Error('unexpected TourAPI response shape');
      const items = body.items && body.items.item ? body.items.item : [];
      return { totalCount: body.totalCount, items: Array.isArray(items) ? items : [items] };
    } catch (err) {
      // Only the message -- the request config carries the service key.
      if (attempt >= MAX_ATTEMPTS) throw new Error(`TourAPI page ${pageNo} failed: ${err.message}`);
      // eslint-disable-next-line no-await-in-loop
      await new Promise((resolve) => setTimeout(resolve, 2000 * attempt));
    }
  }
}

async function importContentType(contentTypeId) {
  let pageNo = 1;
  let fetched = 0;
  let written = 0;
  let totalCount = 0;
  do {
    // eslint-disable-next-line no-await-in-loop
    const page = await fetchPage(contentTypeId, pageNo);
    totalCount = page.totalCount;
    fetched += page.items.length;
    const places = page.items.map(tourApiItemToPlace).filter(Boolean);
    // eslint-disable-next-line no-await-in-loop
    written += await publicPlaceRepository.upsertMany(places);
    console.log(`  type ${contentTypeId} page ${pageNo}: ${fetched}/${totalCount} fetched, ${written} kept`);
    if (page.items.length === 0) break;
    pageNo += 1;
  } while (fetched < totalCount);
  return { fetched, written };
}

async function main() {
  let totalWritten = 0;
  for (const contentTypeId of TOUR_API_CONTENT_TYPES) {
    // eslint-disable-next-line no-await-in-loop
    const { written } = await importContentType(contentTypeId);
    totalWritten += written;
  }
  const removed = await publicPlaceRepository.removeDuplicateDatasetPlaces();
  console.log(`TourAPI import done: ${totalWritten} places written, ${removed} duplicates removed`);
}

main()
  .catch((err) => {
    console.error(err.message);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
