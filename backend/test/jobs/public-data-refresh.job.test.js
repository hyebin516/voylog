jest.mock('../../src/repositories/public-data-refresh.repository');
jest.mock('child_process', () => ({ spawn: jest.fn() }));

const { spawn } = require('child_process');
const publicDataRefreshRepository = require('../../src/repositories/public-data-refresh.repository');
const { checkAndRefresh } = require('../../src/jobs/public-data-refresh.job');

const DAY_MS = 24 * 60 * 60 * 1000;

function fakeChild() {
  const handlers = {};
  return { on: (event, fn) => { handlers[event] = fn; }, exit: (code) => handlers.exit(code) };
}

afterEach(() => jest.clearAllMocks());

describe('checkAndRefresh', () => {
  it('starts a refresh process when the last successful one is a month old', async () => {
    const child = fakeChild();
    spawn.mockReturnValue(child);
    publicDataRefreshRepository.findRunning.mockResolvedValue(null);
    publicDataRefreshRepository.findLastSucceeded.mockResolvedValue({ started_at: new Date(Date.now() - 31 * DAY_MS) });

    expect(await checkAndRefresh()).toBe(true);
    expect(spawn).toHaveBeenCalledWith(
      process.execPath,
      [expect.stringContaining('refresh-public-places.js')],
      expect.any(Object)
    );
    child.exit(0);
  });

  it('does nothing while the data is less than a month old', async () => {
    publicDataRefreshRepository.findRunning.mockResolvedValue(null);
    publicDataRefreshRepository.findLastSucceeded.mockResolvedValue({ started_at: new Date(Date.now() - 3 * DAY_MS) });

    expect(await checkAndRefresh()).toBe(false);
    expect(spawn).not.toHaveBeenCalled();
  });

  it('does not start a second refresh while one is running', async () => {
    publicDataRefreshRepository.findRunning.mockResolvedValue({ started_at: new Date(Date.now() - 60 * 1000) });

    expect(await checkAndRefresh()).toBe(false);
    expect(spawn).not.toHaveBeenCalled();
  });

  it('survives a failing check', async () => {
    publicDataRefreshRepository.findRunning.mockRejectedValue(new Error('db down'));
    jest.spyOn(console, 'warn').mockImplementation(() => {});

    expect(await checkAndRefresh()).toBe(false);
  });
});
