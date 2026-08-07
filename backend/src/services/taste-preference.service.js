const tastePreferenceRepository = require('../repositories/taste-preference.repository');
const { callAiWorker } = require('./aiWorkerClient');

function buildPreferenceText(tags) {
  return tags.join(', ');
}

async function getPreferences(userId) {
  const row = await tastePreferenceRepository.find(userId);
  return { tags: row ? row.source_tags : [] };
}

async function setPreferences(userId, tags) {
  const text = buildPreferenceText(tags);
  const result = await callAiWorker('/embeddings/generate', { text }, 15000);
  const saved = await tastePreferenceRepository.upsert(userId, {
    embedding: result.embedding,
    sourceTags: tags,
    sourceText: text,
    model: result.model,
    dimensions: result.dimensions,
  });
  return { tags: saved.source_tags };
}

async function clearPreferences(userId) {
  await tastePreferenceRepository.remove(userId);
}

module.exports = { getPreferences, setPreferences, clearPreferences };
