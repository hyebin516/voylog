const express = require('express');
const placeController = require('../controllers/place.controller');
const { validatePlaceId, validatePlaceSearch } = require('../validators/place.validator');
const authenticate = require('../middlewares/auth');

const router = express.Router();

// 폴더에 장소를 넣기 위한 검색. 카카오 호출이 섞여 있어 로그인을 요구한다
// -- 비회원에게 열면 우리 할당량이 누구에게나 열린 것이 된다.
router.get('/search', authenticate, validatePlaceSearch, placeController.search);
router.get('/:id/summary', validatePlaceId, placeController.summary);

module.exports = router;
