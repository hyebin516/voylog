const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const path = require('path');

const env = require('./config/env');
const apiRoutes = require('./routes');
const { generalLimiter } = require('./middlewares/rateLimit');
const errorHandler = require('./middlewares/errorHandler');

const app = express();

// Behind a reverse proxy (every managed host puts one in front) req.ip is
// the proxy's address unless this is set, which would put every user of the
// app in one rate-limit bucket and get them blocked together. Off by
// default: trusting X-Forwarded-For blindly lets a direct caller forge any
// IP, so this is only turned on where a proxy really is in front.
if (env.trustProxy) app.set('trust proxy', env.trustProxy);

app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(morgan('combined'));

// Uploaded profile photos. Served outside /api/v1 because they are plain
// files loaded by <img>/Image.network, not API responses. helmet's default
// cross-origin resource policy would block the app from loading them.
app.use(
  '/uploads',
  express.static(path.resolve(__dirname, '../uploads'), {
    setHeaders: (res) => res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin'),
  })
);

app.get('/health', (req, res) => res.json({ status: 'ok' }));

app.use('/api/v1', generalLimiter, apiRoutes);

app.use((req, res) => {
  res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Route not found' } });
});

app.use(errorHandler);

module.exports = app;
