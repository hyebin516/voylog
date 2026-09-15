const { validateUpdateNotificationSettings } = require('../../src/validators/notification-settings.validator');
const { mockReq, mockRes } = require('../helpers/mockExpress');
const AppError = require('../../src/utils/AppError');

const VALID_BODY = { newVlogAlerts: true, routeCompleteAlerts: false, marketingAlerts: true, nightSilent: false };

describe('validateUpdateNotificationSettings', () => {
  it('passes when all four fields are booleans', () => {
    const next = jest.fn();
    validateUpdateNotificationSettings(mockReq({ body: VALID_BODY }), mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects when a field is missing', () => {
    const next = jest.fn();
    const { nightSilent, ...withoutNightSilent } = VALID_BODY;
    validateUpdateNotificationSettings(mockReq({ body: withoutNightSilent }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects when a field is not a boolean', () => {
    const next = jest.fn();
    validateUpdateNotificationSettings(
      mockReq({ body: { ...VALID_BODY, newVlogAlerts: 'yes' } }),
      mockRes(),
      next
    );
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });
});
