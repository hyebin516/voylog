const express = require('express');
const savedWalkingCourseController = require('../controllers/saved-walking-course.controller');
const { validateCreateSavedCourse, validateSavedCourseId } = require('../validators/saved-walking-course.validator');
const authenticate = require('../middlewares/auth');

const router = express.Router();

router.use(authenticate);

router.post('/', validateCreateSavedCourse, savedWalkingCourseController.create);
router.get('/', savedWalkingCourseController.list);
router.delete('/:id', validateSavedCourseId, savedWalkingCourseController.remove);

module.exports = router;
