const {
  validateKakaoLogin,
  validateRequestOtp,
  validateVerifyOtp,
  validateSignup,
  validateLogin,
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
