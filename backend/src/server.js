const app = require('./app');
const env = require('./config/env');
const { assertEnv } = require('./config/required-env');
const { startPublicDataRefreshSchedule } = require('./jobs/public-data-refresh.job');
const { startTripStartAlertSchedule } = require('./jobs/trip-start-alert.job');

// Fail loudly here rather than on the first request that needed the value.
assertEnv();

app.listen(env.port, () => {
  console.log(`Backend server listening on port ${env.port}`);
  startPublicDataRefreshSchedule();
  startTripStartAlertSchedule();
});
