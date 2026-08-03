const app = require('./app');
const env = require('./config/env');

app.listen(env.port, () => {
  console.log(`Backend server listening on port ${env.port}`);
});
