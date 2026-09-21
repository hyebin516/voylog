jest.mock('../../src/repositories/public-place.repository');
jest.mock('../../src/repositories/public-data-refresh.repository');
jest.mock('../../src/services/public-place-import.service');

const fs = require('fs');
const os = require('os');
const path = require('path');
const publicPlaceRepository = require('../../src/repositories/public-place.repository');
const publicDataRefreshRepository = require('../../src/repositories/public-data-refresh.repository');
const { importTourApi } = require('../../src/services/public-place-import.service');
const {
  isRefreshDue,
  isStuck,
  findLatestSemasZip,
  refreshPublicPlaces,
} = require('../../src/services/public-data-refresh.service');

const DAY_MS = 24 * 60 * 60 * 1000;
const NOW = new Date('2026-10-20T00:00:00Z');

afterEach(() => jest.clearAllMocks());

describe('isRefreshDue', () => {
  it('is due when nothing has ever succeeded', () => {
    expect(isRefreshDue(null, NOW)).toBe(true);
  });

  it('is due once 30 days have passed since the last successful run', () => {
    expect(isRefreshDue({ started_at: new Date(NOW - 30 * DAY_MS) }, NOW)).toBe(true);
    expect(isRefreshDue({ started_at: new Date(NOW - 29 * DAY_MS) }, NOW)).toBe(false);
  });
});

describe('isStuck', () => {
  it('treats a run that never finished within 6 hours as stuck', () => {
    expect(isStuck({ started_at: new Date(NOW - 7 * 60 * 60 * 1000) }, NOW)).toBe(true);
    expect(isStuck({ started_at: new Date(NOW - 60 * 60 * 1000) }, NOW)).toBe(false);
  });
});

describe('findLatestSemasZip', () => {
  it('picks the newest edition by the date in the file name', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'seed-'));
    ['소상공인시장진흥공단_상가(상권)정보_20260630.zip', '소상공인시장진흥공단_상가(상권)정보_20260930.zip', 'notes.txt'].forEach(
      (file) => fs.writeFileSync(path.join(dir, file), '')
    );

    expect(findLatestSemasZip(dir)).toEqual({
      path: path.join(dir, '소상공인시장진흥공단_상가(상권)정보_20260930.zip'),
      edition: '20260930',
    });
  });

  it('returns null when the folder is missing or has no dataset zip', () => {
    expect(findLatestSemasZip(path.join(os.tmpdir(), 'does-not-exist-seed'))).toBeNull();
  });
});

describe('refreshPublicPlaces', () => {
  const startedAt = new Date('2026-10-20T04:00:00Z');

  beforeEach(() => {
    publicDataRefreshRepository.start.mockResolvedValue({ refresh_id: 'r1', started_at: startedAt });
    publicDataRefreshRepository.findLatestSemasEdition.mockResolvedValue('20260630');
    publicPlaceRepository.removeDuplicateDatasetPlaces.mockResolvedValue(3);
  });

  function emptySeedDir() {
    return fs.mkdtempSync(path.join(os.tmpdir(), 'seed-'));
  }

  it('re-imports TourAPI, removes places it no longer lists, and skips 상가정보 without a newer zip', async () => {
    importTourApi.mockResolvedValue(29000);
    publicPlaceRepository.countActive.mockResolvedValue(29400);
    publicPlaceRepository.removeStaleDatasetPlaces.mockResolvedValue(12);

    const summary = await refreshPublicPlaces({ seedDir: emptySeedDir() });

    expect(publicPlaceRepository.removeStaleDatasetPlaces).toHaveBeenCalledWith('tour_api', startedAt);
    expect(publicPlaceRepository.removeStaleDatasetPlaces).toHaveBeenCalledTimes(1);
    expect(summary).toEqual({ tourApiWritten: 29000, semasWritten: null, semasEdition: null, removedCount: 15 });
    expect(publicDataRefreshRepository.finish).toHaveBeenCalledWith('r1', expect.objectContaining({ status: 'succeeded' }));
  });

  it('keeps existing places when an import wrote suspiciously few of them', async () => {
    importTourApi.mockResolvedValue(1000); // e.g. the API returned a partial set
    publicPlaceRepository.countActive.mockResolvedValue(29400);

    await refreshPublicPlaces({ seedDir: emptySeedDir() });

    expect(publicPlaceRepository.removeStaleDatasetPlaces).not.toHaveBeenCalled();
  });

  it('records a failed run and rethrows', async () => {
    importTourApi.mockRejectedValue(new Error('TourAPI page 3 failed: timeout'));

    await expect(refreshPublicPlaces({ seedDir: emptySeedDir() })).rejects.toThrow('TourAPI page 3 failed');

    expect(publicDataRefreshRepository.finish).toHaveBeenCalledWith(
      'r1',
      expect.objectContaining({ status: 'failed', error: 'TourAPI page 3 failed: timeout' })
    );
    expect(publicPlaceRepository.removeStaleDatasetPlaces).not.toHaveBeenCalled();
  });
});
