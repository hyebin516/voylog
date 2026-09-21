const app = require('./app');
const env = require('./config/env');
const { startPublicDataRefreshSchedule } = require('./jobs/public-data-refresh.job');
const { startTripStartAlertSchedule } = require('./jobs/trip-start-alert.job');

app.listen(env.port, () => {
  console.log(`Backend server listening on port ${env.port}`);
  startPublicDataRefreshSchedule();
  startTripStartAlertSchedule();
});
