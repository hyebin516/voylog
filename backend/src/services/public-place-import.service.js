const readline = require('readline');
const axios = require('axios');
const env = require('../config/env');
const publicPlaceRepository = require('../repositories/public-place.repository');
const { tourApiItemToPlace, parseCsvLine, semasColumnIndex, semasRowToPlace } = require('./public-place-mapper');
const { TOUR_API_CONTENT_TYPES } = require('./public-place-classification');

/**
 * Loads the public datasets into `places` (FR-15/FR-17 cold start,
 * migration 025). Used by the one-off import scripts and by the monthly
 * refresh (public-data-refresh.service.js). Every write is an upsert, so
 * re-running refreshes rows instead of duplicating them.
 */

// ---- 한국관광공사 TourAPI ----------------------------------------------

const TOUR_API_BASE_URL = 'https://apis.data.go.kr/B551011/KorService2';
const TOUR_API_PAGE_SIZE = 1000;
const TOUR_API_MAX_ATTEMPTS = 3;

// data.go.kr hands out an "Encoding" and a "Decoding" key. axios encodes
// params itself, so an already-encoded key would be encoded twice (403).
function tourApiServiceKey() {
  const key = env.tourApiKey;
  if (!key) throw new Error('TOUR_API_KEY is not set in backend/.env');
  return key.includes('%') ? decodeURIComponent(key) : key;
}

async function fetchTourApiPage(contentTypeId, pageNo) {
  for (let attempt = 1; ; attempt += 1) {
    try {
      // eslint-disable-next-line no-await-in-loop
      const { data } = await axios.get(`${TOUR_API_BASE_URL}/areaBasedList2`, {
        params: {
          serviceKey: tourApiServiceKey(),
          MobileOS: 'ETC',
          MobileApp: 'Voylog',
          _type: 'json',
          contentTypeId,
          numOfRows: TOUR_API_PAGE_SIZE,
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
      if (attempt >= TOUR_API_MAX_ATTEMPTS) throw new Error(`TourAPI page ${pageNo} failed: ${err.message}`);
      // eslint-disable-next-line no-await-in-loop
      await new Promise((resolve) => setTimeout(resolve, 2000 * attempt));
    }
  }
}

/**
 * Imports every TourAPI item of the content types we use, nationwide.
 * Throws if any page can't be fetched, so a caller never mistakes a partial
 * import for a complete one.
 *
 * @returns {Promise<number>} places written
 */
async function importTourApi({ log = () => {} } = {}) {
  let written = 0;
  for (const contentTypeId of TOUR_API_CONTENT_TYPES) {
    let pageNo = 1;
    let fetched = 0;
    let totalCount = 0;
    do {
      // eslint-disable-next-line no-await-in-loop
      const page = await fetchTourApiPage(contentTypeId, pageNo);
      totalCount = page.totalCount;
      fetched += page.items.length;
      // eslint-disable-next-line no-await-in-loop
      written += await publicPlaceRepository.upsertMany(page.items.map(tourApiItemToPlace).filter(Boolean));
      log(`  TourAPI type ${contentTypeId} page ${pageNo}: ${fetched}/${totalCount} fetched, ${written} written`);
      if (page.items.length === 0) break;
      pageNo += 1;
    } while (fetched < totalCount);
  }
  return written;
}

// ---- 소상공인시장진흥공단 상가(상권)정보 --------------------------------

const SEMAS_WRITE_BATCH_SIZE = 5000;

// Only business types an earlier rule set could have imported (음식, 예술·
// 스포츠, 소매); rejected rows from anything else were never in the DB.
const PREVIOUSLY_IMPORTABLE_PREFIXES = ['I2', 'R1', 'G2'];

/**
 * Imports one region's CSV from a readable stream (a file, or an entry
 * streamed straight out of the dataset zip). Rows the current rules reject
 * are removed if an earlier import had created them.
 *
 * @returns {Promise<{rows: number, written: number, removed: number}>}
 */
async function importSemasCsv(input, label, { log = () => {} } = {}) {
  const lines = readline.createInterface({ input, crlfDelay: Infinity });

  let columnIndex = null;
  let rows = 0;
  let written = 0;
  let removed = 0;
  let batch = [];
  let rejectedIds = [];

  const flush = async () => {
    written += await publicPlaceRepository.upsertMany(batch);
    removed += await publicPlaceRepository.removeByExternalIds('semas', rejectedIds);
    batch = [];
    rejectedIds = [];
    log(`  ${label}: ${rows} rows read, ${written} kept, ${removed} removed`);
  };

  for await (const line of lines) {
    if (columnIndex === null) {
      // The file starts with a UTF-8 BOM.
      columnIndex = semasColumnIndex(parseCsvLine(line.replace(/^﻿/, '')));
      continue;
    }
    if (line === '') continue;
    rows += 1;
    const fields = parseCsvLine(line);
    const place = semasRowToPlace(fields, columnIndex);
    if (place) {
      batch.push(place);
    } else if (PREVIOUSLY_IMPORTABLE_PREFIXES.some((prefix) => (fields[columnIndex.subcategoryCode] || '').startsWith(prefix))) {
      rejectedIds.push(fields[columnIndex.id]);
    }
    if (batch.length >= SEMAS_WRITE_BATCH_SIZE || rejectedIds.length >= SEMAS_WRITE_BATCH_SIZE * 4) {
      // eslint-disable-next-line no-await-in-loop
      await flush();
    }
  }
  if (batch.length > 0 || rejectedIds.length > 0) await flush();
  return { rows, written, removed };
}

module.exports = { importTourApi, importSemasCsv };
