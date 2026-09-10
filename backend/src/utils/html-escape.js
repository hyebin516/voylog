const ESCAPE_MAP = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };

// The trip share page (trip.controller.js's `share` action) interpolates
// user-authored strings (trip name, hotel name, place name) directly into a
// hand-written HTML template with no templating engine -- every one of them
// must go through this first or the page is a stored-XSS vector for anyone
// who opens someone else's shared link.
function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (char) => ESCAPE_MAP[char]);
}

module.exports = escapeHtml;
