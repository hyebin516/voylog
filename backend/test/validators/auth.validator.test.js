const {
  validateKakaoLogin,
  validateRequestOtp,
  validateVerifyOtp,
  validateSignup,
  validateLogin,
  validateUpdateNickname,
  validateCheckNickname,
  validateChangePassword,
  validateResetPassword,
} = require('../../src/validators/auth.validator');
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

describe('validateRequestOtp', () => {
  it('passes for a valid email', () => {
    const next = jest.fn();
    validateRequestOtp(mockReq({ body: { email: 'a@b.com' } }), mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects a malformed email', () => {
    const next = jest.fn();
    validateRequestOtp(mockReq({ body: { email: 'not-an-email' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });
});

describe('validateVerifyOtp', () => {
  it('passes for a valid email and 6-digit code', () => {
    const next = jest.fn();
    validateVerifyOtp(mockReq({ body: { email: 'a@b.com', code: '123456' } }), mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects a code that is not 6 digits', () => {
    const next = jest.fn();
    validateVerifyOtp(mockReq({ body: { email: 'a@b.com', code: '123' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects a malformed email', () => {
    const next = jest.fn();
    validateVerifyOtp(mockReq({ body: { email: 'nope', code: '123456' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });
});

describe('validateSignup', () => {
  it('passes for a valid email, 8+ char password, and non-empty nickname', () => {
    const next = jest.fn();
    validateSignup(mockReq({ body: { email: 'a@b.com', password: 'password123', nickname: 'Nagyeong' } }), mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects a password shorter than 8 characters', () => {
    const next = jest.fn();
    validateSignup(mockReq({ body: { email: 'a@b.com', password: 'short', nickname: 'Nagyeong' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects a missing nickname', () => {
    const next = jest.fn();
    validateSignup(mockReq({ body: { email: 'a@b.com', password: 'password123' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });
});

describe('validateLogin', () => {
  it('passes for a valid email and non-empty password', () => {
    const next = jest.fn();
    validateLogin(mockReq({ body: { email: 'a@b.com', password: 'password123' } }), mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects a missing password', () => {
    const next = jest.fn();
    validateLogin(mockReq({ body: { email: 'a@b.com' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });
});

describe('validateUpdateNickname', () => {
  it('passes for a non-empty nickname', () => {
    const next = jest.fn();
    validateUpdateNickname(mockReq({ body: { nickname: '새 닉네임' } }), mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects a missing nickname', () => {
    const next = jest.fn();
    validateUpdateNickname(mockReq({ body: {} }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects a blank/whitespace-only nickname', () => {
    const next = jest.fn();
    validateUpdateNickname(mockReq({ body: { nickname: '   ' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects a nickname longer than 100 characters', () => {
    const next = jest.fn();
    validateUpdateNickname(mockReq({ body: { nickname: 'a'.repeat(101) } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });
});

describe('validateCheckNickname', () => {
  it('passes for a non-empty nickname query param', () => {
    const next = jest.fn();
    validateCheckNickname(mockReq({ query: { nickname: '새 닉네임' } }), mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects a missing nickname query param', () => {
    const next = jest.fn();
    validateCheckNickname(mockReq({ query: {} }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects a blank/whitespace-only nickname', () => {
    const next = jest.fn();
    validateCheckNickname(mockReq({ query: { nickname: '   ' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });
});

describe('validateChangePassword', () => {
  it('passes for a valid current/new password pair', () => {
    const next = jest.fn();
    validateChangePassword(
      mockReq({ body: { currentPassword: 'old-password', newPassword: 'new-password123' } }),
      mockRes(),
      next
    );
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects a missing currentPassword', () => {
    const next = jest.fn();
    validateChangePassword(mockReq({ body: { newPassword: 'new-password123' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects a newPassword shorter than 8 characters', () => {
    const next = jest.fn();
    validateChangePassword(
      mockReq({ body: { currentPassword: 'old-password', newPassword: 'short' } }),
      mockRes(),
      next
    );
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });
});

describe('validateResetPassword', () => {
  it('passes for a valid email and 8+ char newPassword', () => {
    const next = jest.fn();
    validateResetPassword(mockReq({ body: { email: 'a@b.com', newPassword: 'new-password123' } }), mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects a malformed email', () => {
    const next = jest.fn();
    validateResetPassword(mockReq({ body: { email: 'nope', newPassword: 'new-password123' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects a newPassword shorter than 8 characters', () => {
    const next = jest.fn();
    validateResetPassword(mockReq({ body: { email: 'a@b.com', newPassword: 'short' } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });
});
