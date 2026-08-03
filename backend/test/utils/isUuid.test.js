const isUuid = require('../../src/utils/isUuid');

describe('isUuid', () => {
  it('accepts a valid v4-shaped uuid', () => {
    expect(isUuid('5ad1f447-a1e2-46a0-8093-0d007ff3071d')).toBe(true);
  });

  it('accepts uppercase hex digits', () => {
    expect(isUuid('5AD1F447-A1E2-46A0-8093-0D007FF3071D')).toBe(true);
  });

  it('rejects a non-uuid string', () => {
    expect(isUuid('not-a-uuid')).toBe(false);
  });

  it('rejects a uuid missing a segment', () => {
    expect(isUuid('5ad1f447-a1e2-46a0-8093')).toBe(false);
  });

  it('rejects non-string values', () => {
    expect(isUuid(undefined)).toBe(false);
    expect(isUuid(null)).toBe(false);
    expect(isUuid(12345)).toBe(false);
  });
});
