const axios = require('axios');
const env = require('../config/env');
const AppError = require('../utils/AppError');

// The shared secret, when the worker is configured to want one. The worker
// spends money on every call and has no user accounts of its own, so if it
// is reachable from the internet this header is the only thing between it
// and a stranger's script. Omitted when unset, which is how local dev and
// a worker kept on a private network run.
const client = axios.create({
  baseURL: env.aiWorkerUrl,
  headers: env.aiWorkerToken ? { 'X-Worker-Token': env.aiWorkerToken } : {},
});

async function callAiWorker(path, payload, timeoutMs) {
  try {
    const { data } = await client.post(path, payload, { timeout: timeoutMs });
    return data;
  } catch (err) {
    if (err.response && err.response.status === 422) {
      throw new AppError(422, 'TRANSCRIPT_NOT_FOUND', 'Transcript is not available for this video');
    }
    // AI Worker error responses are shaped { error: { code, message } } (see
    // ai_worker_error_handler) -- forward the specific code (e.g.
    // GEOCODING_FAILED) when present, instead of collapsing every failure
    // into a generic AI_PROVIDER_ERROR.
    const aiWorkerError = err.response && err.response.data && err.response.data.error;
    if (aiWorkerError && aiWorkerError.code) {
      throw new AppError(err.response.status, aiWorkerError.code, aiWorkerError.message || 'AI Worker request failed');
    }
    throw new AppError(503, 'AI_PROVIDER_ERROR', 'AI Worker request failed');
  }
}

module.exports = { callAiWorker };
