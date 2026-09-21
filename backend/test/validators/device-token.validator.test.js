const { validateRegisterDeviceToken } = require('../../src/validators/device-token.validator');

function run(body) {
  const next = jest.fn();
  validateRegisterDeviceToken({ body }, {}, next);
  return next.mock.calls[0][0];
}

describe('validateRegisterDeviceToken', () => {
  it('accepts a token with a supported platform', () => {
    expect(run({ token: 'fcm-token', platform: 'android' })).toBeUndefined();
    expect(run({ token: 'fcm-token', platform: 'ios' })).toBeUndefined();
  });

  it('rejects a missing or blank token', () => {
    expect(run({ platform: 'android' })).toMatchObject({ statusCode: 400, code: 'INVALID_REQUEST' });
    expect(run({ token: '   ', platform: 'android' })).toMatchObject({ statusCode: 400 });
  });

  it('rejects a platform the push service does not know', () => {
    expect(run({ token: 'fcm-token', platform: 'web' })).toMatchObject({ statusCode: 400 });
    expect(run({ token: 'fcm-token' })).toMatchObject({ statusCode: 400 });
  });
});
