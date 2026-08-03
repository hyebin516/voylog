const express = require('express');
const bookmarkController = require('../controllers/bookmark.controller');
const { validateCreateBookmark, validateBookmarkId } = require('../validators/bookmark.validator');
const authenticate = require('../middlewares/auth');

const router = express.Router();

router.use(authenticate);

router.post('/', validateCreateBookmark, bookmarkController.create);
router.get('/', bookmarkController.list);
router.delete('/:id', validateBookmarkId, bookmarkController.remove);

module.exports = router;
