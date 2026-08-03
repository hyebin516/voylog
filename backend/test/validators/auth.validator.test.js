const { validateKakaoLogin } = require('../../src/validators/auth.validator');
const { mockReq, mockRes } = require('../helpers/mockExpress');
const AppError = require('../../src/utils/AppError');

describe('validateKakaoLogin', () => {
  it('passes for a string kakaoAccessToken', () => {
    const next = jest.fn();
    validateKakaoLogin(mockReq({ body: { kakaoAccessToken: 'abc123' } }), mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects a missing kakaoAccessToken', () => {
    const next = jest.fn();
    validateKakaoLogin(mockReq({ body: {} }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects a non-string kakaoAccessToken', () => {
    const next = jest.fn();
    validateKakaoLogin(mockReq({ body: { kakaoAccessToken: 12345 } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });
});
