const fs = require('fs');
const path = require('path');
const yauzl = require('yauzl');
const publicPlaceRepository = require('../repositories/public-place.repository');
const publicDataRefreshRepository = require('../repositories/public-data-refresh.repository');
const { importTourApi, importSemasCsv } = require('./public-place-import.service');

/**
 * Monthly refresh of the public-dataset places (FR-15/FR-17, migrations
 * 025/026).
 *
 * - TourAPI is re-imported every run; it changes continuously.
 * - 소상공인 상가(상권)정보 is published as a quarterly zip that has to be
 *   downloaded from data.go.kr by hand and dropped into database/seed-data/.
 *   A run imports it only when that folder holds a newer edition than the
 *   last one imported, streaming each region's CSV straight out of the zip.
 * - Places a complete import no longer contains -- closed shops, withdrawn
 *   listings -- are removed afterwards (bookmarked places are kept).
 */

const REFRESH_INTERVAL_DAYS = 30;
const SEMAS_ZIP_PATTERN = /상가\(상권\)정보_(\d{8})\.zip$/;
// The dataset ships 16 region files, not one per 시도: 전남 and 광주 share
// one file (소상공인시장진흥공단_상가(상권)정보_전남광주_YYYYMM.csv).
const SEMAS_REGION_COUNT = 16;

// Don't remove "stale" places when a run wrote far fewer than are active: a
// data source returning a partial set (an API outage mid-run, a truncated
// file) would otherwise delete most of the dataset.
const MIN_WRITTEN_SHARE_FOR_REMOVAL = 0.5;

// A run older than this that never finished (the process was killed) no
// longer blocks a new one.
const STUCK_RUN_HOURS = 6;

function isRefreshDue(lastSucceeded, now = new Date()) {
  if (!lastSucceeded) return true;
  const ageMs = now.getTime() - new Date(lastSucceeded.started_at).getTime();
  return ageMs >= REFRESH_INTERVAL_DAYS * 24 * 60 * 60 * 1000;
}

function isStuck(runningRefresh, now = new Date()) {
  const ageMs = now.getTime() - new Date(runningRefresh.started_at).getTime();
  return ageMs >= STUCK_RUN_HOURS * 60 * 60 * 1000;
}

/** The newest 상가정보 zip in `seedDir`, by the edition date in its name. */
function findLatestSemasZip(seedDir) {
  if (!fs.existsSync(seedDir)) return null;
  return fs
    .readdirSync(seedDir)
    .map((file) => {
      const match = file.match(SEMAS_ZIP_PATTERN);
      return match ? { path: path.join(seedDir, file), edition: match[1] } : null;
    })
    .filter(Boolean)
    .sort((a, b) => b.edition.localeCompare(a.edition))[0] || null;
}

function openZip(zipPath) {
  return new Promise((resolve, reject) => {
    yauzl.open(zipPath, { lazyEntries: true, decodeStrings: true }, (err, zip) => (err ? reject(err) : resolve(zip)));
  });
}

function openEntry(zip, entry) {
  return new Promise((resolve, reject) => {
    zip.openReadStream(entry, (err, stream) => (err ? reject(err) : resolve(stream)));
  });
}

/**
 * Imports every region CSV in the zip. Throws unless all regions were read,
 * so an incomplete file never counts as a full import.
 */
async function importSemasZip(zipPath, { log }) {
  const zip = await openZip(zipPath);
  let regions = 0;
  let written = 0;
  try {
    await new Promise((resolve, reject) => {
      zip.on('error', reject);
      zip.on('end', resolve);
      zip.on('entry', async (entry) => {
        try {
          if (entry.fileName.toLowerCase().endsWith('.csv')) {
            const stream = await openEntry(zip, entry);
            stream.setEncoding('utf8');
            const result = await importSemasCsv(stream, path.basename(entry.fileName), { log });
            written += result.written;
            regions += 1;
          }
          zip.readEntry();
        } catch (err) {
          reject(err);
        }
      });
      zip.readEntry();
    });
  } finally {
    zip.close();
  }
  if (regions < SEMAS_REGION_COUNT) {
    throw new Error(`상가정보 zip had ${regions} region files, expected ${SEMAS_REGION_COUNT}`);
  }
  return written;
}

async function removeStale(source, since, written, { log }) {
  const active = await publicPlaceRepository.countActive(source);
  if (written < active * MIN_WRITTEN_SHARE_FOR_REMOVAL) {
    log(`  ${source}: wrote ${written} of ${active} active places -- too few to trust, keeping the rest`);
    return 0;
  }
  const removed = await publicPlaceRepository.removeStaleDatasetPlaces(source, since);
  log(`  ${source}: removed ${removed} places no longer in the data`);
  return removed;
}

/**
 * Runs one refresh and records it in public_data_refreshes.
 *
 * @returns {Promise<object>} what the run did
 */
async function refreshPublicPlaces({ seedDir, log = () => {} }) {
  const run = await publicDataRefreshRepository.start();
  const summary = { tourApiWritten: null, semasWritten: null, semasEdition: null, removedCount: 0 };
  try {
    log('Refreshing TourAPI places...');
    summary.tourApiWritten = await importTourApi({ log });
    summary.removedCount += await removeStale('tour_api', run.started_at, summary.tourApiWritten, { log });

    const zip = findLatestSemasZip(seedDir);
    const importedEdition = await publicDataRefreshRepository.findLatestSemasEdition();
    if (zip && (!importedEdition || zip.edition > importedEdition)) {
      log(`Importing 상가정보 edition ${zip.edition}...`);
      summary.semasWritten = await importSemasZip(zip.path, { log });
      summary.semasEdition = zip.edition;
      summary.removedCount += await removeStale('semas', run.started_at, summary.semasWritten, { log });
    } else {
      log(`상가정보: no edition newer than ${importedEdition || 'none'} in ${seedDir}, skipped`);
    }

    summary.removedCount += await publicPlaceRepository.removeDuplicateDatasetPlaces();
    await publicDataRefreshRepository.finish(run.refresh_id, { status: 'succeeded', ...summary });
    return summary;
  } catch (err) {
    await publicDataRefreshRepository.finish(run.refresh_id, { status: 'failed', ...summary, error: err.message });
    throw err;
  }
}

module.exports = {
  REFRESH_INTERVAL_DAYS,
  isRefreshDue,
  isStuck,
  findLatestSemasZip,
  refreshPublicPlaces,
};
