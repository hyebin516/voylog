const pool = require('../config/db');

/** Monthly public-dataset refresh runs (migration 026). */

async function start() {
  const { rows } = await pool.query(
    "INSERT INTO public_data_refreshes (status) VALUES ('running') RETURNING refresh_id, started_at"
  );
  return rows[0];
}

async function finish(refreshId, { status, semasEdition = null, tourApiWritten = null, semasWritten = null, removedCount = null, error = null }) {
  await pool.query(
    `UPDATE public_data_refreshes
     SET status = $2, semas_edition = $3, tour_api_written = $4, semas_written = $5,
         removed_count = $6, error = $7, finished_at = now(), updated_at = now()
     WHERE refresh_id = $1`,
    [refreshId, status, semasEdition, tourApiWritten, semasWritten, removedCount, error]
  );
}

async function findLastSucceeded() {
  const { rows } = await pool.query(
    "SELECT * FROM public_data_refreshes WHERE status = 'succeeded' ORDER BY started_at DESC LIMIT 1"
  );
  return rows[0] || null;
}

/** The newest 상가정보 edition any successful run imported. */
async function findLatestSemasEdition() {
  const { rows } = await pool.query(
    "SELECT MAX(semas_edition) AS edition FROM public_data_refreshes WHERE status = 'succeeded'"
  );
  return rows[0].edition || null;
}

async function findRunning() {
  const { rows } = await pool.query(
    "SELECT * FROM public_data_refreshes WHERE status = 'running' ORDER BY started_at DESC LIMIT 1"
  );
  return rows[0] || null;
}

module.exports = { start, finish, findLastSucceeded, findLatestSemasEdition, findRunning };
