const fs = require('fs');
const path = require('path');
const MarkdownIt = require('markdown-it');

// 공개 문서(개인정보처리방침, 이용약관)를 마크다운 그대로 두고 그 자리에서
// 렌더해 서빙한다. Google Play는 공개된 개인정보처리방침 URL을 요구하고
// 심사 중에 실제로 접속해 본다.
//
// 파일이 backend/src/static/에 있는 이유는 Docker 빌드 컨텍스트가
// ./backend이기 때문이다 -- 저장소의 docs/에 둔 파일은 이미지에 들어가지
// 않는다. 사본을 두 곳에 두면 언젠가 어긋난다.
//
// markdown-it을 쓰는 이유는 marked가 ESM 전용이 되어 Jest가 require하지
// 못하기 때문이다. 테스트할 수 없는 페이지가 되어버린다.
const markdownIt = new MarkdownIt({ html: true });

const PAGE_STYLE = `
  body { font-family: -apple-system, 'Malgun Gothic', sans-serif; background: #f7fbfd; color: #1c3f52;
         margin: 0; padding: 32px 16px 64px; line-height: 1.7; }
  .container { max-width: 720px; margin: 0 auto; background: #fff; border-radius: 18px;
               padding: 32px 28px; box-shadow: 0 4px 14px rgba(58,159,216,.07); }
  h1 { font-size: 24px; margin: 0 0 8px; }
  h2 { font-size: 17px; margin: 32px 0 8px; padding-top: 8px; }
  h3 { font-size: 15px; margin: 20px 0 6px; color: #4a90bb; }
  p, li { font-size: 14.5px; }
  hr { border: none; border-top: 1px solid #e6f2f9; margin: 28px 0; }
  table { border-collapse: collapse; width: 100%; margin: 12px 0; font-size: 13.5px; }
  th, td { border: 1px solid #e6f2f9; padding: 8px 10px; text-align: left; vertical-align: top; }
  th { background: #f2f9fd; }
  code { background: #f2f9fd; padding: 1px 5px; border-radius: 4px; font-size: 13px; }
  blockquote { margin: 16px 0; padding: 12px 16px; background: #f2f9fd; border-left: 3px solid #4a90bb; }
  a { color: #158a92; }
  .nav { max-width: 720px; margin: 0 auto 14px; font-size: 13px; }
  .nav a { color: #4a90bb; text-decoration: none; margin-right: 14px; }
  @media (max-width: 480px) { .container { padding: 24px 18px; } table { font-size: 12.5px; } }
`;

const DOCS = {
  privacy: { file: 'privacy-policy.md', title: '개인정보처리방침 - Voylog' },
  terms: { file: 'terms-of-service.md', title: '이용약관 - Voylog' },
};

// 한 번만 읽는다. 파일은 이미지 안에 들어 있어 돌고 있는 컨테이너에서
// 바뀔 수 없고, 요청마다 다시 읽어봐야 디스크만 더 두드린다.
const cache = {};

function render(name) {
  if (cache[name]) return cache[name];

  const doc = DOCS[name];
  const markdown = fs.readFileSync(path.join(__dirname, '..', 'static', doc.file), 'utf8');
  cache[name] = `<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>${doc.title}</title>
<style>${PAGE_STYLE}</style>
</head>
<body>
  <div class="nav"><a href="/privacy">개인정보처리방침</a><a href="/terms">이용약관</a></div>
  <div class="container">
${markdownIt.render(markdown)}
  </div>
</body>
</html>`;
  return cache[name];
}

const privacyPolicy = (req, res) => res.type('html').send(render('privacy'));
const termsOfService = (req, res) => res.type('html').send(render('terms'));

module.exports = { privacyPolicy, termsOfService };
