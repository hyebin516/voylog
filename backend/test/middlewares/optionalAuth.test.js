const jwt = require('jsonwebtoken');
const optionalAuthenticate = require('../../src/middlewares/optionalAuth');
const { mockReq, mockRes } = require('../helpers/mockExpress');

const SECRET = process.env.JWT_SECRET;

describe('optionalAuthenticate middleware', () => {
  it('attaches the decoded payload to req.user and calls next() for a valid token', () => {
    const token = jwt.sign({ userId: 'user-1' }, SECRET, { expiresIn: '1h' });
    const req = mockReq({ headers: { authorization: `Bearer ${token}` } });
    const next = jest.fn();

    optionalAuthenticate(req, mockRes(), next);

    expect(next).toHaveBeenCalledWith();
    expect(req.user.userId).toBe('user-1');
  });

  it('calls next() without req.user when there is no Authorization header (guest request)', () => {
    const req = mockReq();
    const next = jest.fn();

    optionalAuthenticate(req, mockRes(), next);

    expect(next).toHaveBeenCalledWith();
    expect(req.user).toBeUndefined();
  });

  it('calls next() without req.user when the token is invalid, instead of rejecting', () => {
    const req = mockReq({ headers: { authorization: 'Bearer not-a-real-token' } });
    const next = jest.fn();

    optionalAuthenticate(req, mockRes(), next);

    expect(next).toHaveBeenCalledWith();
    expect(req.user).toBeUndefined();
  });

  it('calls next() without req.user when the token is expired', () => {
    const token = jwt.sign({ userId: 'user-1' }, SECRET, { expiresIn: -10 });
    const req = mockReq({ headers: { authorization: `Bearer ${token}` } });
    const next = jest.fn();

    optionalAuthenticate(req, mockRes(), next);

    expect(next).toHaveBeenCalledWith();
    expect(req.user).toBeUndefined();
  });
});
