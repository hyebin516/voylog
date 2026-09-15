/**
 * Removes (soft-deletes) already-imported public-dataset places whose names
 * were cut off in the source data -- "타르틴(타르틴베이커리서울 코리아",
 * "분식·", "스타벅스 대". The importers skip these rows from now on; this
 * cleans up what was loaded before that check existed.
 *
 *   node scripts/remove-broken-place-names.js          # preview only
 *   node scripts/remove-broken-place-names.js --apply  # remove them
 *
 * Video places and bookmarked places are never removed.
 */
const pool = require('../src/config/db');
const publicPlaceRepository = require('../src/repositories/public-place.repository');
const { isBrokenPlaceName, isBrokenBranchName } = require('../src/services/public-place-mapper');

function isBroken(place) {
  if (isBrokenPlaceName(place.name)) return true;
  // The importer stored 상가정보 names as "상호명 지점명".
  if (place.source === 'semas') {
    const tokens = place.name.split(' ');
    return tokens.length >= 2 && isBrokenBranchName(tokens[tokens.length - 1]);
  }
  return false;
}

async function main() {
  const apply = process.argv.includes('--apply');
  const suspects = await publicPlaceRepository.findDatasetPlacesWithSuspectNames();
  const broken = suspects.filter(isBroken);

  console.log(`${broken.length} broken names out of ${suspects.length} suspects`);
  broken.slice(0, 50).forEach((place) => console.log(`  ${place.source} | ${place.name}`));

  if (!apply) {
    console.log('Preview only. Re-run with --apply to remove them.');
    return;
  }
  const removed = await publicPlaceRepository.removeDatasetPlaces(broken.map((place) => place.place_id));
  console.log(`Removed ${removed} places.`);
}

main()
  .catch((err) => {
    console.error(err.message);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
