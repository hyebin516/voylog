const axios = require('axios');
const env = require('../config/env');
const AppError = require('../utils/AppError');

const client = axios.create({ baseURL: env.aiWorkerUrl });

async function callAiWorker(path, payload, timeoutMs) {
  try {
    const { data } = await client.post(path, payload, { timeout: timeoutMs });
    return data;
  } catch (err) {
    if (err.response && err.response.status === 422) {
      throw new AppError(422, 'TRANSCRIPT_NOT_FOUND', 'Transcript is not available for this video');
    }
    throw new AppError(503, 'AI_PROVIDER_ERROR', 'AI Worker request failed');
  }
}

module.exports = { callAiWorker };
