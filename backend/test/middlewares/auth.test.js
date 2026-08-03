const jwt = require('jsonwebtoken');
const authenticate = require('../../src/middlewares/auth');
const { mockReq, mockRes } = require('../helpers/mockExpress');
const AppError = require('../../src/utils/AppError');

const SECRET = process.env.JWT_SECRET;

describe('authenticate middleware', () => {
  it('attaches the decoded payload to req.user and calls next() for a valid token', () => {
    const token = jwt.sign({ userId: 'user-1' }, SECRET, { expiresIn: '1h' });
    const req = mockReq({ headers: { authorization: `Bearer ${token}` } });
    const next = jest.fn();
    authenticate(req, mockRes(), next);
    expect(next).toHaveBeenCalledWith();
    expect(req.user.userId).toBe('user-1');
  });

  it('rejects a missing Authorization header with 401 JWT_INVALID', () => {
    const next = jest.fn();
    authenticate(mockReq(), mockRes(), next);
    const err = next.mock.calls[0][0];
    expect(err).toBeInstanceOf(AppError);
    expect(err.statusCode).toBe(401);
    expect(err.code).toBe('JWT_INVALID');
  });

  it('rejects a header that is not a Bearer token with 401 JWT_INVALID', () => {
    const next = jest.fn();
    authenticate(mockReq({ headers: { authorization: 'Basic abc123' } }), mockRes(), next);
    expect(next.mock.calls[0][0].code).toBe('JWT_INVALID');
  });

  it('rejects a malformed token with 401 JWT_INVALID', () => {
    const next = jest.fn();
    authenticate(mockReq({ headers: { authorization: 'Bearer not-a-real-token' } }), mockRes(), next);
    expect(next.mock.calls[0][0].code).toBe('JWT_INVALID');
  });

  it('rejects an expired token with 403 JWT_EXPIRED', () => {
    const token = jwt.sign({ userId: 'user-1' }, SECRET, { expiresIn: -10 });
    const next = jest.fn();
    authenticate(mockReq({ headers: { authorization: `Bearer ${token}` } }), mockRes(), next);
    const err = next.mock.calls[0][0];
    expect(err.statusCode).toBe(403);
    expect(err.code).toBe('JWT_EXPIRED');
  });
});
