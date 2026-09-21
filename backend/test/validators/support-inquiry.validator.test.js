const { validateSubmitInquiry } = require('../../src/validators/support-inquiry.validator');

function run(body) {
  const req = { body };
  const next = jest.fn();
  validateSubmitInquiry(req, {}, next);
  return { error: next.mock.calls[0][0], req };
}

const VALID = { email: 'a@b.com', category: 'bug', message: '분석이 멈춰요' };

describe('validateSubmitInquiry', () => {
  it('accepts a complete inquiry and trims what it stores', () => {
    const { error, req } = run({ ...VALID, email: '  a@b.com ', message: '  분석이 멈춰요  ' });

    expect(error).toBeUndefined();
    expect(req.body.email).toBe('a@b.com');
    expect(req.body.message).toBe('분석이 멈춰요');
  });

  it('rejects a missing or malformed email -- there would be no way to answer', () => {
    expect(run({ ...VALID, email: undefined }).error).toMatchObject({ statusCode: 400, code: 'INVALID_REQUEST' });
    expect(run({ ...VALID, email: 'not-an-email' }).error).toMatchObject({ statusCode: 400 });
  });

  it('rejects an unknown category', () => {
    expect(run({ ...VALID, category: 'refund' }).error).toMatchObject({ statusCode: 400 });
    expect(run({ ...VALID, category: undefined }).error).toMatchObject({ statusCode: 400 });
  });

  it('rejects an empty message', () => {
    expect(run({ ...VALID, message: '   ' }).error).toMatchObject({ statusCode: 400 });
  });

  it('rejects a message longer than the limit', () => {
    expect(run({ ...VALID, message: 'x'.repeat(2001) }).error).toMatchObject({ statusCode: 400 });
    expect(run({ ...VALID, message: 'x'.repeat(2000) }).error).toBeUndefined();
  });
});
