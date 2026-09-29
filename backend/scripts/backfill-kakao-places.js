/**
 * Backfills courses kept before Kakao-search places were written into
 * `places` (migration 032).
 *
 * Those snapshots still hold "kakao:<id>" instead of a place id, so their
 * places cannot be bookmarked from the course and a like on the published
 * route learns nothing from them. This writes each one into `places` and
 * rewrites the snapshot to point at it. Re-running is safe: the upsert is
 * keyed on (source, external_id) and a snapshot with no Kakao ids is
 * skipped.
 *
 *   node scripts/backfill-kakao-places.js [--dry-run]
 */
const pool = require('../src/config/db');
const { materializeRoutePlaces, KAKAO_ID_PREFIX } = require('../src/services/kakao-place.service');

const DRY_RUN = process.argv.includes('--dry-run');

function kakaoIdCount(routeData) {
  if (!Array.isArray(routeData)) return 0;
  return routeData.filter(
    (p) => p && typeof p.placeId === 'string' && p.placeId.startsWith(KAKAO_ID_PREFIX)
  ).length;
}

async function backfillTable(table, idColumn) {
  const { rows } = await pool.query(
    `SELECT ${idColumn} AS id, route_data FROM ${table} WHERE deleted_at IS NULL`
  );

  let touched = 0;
  let resolved = 0;
  for (const row of rows) {
    const before = kakaoIdCount(row.route_data);
    if (before === 0) continue;

    if (DRY_RUN) {
      // No writing at all, not even the `places` rows -- a dry run that
      // half-applied itself would be worse than none.
      console.log(`  ${row.id}: 카카오 장소 ${before}곳 (적용 시 등록 대상)`);
      touched += 1;
      continue;
    }

    // eslint-disable-next-line no-await-in-loop
    const routeData = await materializeRoutePlaces(row.route_data);
    const after = kakaoIdCount(routeData);

    // eslint-disable-next-line no-await-in-loop
    await pool.query(
      `UPDATE ${table} SET route_data = $1, updated_at = now() WHERE ${idColumn} = $2`,
      [JSON.stringify(routeData), row.id]
    );
    touched += 1;
    resolved += before - after;
    console.log(`  ${row.id}: 카카오 장소 ${before}곳 → ${before - after}곳 해결${after ? `, ${after}곳은 좌표가 없어 그대로` : ''}`);
  }
  console.log(`${table}: ${touched}건 처리, 장소 ${resolved}곳 places에 등록${DRY_RUN ? ' (dry-run, 저장 안 함)' : ''}`);
}

(async () => {
  console.log(DRY_RUN ? '--- dry-run ---' : '--- 적용 ---');
  await backfillTable('saved_walking_courses', 'saved_course_id');
  await backfillTable('shared_routes', 'shared_route_id');
  await pool.end();
})().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
