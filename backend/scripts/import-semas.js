/**
 * Loads 소상공인시장진흥공단 상가(상권)정보 restaurants, cafes and similar
 * places into `places` (FR-15/FR-17 cold start, migration 025).
 *
 *   node scripts/import-semas.js <csv> [<csv> ...]
 *
 * The dataset ships as one zip of per-region CSVs. Extract the regions to
 * load into database/seed-data/ first (that folder is gitignored), then
 *
 *   node scripts/import-semas.js ../database/seed-data/*서울*.csv ../database/seed-data/*경기*.csv
 *
 * Only allowlisted business types are kept (see
 * public-place-classification.js). Safe to re-run: existing rows are
 * refreshed, not duplicated. Run import-tour-api.js first so store listings
 * that duplicate a TourAPI entry are the ones removed.
 *
 * Data: 소상공인시장진흥공단 상가(상권)정보 (공공누리 제1유형, 출처표시).
 */
const fs = require('fs');
const path = require('path');
const readline = require('readline');
const pool = require('../src/config/db');
const publicPlaceRepository = require('../src/repositories/public-place.repository');
const { parseCsvLine, semasColumnIndex, semasRowToPlace } = require('../src/services/public-place-mapper');

const WRITE_BATCH_SIZE = 5000;

async function importCsv(filePath) {
  const lines = readline.createInterface({
    input: fs.createReadStream(filePath, { encoding: 'utf8' }),
    crlfDelay: Infinity,
  });

  let columnIndex = null;
  let rows = 0;
  let written = 0;
  let batch = [];

  const flush = async () => {
    written += await publicPlaceRepository.upsertMany(batch);
    batch = [];
    console.log(`  ${path.basename(filePath)}: ${rows} rows read, ${written} kept`);
  };

  for await (const line of lines) {
    if (columnIndex === null) {
      // The file starts with a UTF-8 BOM.
      columnIndex = semasColumnIndex(parseCsvLine(line.replace(/^﻿/, '')));
      continue;
    }
    if (line === '') continue;
    rows += 1;
    const place = semasRowToPlace(parseCsvLine(line), columnIndex);
    if (place) batch.push(place);
    if (batch.length >= WRITE_BATCH_SIZE) await flush();
  }
  if (batch.length > 0) await flush();
  return written;
}

async function main() {
  const files = process.argv.slice(2);
  if (files.length === 0) {
    throw new Error('Usage: node scripts/import-semas.js <csv> [<csv> ...]');
  }

  let totalWritten = 0;
  for (const file of files) {
    // eslint-disable-next-line no-await-in-loop
    totalWritten += await importCsv(file);
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
