// FR-12 push sending. Every test loads the service fresh: it initialises
// the Firebase SDK once per process and remembers the result.
const KEY_PATH = 'C:/fake/firebase-service-account.json';

// 23:00 and 12:00 in Asia/Seoul -- the app's zone, not the server's.
const AT_NIGHT = new Date('2026-09-21T14:00:00Z');
const AT_MIDDAY = new Date('2026-09-21T03:00:00Z');

function loadService({ configured = true, keyExists = true, sendResult } = {}) {
  jest.resetModules();

  const actualFs = jest.requireActual('fs');
  jest.doMock('fs', () => ({
    ...actualFs,
    existsSync: (p) => (p === KEY_PATH ? keyExists : actualFs.existsSync(p)),
    readFileSync: (p, ...rest) => (p === KEY_PATH ? '{"project_id":"test"}' : actualFs.readFileSync(p, ...rest)),
  }));

  jest.doMock('../../src/config/env', () => ({ firebaseServiceAccountPath: configured ? KEY_PATH : undefined }));

  const sendEachForMulticast = jest
    .fn()
    .mockResolvedValue(sendResult || { successCount: 1, responses: [{ success: true }] });
  jest.doMock('firebase-admin', () => ({
    apps: [],
    app: jest.fn(),
    initializeApp: jest.fn(() => ({})),
    credential: { cert: jest.fn() },
    messaging: () => ({ sendEachForMulticast }),
  }));

  const deviceTokenRepository = { findByUser: jest.fn().mockResolvedValue([{ token: 'tok-1' }]), remove: jest.fn() };
  jest.doMock('../../src/repositories/device-token.repository', () => deviceTokenRepository);

  const notificationSettingsService = {
    getSettings: jest.fn().mockResolvedValue({
      trip_start_alerts: true,
      route_complete_alerts: true,
      marketing_alerts: false,
      night_silent: false,
    }),
  };
  jest.doMock('../../src/services/notification-settings.service', () => notificationSettingsService);

  // eslint-disable-next-line global-require
  const push = require('../../src/services/push.service');
  return { push, sendEachForMulticast, deviceTokenRepository, notificationSettingsService };
}

const MESSAGE = { kind: 'analysisComplete', title: '분석 완료', body: '장소를 더 찾았어요' };

afterEach(() => jest.restoreAllMocks());

describe('sendToUser respects the stored notification settings (FR-12)', () => {
  it('sends when the matching toggle is on', async () => {
    const { push, sendEachForMulticast } = loadService();

    const result = await push.sendToUser('u1', { ...MESSAGE, now: AT_MIDDAY });

    expect(result).toEqual({ sent: 1 });
    expect(sendEachForMulticast).toHaveBeenCalledWith(
      expect.objectContaining({ tokens: ['tok-1'], notification: { title: '분석 완료', body: '장소를 더 찾았어요' } })
    );
  });

  it('sends nothing when the kind is turned off', async () => {
    const { push, sendEachForMulticast, notificationSettingsService } = loadService();
    notificationSettingsService.getSettings.mockResolvedValue({ route_complete_alerts: false, night_silent: false });

    const result = await push.sendToUser('u1', { ...MESSAGE, now: AT_MIDDAY });

    expect(result).toEqual({ sent: 0, skipped: 'turned off' });
    expect(sendEachForMulticast).not.toHaveBeenCalled();
  });

  it('holds a night-time notification back for a user who silenced nights', async () => {
    const { push, sendEachForMulticast, notificationSettingsService } = loadService();
    notificationSettingsService.getSettings.mockResolvedValue({ route_complete_alerts: true, night_silent: true });

    const result = await push.sendToUser('u1', { ...MESSAGE, now: AT_NIGHT });

    expect(result).toEqual({ sent: 0, skipped: 'night silent' });
    expect(sendEachForMulticast).not.toHaveBeenCalled();
  });

  it('still sends during the day to a user who silenced nights', async () => {
    const { push, sendEachForMulticast, notificationSettingsService } = loadService();
    notificationSettingsService.getSettings.mockResolvedValue({ route_complete_alerts: true, night_silent: true });

    await push.sendToUser('u1', { ...MESSAGE, now: AT_MIDDAY });

    expect(sendEachForMulticast).toHaveBeenCalled();
  });

  it('judges night by Asia/Seoul, not the server clock', () => {
    const { push } = loadService();

    expect(push.isNightSilentNow(AT_NIGHT)).toBe(true);
    expect(push.isNightSilentNow(AT_MIDDAY)).toBe(false);
  });
});

describe('sendToUser failure handling', () => {
  it('is a no-op that says so when Firebase is not configured', async () => {
    const { push, sendEachForMulticast } = loadService({ configured: false });

    const result = await push.sendToUser('u1', { ...MESSAGE, now: AT_MIDDAY });

    expect(result).toEqual({ sent: 0, skipped: 'firebase not configured' });
    expect(sendEachForMulticast).not.toHaveBeenCalled();
  });

  it('is a no-op when the configured service-account file is missing', async () => {
    const { push } = loadService({ keyExists: false });

    await expect(push.sendToUser('u1', { ...MESSAGE, now: AT_MIDDAY })).resolves.toEqual({
      sent: 0,
      skipped: 'firebase not configured',
    });
  });

  it('says so when the user has no device registered', async () => {
    const { push, deviceTokenRepository } = loadService();
    deviceTokenRepository.findByUser.mockResolvedValue([]);

    await expect(push.sendToUser('u1', { ...MESSAGE, now: AT_MIDDAY })).resolves.toEqual({
      sent: 0,
      skipped: 'no devices',
    });
  });

  it('deletes a token FCM no longer knows, so later sends stop retrying it', async () => {
    const { push, deviceTokenRepository } = loadService({
      sendResult: {
        successCount: 1,
        responses: [{ success: true }, { error: { code: 'messaging/registration-token-not-registered' } }],
      },
    });
    deviceTokenRepository.findByUser.mockResolvedValue([{ token: 'good' }, { token: 'stale' }]);

    await push.sendToUser('u1', { ...MESSAGE, now: AT_MIDDAY });

    expect(deviceTokenRepository.remove).toHaveBeenCalledWith('stale');
    expect(deviceTokenRepository.remove).not.toHaveBeenCalledWith('good');
  });

  it('never throws -- a failed notification must not fail the job behind it', async () => {
    const { push, sendEachForMulticast } = loadService();
    sendEachForMulticast.mockRejectedValue(new Error('FCM is down'));
    jest.spyOn(console, 'warn').mockImplementation(() => {});

    await expect(push.sendToUser('u1', { ...MESSAGE, now: AT_MIDDAY })).resolves.toEqual({ sent: 0, skipped: 'error' });
  });

  it('rejects an unknown notification kind instead of sending it unguarded', async () => {
    const { push, sendEachForMulticast } = loadService();
    jest.spyOn(console, 'warn').mockImplementation(() => {});

    const result = await push.sendToUser('u1', { kind: 'nope', title: 't', body: 'b', now: AT_MIDDAY });

    expect(result).toEqual({ sent: 0, skipped: 'error' });
    expect(sendEachForMulticast).not.toHaveBeenCalled();
  });

  it('passes data values through as strings, as FCM requires', async () => {
    const { push, sendEachForMulticast } = loadService();

    await push.sendToUser('u1', { ...MESSAGE, data: { videoId: 'v1', count: 3 }, now: AT_MIDDAY });

    expect(sendEachForMulticast).toHaveBeenCalledWith(
      expect.objectContaining({ data: { kind: 'analysisComplete', videoId: 'v1', count: '3' } })
    );
  });
});
