const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const path = require('path');

const env = require('./config/env');
const apiRoutes = require('./routes');
const { generalLimiter } = require('./middlewares/rateLimit');
const staticDocController = require('./controllers/static-doc.controller');
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

// Outside /api/v1 and outside the rate limiter: these are pages for people
// and for Google Play's review, not API calls, and they have to answer every
// time. 앱의 설정·회원가입 화면도 이 주소를 연다.
app.get('/privacy', staticDocController.privacyPolicy);
app.get('/terms', staticDocController.termsOfService);
app.get('/account-deletion', staticDocController.accountDeletion);

// 전시·발표에서 QR로 앱을 받게 하는 짧은 주소. /uploads/voylog.apk를 그대로
// QR에 넣으면 45자라 41x41 모듈이 되는데, 이 주소는 25x25로 떨어진다 --
// 같은 크기로 인쇄해도 칸이 1.6배 커져서 멀리서·비스듬히 찍어도 잡힌다.
// 302(임시)인 이유는 파일 경로가 바뀌어도 QR은 그대로 쓰기 위해서다.
app.get('/get', (req, res) => res.redirect(302, '/uploads/voylog.apk'));

// 전시에서 아이폰 관람객에게 보여줄 예시 동선. 설치가 불가능한 기기에서도
// 앱이 실제로 짠 일정을 브라우저로 확인할 수 있어야 한다. 가리키는 곳은
// 심사용 계정(voylog.help+review)의 "제주 1박 2일" 여행이고, FR-20의 공개
// 조회 페이지라 로그인 없이 열린다 -- 그 여행을 지우면 이 주소도 깨진다.
const DEMO_TRIP_ID = '90981936-2a37-4c19-9c97-5447e1a7c79b';
app.get('/demo', (req, res) => res.redirect(302, `/api/v1/trips/${DEMO_TRIP_ID}/share`));

app.use('/api/v1', generalLimiter, apiRoutes);

app.use((req, res) => {
  res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Route not found' } });
});

app.use(errorHandler);

module.exports = app;
