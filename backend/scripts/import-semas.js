/**
 * Loads 소상공인시장진흥공단 상가(상권)정보 restaurants, cafes and similar
 * places into `places` (FR-15/FR-17 cold start, migration 025).
 *
 *   node scripts/import-semas.js <csv> [<csv> ...]
 *
 * For individual region CSVs extracted from the dataset zip. To load a whole
 * new edition, put the zip in database/seed-data/ and run
 * scripts/refresh-public-places.js instead -- it reads the CSVs straight out
 * of the zip and removes places the new edition no longer lists.
 *
 * Only allowlisted business types are kept (see
 * public-place-classification.js). Safe to re-run: existing rows are
 * refreshed, not duplicated, and places an earlier run imported from rows
 * the current rules reject are removed. Run import-tour-api.js first so
 * store listings that duplicate a TourAPI entry are the ones removed.
 *
 * Data: 소상공인시장진흥공단 상가(상권)정보 (공공누리 제1유형, 출처표시).
 */
const fs = require('fs');
const path = require('path');
const pool = require('../src/config/db');
const publicPlaceRepository = require('../src/repositories/public-place.repository');
const { importSemasCsv } = require('../src/services/public-place-import.service');

async function main() {
  const files = process.argv.slice(2);
  if (files.length === 0) {
    throw new Error('Usage: node scripts/import-semas.js <csv> [<csv> ...]');
  }

  let totalWritten = 0;
  for (const file of files) {
    const input = fs.createReadStream(file, { encoding: 'utf8' });
    // eslint-disable-next-line no-await-in-loop
    const { written } = await importSemasCsv(input, path.basename(file), { log: console.log });
    totalWritten += written;
  }
  const removed = await publicPlaceRepository.removeDuplicateDatasetPlaces();
  console.log(`SEMAS import done: ${totalWritten} places written, ${removed} duplicates removed`);
}

main()
  .catch((err) => {
    console.error(err.message);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
