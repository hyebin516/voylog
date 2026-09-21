jest.mock('../../src/repositories/trip.repository');
jest.mock('../../src/services/push.service');

const tripRepository = require('../../src/repositories/trip.repository');
const pushService = require('../../src/services/push.service');
const {
  sendDueTripStartAlerts,
  tomorrowInAppZone,
  isWithinSendWindow,
} = require('../../src/services/trip-start-alert.service');

// 12:00, 23:00 and 08:00 in Asia/Seoul.
const AT_MIDDAY = new Date('2026-09-21T03:00:00Z');
const AT_NIGHT = new Date('2026-09-21T14:00:00Z');
const AT_EARLY_MORNING = new Date('2026-09-20T23:00:00Z');

beforeEach(() => {
  tripRepository.findStartingOnWithoutAlert.mockResolvedValue([]);
  tripRepository.markStartAlertSent.mockResolvedValue(undefined);
  pushService.sendToUser.mockResolvedValue({ sent: 1 });
});

afterEach(() => jest.clearAllMocks());

describe('working out which day is "tomorrow"', () => {
  it('uses Asia/Seoul, so a server in another zone does not shift a Korean trip', () => {
    // 23:00 UTC on the 20th is already the 21st in Seoul.
    expect(tomorrowInAppZone(AT_EARLY_MORNING)).toBe('2026-09-22');
    expect(tomorrowInAppZone(AT_MIDDAY)).toBe('2026-09-22');
  });

  it('rolls over month and year ends', () => {
    expect(tomorrowInAppZone(new Date('2026-09-30T03:00:00Z'))).toBe('2026-10-01');
    expect(tomorrowInAppZone(new Date('2026-12-31T03:00:00Z'))).toBe('2027-01-01');
  });
});

describe('the send window', () => {
  it('is open during the day', () => {
    expect(isWithinSendWindow(AT_MIDDAY)).toBe(true);
  });

  it('is shut at night, so a night-silenced user is not marked as told', () => {
    expect(isWithinSendWindow(AT_NIGHT)).toBe(false);
    expect(isWithinSendWindow(AT_EARLY_MORNING)).toBe(false);
  });
});

describe('sendDueTripStartAlerts', () => {
  const TRIP = { trip_id: 't1', user_id: 'u1', name: '부산 2박 3일' };

  it('reminds the owner of each trip starting tomorrow and marks it sent', async () => {
    tripRepository.findStartingOnWithoutAlert.mockResolvedValue([TRIP]);

    const result = await sendDueTripStartAlerts(AT_MIDDAY);

    expect(tripRepository.findStartingOnWithoutAlert).toHaveBeenCalledWith('2026-09-22');
    expect(pushService.sendToUser).toHaveBeenCalledWith(
      'u1',
      expect.objectContaining({ kind: 'tripStart', body: expect.stringContaining('부산 2박 3일') })
    );
    expect(tripRepository.markStartAlertSent).toHaveBeenCalledWith('t1');
    expect(result).toEqual({ sent: 1, considered: 1 });
  });

  it('sends nothing when no trip starts tomorrow', async () => {
    const result = await sendDueTripStartAlerts(AT_MIDDAY);

    expect(pushService.sendToUser).not.toHaveBeenCalled();
    expect(result).toEqual({ sent: 0, considered: 0 });
  });

  it('marks a trip whose owner turned the alert off, so it is not reconsidered daily', async () => {
    tripRepository.findStartingOnWithoutAlert.mockResolvedValue([TRIP]);
    pushService.sendToUser.mockResolvedValue({ sent: 0, skipped: 'turned off' });

    const result = await sendDueTripStartAlerts(AT_MIDDAY);

    expect(tripRepository.markStartAlertSent).toHaveBeenCalledWith('t1');
    expect(result).toEqual({ sent: 0, considered: 1 });
  });

  it('leaves a trip unmarked when the push could not be attempted at all', async () => {
    tripRepository.findStartingOnWithoutAlert.mockResolvedValue([TRIP]);
    pushService.sendToUser.mockResolvedValue({ sent: 0, skipped: 'firebase not configured' });

    await sendDueTripStartAlerts(AT_MIDDAY);

    expect(tripRepository.markStartAlertSent).not.toHaveBeenCalled();
  });
});
