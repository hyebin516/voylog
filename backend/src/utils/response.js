function success(res, data, statusCode = 200) {
  return res.status(statusCode).json({ success: true, data });
}

function failure(res, statusCode, code, message) {
  return res.status(statusCode).json({ success: false, error: { code, message } });
}

module.exports = { success, failure };
