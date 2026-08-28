const placeRepository = require('../repositories/place.repository');
const { callAiWorker } = require('./aiWorkerClient');
const AppError = require('../utils/AppError');

// "References multiple vlogs" only means something once at least 2 videos
// have commented on the place -- otherwise there's nothing to synthesize.
const MIN_SOURCE_VIDEOS = 2;

async function getPlaceSummary(placeId) {
  const place = await placeRepository.findById(placeId);
  if (!place) {
    throw new AppError(404, 'PLACE_NOT_FOUND', 'Place not found');
  }

  if (place.latitude == null || place.longitude == null) {
    return { available: false, pros: null, cons: null, sourceCount: 0 };
  }

  const sources = await placeRepository.findSummarySources(place.latitude, place.longitude);
  const sourceCount = sources.length;

  if (sourceCount < MIN_SOURCE_VIDEOS) {
    return { available: false, pros: null, cons: null, sourceCount };
  }

  const isCacheValid = place.summary_generated_at != null && place.summary_source_count === sourceCount;
  if (isCacheValid) {
    return { available: true, pros: place.pros_summary, cons: place.cons_summary, sourceCount };
  }

  const result = await callAiWorker(
    '/places/summarize',
    { placeName: place.name, notes: sources.map((s) => s.mentionNote), llmProvider: 'auto' },
    20000
  );

  await placeRepository.updateSummary(placeId, {
    prosSummary: result.pros,
    consSummary: result.cons,
    summarySourceCount: sourceCount,
  });

  return { available: true, pros: result.pros, cons: result.cons, sourceCount };
}

module.exports = { getPlaceSummary, MIN_SOURCE_VIDEOS };
