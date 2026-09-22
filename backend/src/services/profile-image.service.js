const crypto = require('crypto');
const fs = require('fs/promises');
const path = require('path');
const userRepository = require('../repositories/user.repository');

/**
 * Stores the profile photo a user picks from their own gallery.
 *
 * Files live on the backend's disk and are served statically, rather than in
 * the database: a photo is read on every screen that shows an avatar, and
 * pulling tens of KB through a row read on each of those is the wrong shape.
 * No object storage is configured for this project, and none is needed --
 * one small file per user.
 */

const UPLOAD_DIR = path.resolve(__dirname, '../../uploads/profile-images');
const PUBLIC_PREFIX = '/uploads/profile-images';

const EXTENSION_BY_MIME = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
};

function isStoredLocally(profileImage) {
  return typeof profileImage === 'string' && profileImage.startsWith(PUBLIC_PREFIX);
}

/** Best effort: a leftover file wastes bytes, a failed delete must not fail the request. */
async function removeStoredFile(profileImage) {
  if (!isStoredLocally(profileImage)) return;
  try {
    await fs.unlink(path.join(UPLOAD_DIR, path.basename(profileImage)));
  } catch (err) {
    if (err.code !== 'ENOENT') {
      console.warn(`Could not delete the old profile image ${profileImage}: ${err.message}`);
    }
  }
}

/**
 * @returns {Promise<object>} the updated user row.
 */
async function replaceProfileImage(user, file) {
  const extension = EXTENSION_BY_MIME[file.mimetype];
  if (!extension) throw new Error(`Unsupported image type: ${file.mimetype}`);

  await fs.mkdir(UPLOAD_DIR, { recursive: true });
  // The random suffix keeps a replaced photo from being served from a cache
  // under its old URL, and makes the path unguessable from a user id alone.
  const filename = `${user.user_id}-${crypto.randomBytes(8).toString('hex')}${extension}`;
  await fs.writeFile(path.join(UPLOAD_DIR, filename), file.buffer);

  const updated = await userRepository.updateProfileImage(user.user_id, `${PUBLIC_PREFIX}/${filename}`);
  // Only after the row points at the new file, so a crash in between leaves
  // an orphan rather than a user whose avatar 404s.
  await removeStoredFile(user.profile_image);
  return updated;
}

async function clearProfileImage(user) {
  const updated = await userRepository.updateProfileImage(user.user_id, null);
  await removeStoredFile(user.profile_image);
  return updated;
}

/**
 * Turns a stored path into something the app can load. A Kakao photo is
 * already an absolute CDN URL and is returned untouched; an uploaded one is
 * relative, so it is resolved against the host the client used to get here
 * (localhost through `adb reverse` on a device, a real host in deployment).
 */
function toPublicUrl(profileImage, req) {
  if (!profileImage) return null;
  if (/^https?:\/\//i.test(profileImage)) return profileImage;
  return `${req.protocol}://${req.get('host')}${profileImage}`;
}

module.exports = {
  replaceProfileImage,
  clearProfileImage,
  toPublicUrl,
  UPLOAD_DIR,
  PUBLIC_PREFIX,
  EXTENSION_BY_MIME,
};
