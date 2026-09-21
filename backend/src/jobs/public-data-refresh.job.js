const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const env = require('../config/env');
const publicDataRefreshRepository = require('../repositories/public-data-refresh.repository');
const { isRefreshDue, isStuck } = require('../services/public-data-refresh.service');

/**
 * Keeps the public-dataset places no more than a month old (FR-15/FR-17).
 *
 * Checks shortly after the server starts and then once a day, so a refresh
 * missed while the server was down still happens soon after it's back --
 * a fixed "1st of the month" schedule would silently skip that month.
 * The refresh itself runs as a separate process: importing ~800k store
 * rows would otherwise stall the API for minutes.
 */

const FIRST_CHECK_DELAY_MS = 60 * 1000;
const CHECK_INTERVAL_MS = 24 * 60 * 60 * 1000;
const SCRIPT_PATH = path.resolve(__dirname, '../../scripts/refresh-public-places.js');
const LOG_PATH = path.resolve(__dirname, '../../logs/public-data-refresh.log');

let child = null;

function startRefreshProcess() {
  fs.mkdirSync(path.dirname(LOG_PATH), { recursive: true });
  const logFd = fs.openSync(LOG_PATH, 'a');
  child = spawn(process.execPath, [SCRIPT_PATH], { stdio: ['ignore', logFd, logFd], windowsHide: true });
  child.on('exit', (code) => {
    console.log(`Public data refresh process exited with code ${code} (log: ${LOG_PATH})`);
    child = null;
    fs.closeSync(logFd);
  });
}

async function checkAndRefresh() {
  if (child) return false;
  try {
    const running = await publicDataRefreshRepository.findRunning();
    if (running && !isStuck(running)) return false;
    if (!isRefreshDue(await publicDataRefreshRepository.findLastSucceeded())) return false;
    console.log('Public data is a month old -- starting a refresh in the background');
    startRefreshProcess();
    return true;
  } catch (err) {
    // A failed check just means we try again tomorrow.
    console.warn(`Public data refresh check failed: ${err.message}`);
    return false;
  }
}

function startPublicDataRefreshSchedule() {
  if (!env.publicDataRefreshEnabled) return;
  setTimeout(checkAndRefresh, FIRST_CHECK_DELAY_MS).unref();
  setInterval(checkAndRefresh, CHECK_INTERVAL_MS).unref();
}

module.exports = { startPublicDataRefreshSchedule, checkAndRefresh };
