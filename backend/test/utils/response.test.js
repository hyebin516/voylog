const { success, failure } = require('../../src/utils/response');

function mockRes() {
  return {
    statusCode: null,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(body) {
      this.body = body;
      return this;
    },
  };
}

describe('response helpers', () => {
  it('success() wraps data in the standard success envelope with a 200 default', () => {
    const res = mockRes();
    success(res, { foo: 'bar' });
    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual({ success: true, data: { foo: 'bar' } });
  });

  it('success() honors a custom status code', () => {
    const res = mockRes();
    success(res, { id: 1 }, 201);
    expect(res.statusCode).toBe(201);
  });

  it('failure() wraps the error in the standard failure envelope', () => {
    const res = mockRes();
    failure(res, 404, 'NOT_FOUND', 'missing');
    expect(res.statusCode).toBe(404);
    expect(res.body).toEqual({ success: false, error: { code: 'NOT_FOUND', message: 'missing' } });
  });
});
