jest.mock('../../src/services/trip-start-alert.service', () => ({
  sendDueTripStartAlerts: jest.fn(),
  isWithinSendWindow: jest.requireActual('../../src/services/trip-start-alert.service').isWithinSendWindow,
}));

const { sendDueTripStartAlerts } = require('../../src/services/trip-start-alert.service');
const { checkAndSend } = require('../../src/jobs/trip-start-alert.job');

// 12:00 and 03:00 in Asia/Seoul.
const AT_MIDDAY = new Date('2026-09-21T03:00:00Z');
const AT_NIGHT = new Date('2026-09-21T18:00:00Z');

afterEach(() => jest.clearAllMocks());

describe('checkAndSend', () => {
  it('runs the sweep during the day', async () => {
    sendDueTripStartAlerts.mockResolvedValue({ sent: 2, considered: 3 });

    expect(await checkAndSend(AT_MIDDAY)).toEqual({ sent: 2, considered: 3 });
    expect(sendDueTripStartAlerts).toHaveBeenCalledWith(AT_MIDDAY);
  });

  it('does not wake anybody up at night', async () => {
    expect(await checkAndSend(AT_NIGHT)).toEqual({ sent: 0, considered: 0, skipped: 'outside send window' });
    expect(sendDueTripStartAlerts).not.toHaveBeenCalled();
  });

  it('swallows a failed sweep so the hourly schedule keeps running', async () => {
    sendDueTripStartAlerts.mockRejectedValue(new Error('db down'));
    jest.spyOn(console, 'warn').mockImplementation(() => {});

    expect(await checkAndSend(AT_MIDDAY)).toEqual({ sent: 0, considered: 0, skipped: 'error' });
  });
});
