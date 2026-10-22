const fs = require('fs');
const path = require('path');
const MarkdownIt = require('markdown-it');

// Google Play requires a publicly reachable privacy policy URL, and checks it
// during review. Serving it from here rather than a separate host keeps one
// copy of the text: the markdown file next to this controller is the only
// source, and `docs/` no longer holds a second one that could drift.
//
// It lives under backend/src/ because the Docker build context is ./backend
// -- a file in the repo's docs/ never reaches the image.
// markdown-it rather than marked: marked is ESM-only now and Jest cannot
// require() it, so the page would have been untestable.
const markdown_it = new MarkdownIt({ html: true });

const POLICY_PATH = path.join(__dirname, '..', 'static', 'privacy-policy.md');

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
  @media (max-width: 480px) { .container { padding: 24px 18px; } table { font-size: 12.5px; } }
`;

// Read once. The file ships inside the image, so it cannot change under a
// running container, and re-reading it per request would only add disk I/O
// to a page that review bots and users hit rarely.
let cachedHtml = null;

function render() {
  if (cachedHtml) return cachedHtml;

  const markdown = fs.readFileSync(POLICY_PATH, 'utf8');
  cachedHtml = `<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>개인정보처리방침 - Voylog</title>
<style>${PAGE_STYLE}</style>
</head>
<body>
  <div class="container">
${markdown_it.render(markdown)}
  </div>
</body>
</html>`;
  return cachedHtml;
}

function privacyPolicy(req, res) {
  res.type('html').send(render());
}

module.exports = { privacyPolicy };
