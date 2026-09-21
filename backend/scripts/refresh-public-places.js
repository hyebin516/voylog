/**
 * One refresh of the public-dataset places (FR-15/FR-17): re-imports
 * TourAPI, imports a newer 상가(상권)정보 edition if one is in
 * database/seed-data/, and removes places the data no longer lists.
 *
 *   node scripts/refresh-public-places.js
 *
 * The backend starts this itself once a month (src/jobs/public-data-refresh.job.js);
 * run it by hand right after dropping a new 상가정보 zip into seed-data/ to
 * load it without waiting. Each run is recorded in public_data_refreshes.
 */
const path = require('path');
const pool = require('../src/config/db');
const { refreshPublicPlaces } = require('../src/services/public-data-refresh.service');

const SEED_DIR = path.resolve(__dirname, '../../database/seed-data');

function log(line) {
  console.log(`[${new Date().toISOString()}] ${line}`);
}

refreshPublicPlaces({ seedDir: SEED_DIR, log })
  .then((summary) => log(`Public place refresh done: ${JSON.stringify(summary)}`))
  .catch((err) => {
    log(`Public place refresh failed: ${err.message}`);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
