jest.mock('../../src/repositories/notification-settings.repository');

const notificationSettingsRepository = require('../../src/repositories/notification-settings.repository');
const notificationSettingsService = require('../../src/services/notification-settings.service');

const USER_ID = 'user-1';

afterEach(() => jest.clearAllMocks());

describe('getSettings', () => {
  it('returns the saved settings when they exist', async () => {
    notificationSettingsRepository.find.mockResolvedValue({
      user_id: USER_ID,
      trip_start_alerts: false,
      route_complete_alerts: true,
      marketing_alerts: true,
      night_silent: true,
    });

    const settings = await notificationSettingsService.getSettings(USER_ID);

    expect(settings).toEqual({
      user_id: USER_ID,
      trip_start_alerts: false,
      route_complete_alerts: true,
      marketing_alerts: true,
      night_silent: true,
    });
  });

  it('returns default settings when the user has none saved yet', async () => {
    notificationSettingsRepository.find.mockResolvedValue(null);

    const settings = await notificationSettingsService.getSettings(USER_ID);

    expect(settings).toEqual({
      user_id: USER_ID,
      trip_start_alerts: true,
      route_complete_alerts: true,
      marketing_alerts: false,
      night_silent: false,
    });
  });
});

describe('updateSettings', () => {
  it('upserts the given settings for the user', async () => {
    const input = { tripStartAlerts: false, routeCompleteAlerts: false, marketingAlerts: true, nightSilent: true };
    notificationSettingsRepository.upsert.mockResolvedValue({ user_id: USER_ID, ...input });

    await notificationSettingsService.updateSettings(USER_ID, input);

    expect(notificationSettingsRepository.upsert).toHaveBeenCalledWith(USER_ID, input);
  });
});
