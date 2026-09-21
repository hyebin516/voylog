/**
 * Loads 한국관광공사 TourAPI places nationwide into `places` (FR-15/FR-17
 * cold start, migration 025).
 *
 *   node scripts/import-tour-api.js
 *
 * Needs TOUR_API_KEY in backend/.env. Safe to re-run: existing rows are
 * refreshed, not duplicated. A full run is ~60 API calls, well inside the
 * development key's 1,000/day quota. The backend also re-runs this monthly
 * (see scripts/refresh-public-places.js).
 *
 * Data: 한국관광공사 TourAPI (공공누리 제1유형, 출처표시). Images are not
 * imported -- their licenses vary per item (cpyrhtDivCd).
 */
const pool = require('../src/config/db');
const publicPlaceRepository = require('../src/repositories/public-place.repository');
const { importTourApi } = require('../src/services/public-place-import.service');

async function main() {
  const written = await importTourApi({ log: console.log });
  const removed = await publicPlaceRepository.removeDuplicateDatasetPlaces();
  console.log(`TourAPI import done: ${written} places written, ${removed} duplicates removed`);
}

main()
  .catch((err) => {
    console.error(err.message);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
