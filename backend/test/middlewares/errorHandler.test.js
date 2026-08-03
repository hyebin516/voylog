const errorHandler = require('../../src/middlewares/errorHandler');
const AppError = require('../../src/utils/AppError');
const { mockRes } = require('../helpers/mockExpress');

describe('errorHandler', () => {
  it('formats an AppError using its own statusCode/code/message', () => {
    const res = mockRes();
    errorHandler(new AppError(409, 'BOOKMARK_EXISTS', 'already bookmarked'), {}, res, jest.fn());
    expect(res.statusCode).toBe(409);
    expect(res.body).toEqual({ success: false, error: { code: 'BOOKMARK_EXISTS', message: 'already bookmarked' } });
  });

  it('falls back to 500 INTERNAL_ERROR for an unrecognized error, without leaking the raw message', () => {
    const res = mockRes();
    const spy = jest.spyOn(console, 'error').mockImplementation(() => {});
    errorHandler(new Error('db connection string leaked here'), {}, res, jest.fn());
    expect(res.statusCode).toBe(500);
    expect(res.body).toEqual({ success: false, error: { code: 'INTERNAL_ERROR', message: 'An unexpected error occurred' } });
    spy.mockRestore();
  });
});
