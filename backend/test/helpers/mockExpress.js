function mockReq(overrides = {}) {
  return { body: {}, params: {}, headers: {}, ...overrides };
}

function mockRes() {
  return {
    statusCode: null,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(body) {
      this.body = body;
      return this;
    },
    send(body) {
      this.body = body;
      return this;
    },
  };
}

module.exports = { mockReq, mockRes };
