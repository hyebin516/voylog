const AppError = require('../utils/AppError');
const { failure } = require('../utils/response');

function errorHandler(err, req, res, next) {
  if (err instanceof AppError) {
    return failure(res, err.statusCode, err.code, err.message);
  }

  console.error(err);
  return failure(res, 500, 'INTERNAL_ERROR', 'An unexpected error occurred');
}

module.exports = errorHandler;
