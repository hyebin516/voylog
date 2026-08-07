const { validateSetPreferences } = require('../../src/validators/taste-preference.validator');
const { mockReq, mockRes } = require('../helpers/mockExpress');
const AppError = require('../../src/utils/AppError');

describe('validateSetPreferences', () => {
  it('passes for a non-empty array of tag strings', () => {
    const next = jest.fn();
    validateSetPreferences(mockReq({ body: { tags: ['소금빵', '오션뷰'] } }), mockRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it('rejects a missing tags field', () => {
    const next = jest.fn();
    validateSetPreferences(mockReq({ body: {} }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects an empty array', () => {
    const next = jest.fn();
    validateSetPreferences(mockReq({ body: { tags: [] } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects an array containing a non-string', () => {
    const next = jest.fn();
    validateSetPreferences(mockReq({ body: { tags: ['소금빵', 123] } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });

  it('rejects an array containing a blank string', () => {
    const next = jest.fn();
    validateSetPreferences(mockReq({ body: { tags: ['   '] } }), mockRes(), next);
    expect(next.mock.calls[0][0]).toBeInstanceOf(AppError);
  });
});
