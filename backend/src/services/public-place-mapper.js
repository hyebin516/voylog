const { classifyTourApiItem, classifySemasRow, toPlaceTags } = require('./public-place-classification');

/**
 * Turns raw public-dataset records into `places` rows for the importer
 * scripts (backend/scripts/import-*.js). Pure functions only -- the scripts
 * own fetching, file reading and writing to the DB.
 */

// Keeps imports inside Korea's bounding box; both datasets occasionally
// carry 0,0 or swapped coordinates, which would place a shop in the ocean
// and in every "nearby" list's bounding box math.
const KOREA_BOUNDS = { minLat: 33, maxLat: 39, minLng: 124, maxLng: 132 };

function toCoordinate(value) {
  const number = Number.parseFloat(value);
  return Number.isFinite(number) ? number : null;
}

function isInKorea(latitude, longitude) {
  return (
    latitude != null &&
    longitude != null &&
    latitude >= KOREA_BOUNDS.minLat &&
    latitude <= KOREA_BOUNDS.maxLat &&
    longitude >= KOREA_BOUNDS.minLng &&
    longitude <= KOREA_BOUNDS.maxLng
  );
}

function cleanText(value) {
  const text = (value || '').trim();
  return text === '' ? null : text;
}

function count(text, char) {
  return text.split(char).length - 1;
}

/**
 * True for a name that was cut off or mangled in the source data, e.g.
 * "타르틴(타르틴베이커리서울 코리아" or "앤디관)" -- an unpaired bracket -- or
 * "분식·" / "&마왕푸드 동대문" -- a connector left dangling at an edge.
 *
 * Short names are deliberately NOT treated as broken: "별", "숲", "강릉의 밤"
 * and "모주체험 여" are real place names.
 */
function isBrokenPlaceName(name) {
  if (!name) return true;
  if (count(name, '(') !== count(name, ')') || count(name, '[') !== count(name, ']')) return true;
  return /^[)\]&·,/]/.test(name) || /[(\[&·,/]$/.test(name);
}

/**
 * A 상가정보 지점명 of one syllable that isn't a real branch word ("스타벅스"
 * + "대") is the tail of a truncated branch name.
 */
function isBrokenBranchName(branch) {
  return /^[가-힣]$/.test(branch) && branch !== '점';
}

/**
 * @param {object} item one item from TourAPI areaBasedList2
 * @returns {object | null} a place row, or null when the item isn't usable
 */
function tourApiItemToPlace(item) {
  const classification = classifyTourApiItem(item);
  if (!classification) return null;

  const name = cleanText(item.title);
  const latitude = toCoordinate(item.mapy);
  const longitude = toCoordinate(item.mapx);
  if (!name || isBrokenPlaceName(name) || !item.contentid || !isInKorea(latitude, longitude)) return null;

  return {
    source: 'tour_api',
    externalId: String(item.contentid),
    name,
    address: cleanText([item.addr1, item.addr2].filter(Boolean).join(' ')),
    latitude,
    longitude,
    category: classification.category,
    tags: toPlaceTags(classification.tags),
  };
}

/**
 * Splits one line of the SEMAS CSV. Every field in the file is quoted, but
 * this also accepts unquoted fields and "" escapes so a format tweak in a
 * later release can't silently shift columns.
 */
function parseCsvLine(line) {
  const fields = [];
  let field = '';
  let inQuotes = false;
  for (let i = 0; i < line.length; i += 1) {
    const char = line[i];
    if (inQuotes) {
      if (char === '"' && line[i + 1] === '"') {
        field += '"';
        i += 1;
      } else if (char === '"') {
        inQuotes = false;
      } else {
        field += char;
      }
    } else if (char === '"') {
      inQuotes = true;
    } else if (char === ',') {
      fields.push(field);
      field = '';
    } else {
      field += char;
    }
  }
  fields.push(field);
  return fields;
}

const SEMAS_COLUMNS = {
  id: '상가업소번호',
  name: '상호명',
  branch: '지점명',
  subcategoryCode: '상권업종소분류코드',
  roadAddress: '도로명주소',
  lotAddress: '지번주소',
  longitude: '경도',
  latitude: '위도',
};

/**
 * Column positions looked up by header name rather than hardcoded, so a
 * reordered release fails loudly here instead of importing garbage.
 */
function semasColumnIndex(headerFields) {
  const index = {};
  for (const [key, header] of Object.entries(SEMAS_COLUMNS)) {
    const position = headerFields.indexOf(header);
    if (position === -1) {
      throw new Error(`SEMAS CSV is missing the "${header}" column`);
    }
    index[key] = position;
  }
  return index;
}

/**
 * @param {string[]} fields one parsed CSV row
 * @param {object} columnIndex from semasColumnIndex
 * @returns {object | null} a place row, or null when the row isn't usable
 */
function semasRowToPlace(fields, columnIndex) {
  const classification = classifySemasRow(fields[columnIndex.subcategoryCode]);
  if (!classification) return null;

  const baseName = cleanText(fields[columnIndex.name]);
  const branch = cleanText(fields[columnIndex.branch]);
  const latitude = toCoordinate(fields[columnIndex.latitude]);
  const longitude = toCoordinate(fields[columnIndex.longitude]);
  const externalId = cleanText(fields[columnIndex.id]);
  if (!baseName || !externalId || !isInKorea(latitude, longitude)) return null;
  if (branch && isBrokenBranchName(branch)) return null;

  // 지점명 is what tells two franchise branches apart ("스타벅스 판교점").
  const name = branch ? `${baseName} ${branch}` : baseName;
  if (isBrokenPlaceName(name)) return null;

  return {
    source: 'semas',
    externalId,
    name,
    address: cleanText(fields[columnIndex.roadAddress]) || cleanText(fields[columnIndex.lotAddress]),
    latitude,
    longitude,
    category: classification.category,
    tags: toPlaceTags(classification.tags),
  };
}

module.exports = {
  isBrokenPlaceName,
  isBrokenBranchName,
  tourApiItemToPlace,
  parseCsvLine,
  semasColumnIndex,
  semasRowToPlace,
};
