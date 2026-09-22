const multer = require('multer');
const AppError = require('../utils/AppError');
const { EXTENSION_BY_MIME } = require('../services/profile-image.service');

/**
 * Accepts one profile photo in the `image` field. Held in memory, not on
 * disk: the app already downscales before uploading, so these are tens of
 * KB, and the service decides the final filename.
 */

// The app uploads a 512px JPEG (~50KB). This is the ceiling for a photo
// that skipped that step, not the expected size.
const MAX_BYTES = 5 * 1024 * 1024;

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_BYTES, files: 1 },
  fileFilter: (req, file, cb) => {
    if (!EXTENSION_BY_MIME[file.mimetype]) {
      cb(new AppError(400, 'INVALID_REQUEST', `Unsupported image type: ${file.mimetype}`));
      return;
    }
    cb(null, true);
  },
});

function uploadProfileImage(req, res, next) {
  upload.single('image')(req, res, (err) => {
    if (err instanceof multer.MulterError) {
      const message =
        err.code === 'LIMIT_FILE_SIZE'
          ? `Image must be at most ${MAX_BYTES / 1024 / 1024}MB`
          : `Upload failed: ${err.code}`;
      return next(new AppError(400, 'INVALID_REQUEST', message));
    }
    if (err) return next(err);
    if (!req.file) return next(new AppError(400, 'INVALID_REQUEST', 'An image file is required'));
    return next();
  });
}

module.exports = { uploadProfileImage, MAX_BYTES };
