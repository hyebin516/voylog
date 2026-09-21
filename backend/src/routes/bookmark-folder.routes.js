const express = require('express');
const bookmarkFolderController = require('../controllers/bookmark-folder.controller');
const {
  validateCreateFolder,
  validateFolderId,
  validateFolderBookmarkBody,
  validateFolderBookmarkId,
} = require('../validators/bookmark-folder.validator');
const authenticate = require('../middlewares/auth');

const router = express.Router();

router.use(authenticate);

router.post('/', validateCreateFolder, bookmarkFolderController.create);
router.get('/', bookmarkFolderController.list);
router.delete('/:id', validateFolderId, bookmarkFolderController.remove);
router.get('/:id/bookmarks', validateFolderId, bookmarkFolderController.listBookmarks);
router.post('/:id/bookmarks', validateFolderId, validateFolderBookmarkBody, bookmarkFolderController.addBookmark);
router.post('/:id/route', validateFolderId, bookmarkFolderController.createRoute);
router.delete(
  '/:id/bookmarks/:bookmarkId',
  validateFolderId,
  validateFolderBookmarkId,
  bookmarkFolderController.removeBookmark
);

module.exports = router;
