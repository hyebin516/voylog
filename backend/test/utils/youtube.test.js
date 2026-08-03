const { extractYoutubeVideoId } = require('../../src/utils/youtube');

describe('extractYoutubeVideoId', () => {
  it('extracts the id from a watch url', () => {
    expect(extractYoutubeVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ')).toBe('dQw4w9WgXcQ');
  });

  it('extracts the id from a watch url with extra query params', () => {
    expect(extractYoutubeVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=30s')).toBe('dQw4w9WgXcQ');
  });

  it('extracts the id from a youtu.be short url', () => {
    expect(extractYoutubeVideoId('https://youtu.be/dQw4w9WgXcQ')).toBe('dQw4w9WgXcQ');
  });

  it('returns null when no id is present', () => {
    expect(extractYoutubeVideoId('https://example.com/not-youtube')).toBeNull();
  });
});
