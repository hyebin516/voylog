const videoService = require('../../src/services/video.service');

/// A fresh analysis returns the rows in the order the LLM listed them, which
/// is not the order they appear in the video; a cached one comes back from
/// the database already sorted. The response has to be in timeline order
/// either way, because the app lists places exactly as it receives them.
describe('video analysis response ordering', () => {
  const video = {
    video_id: 'v1',
    youtube_url: 'https://youtu.be/abc',
    title: '제주 브이로그',
    enrichment_status: null,
  };

  const place = (name, timestampSec) => ({
    place_id: `p-${name}`,
    name,
    timestamp_sec: timestampSec,
    latitude: null,
    longitude: null,
    address: null,
    source: timestampSec == null ? 'description' : 'transcript',
    confidence: 0.9,
    category: null,
    business_hours: null,
    business_hours_is_estimated: false,
    tags: null,
    mention_note: null,
  });

  const namesOf = (places) =>
    videoService.__testing.toResponse(video, places, false).places.map((p) => p.name);

  it('puts the earliest place first whatever order it was given', () => {
    expect(namesOf([place('세번째', 900), place('첫번째', 60), place('두번째', 420)]))
      .toEqual(['첫번째', '두번째', '세번째']);
  });

  it('sends places with no timestamp last', () => {
    // Found in the title, description, hashtags or on-screen text -- they
    // have no position in the video, so they must not land at the top as a
    // zero would put them.
    expect(namesOf([place('자막없음', null), place('초반', 30), place('후반', 1200)]))
      .toEqual(['초반', '후반', '자막없음']);
  });

  it('keeps 0:00 ahead of a place with no timestamp', () => {
    expect(namesOf([place('무시점', null), place('영초', 0)])).toEqual(['영초', '무시점']);
  });

  it('leaves an already-sorted list alone', () => {
    expect(namesOf([place('a', 10), place('b', 20), place('c', 30)]))
      .toEqual(['a', 'b', 'c']);
  });
});
