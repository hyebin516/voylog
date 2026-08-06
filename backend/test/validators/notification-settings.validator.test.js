const { validateUpdateNotificationSettings } = require('../../src/validators/notification-settings.validator');
const { mockReq, mockRes } = require('../helpers/mockExpress');
const AppError = require('../../src/utils/AppError');

describe('validateUpdateNotificationSettings', () => {
  it('passes when all three fields are booleans', () => {
    const next = jest.fn();
    validateUpdateNotificationSettings(
      mockReq({ body: { tripAlerts: true, serviceAlerts: false, marketingAlerts: true } }),
      mockRes(),
      next
    );
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects when a field is missing', () => {
    const next = jest.fn();
    validateUpdateNotificationSettings(mockReq({ body: { tripAlerts: true, serviceAlerts: false } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects when a field is not a boolean', () => {
    const next = jest.fn();
    validateUpdateNotificationSettings(
      mockReq({ body: { tripAlerts: 'yes', serviceAlerts: false, marketingAlerts: true } }),
      mockRes(),
      next
    );
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });
});
