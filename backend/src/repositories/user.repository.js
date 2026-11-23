const pool = require('../config/db');

async function findByProviderId(providerId) {
  const { rows } = await pool.query(
    'SELECT * FROM users WHERE provider_id = $1 AND deleted_at IS NULL',
    [providerId]
  );
  return rows[0] || null;
}

async function findById(userId) {
  const { rows } = await pool.query('SELECT * FROM users WHERE user_id = $1 AND deleted_at IS NULL', [userId]);
  return rows[0] || null;
}

async function create(user) {
  const { rows } = await pool.query(
    `INSERT INTO users (provider, provider_id, email, nickname, profile_image)
     VALUES ('kakao', $1, $2, $3, $4)
     RETURNING *`,
    [user.providerId, user.email, user.nickname, user.profileImage]
  );
  return rows[0];
}

/**
 * Refreshes what Kakao owns on a returning user's row -- never the nickname,
 * which the user can rename in this app.
 */
async function updateKakaoProfile(userId, { email, profileImage }) {
  const { rows } = await pool.query(
    `UPDATE users SET email = $1, profile_image = $2, updated_at = now()
     WHERE user_id = $3 AND deleted_at IS NULL
     RETURNING *`,
    [email, profileImage, userId]
  );
  return rows[0];
}

/**
 * 회원 탈퇴. 행 자체는 남긴다 -- 북마크·여행·동선이 `user_id`를 참조하고
 * 있어서 지우면 그쪽이 깨진다. 대신 **사람을 가리키는 값은 전부 덮는다.**
 *
 * `deleted_at`만 찍던 시절에는 탈퇴한 뒤에도 이메일·닉네임·카카오 회원번호가
 * 그대로 남아 있었다. 로그인은 막히니 기능상 문제는 없었지만, "탈퇴하면
 * 개인정보는 어떻게 되나"에 "남아 있습니다"라고 답해야 했다.
 *
 * `nickname`과 `provider_id`는 NOT NULL이라 비울 수 없어 식별 불가능한 값으로
 * 덮는다. 둘 다 유니크 제약은 `deleted_at IS NULL` 범위의 부분 인덱스라(027),
 * 같은 카카오 계정·이메일로 다시 가입하는 데는 영향이 없다.
 */
async function softDeleteAndAnonymize(userId) {
  await pool.query(
    `UPDATE users
        SET deleted_at = now(),
            updated_at = now(),
            email = NULL,
            password_hash = NULL,
            profile_image = NULL,
            nickname = '탈퇴한 사용자',
            provider_id = 'deleted:' || user_id
      WHERE user_id = $1 AND deleted_at IS NULL`,
    [userId]
  );
}

async function updateNickname(userId, nickname) {
  const { rows } = await pool.query(
    'UPDATE users SET nickname = $1, updated_at = now() WHERE user_id = $2 AND deleted_at IS NULL RETURNING *',
    [nickname, userId]
  );
  return rows[0];
}

async function updateProfileImage(userId, profileImage) {
  const { rows } = await pool.query(
    'UPDATE users SET profile_image = $1, updated_at = now() WHERE user_id = $2 AND deleted_at IS NULL RETURNING *',
    [profileImage, userId]
  );
  return rows[0];
}

async function findByEmail(email) {
  const { rows } = await pool.query('SELECT * FROM users WHERE email = $1 AND deleted_at IS NULL', [email]);
  return rows[0] || null;
}

async function findByNickname(nickname) {
  const { rows } = await pool.query('SELECT * FROM users WHERE nickname = $1 AND deleted_at IS NULL', [nickname]);
  return rows[0] || null;
}

async function updatePasswordHash(userId, passwordHash) {
  const { rows } = await pool.query(
    'UPDATE users SET password_hash = $1, updated_at = now() WHERE user_id = $2 AND deleted_at IS NULL RETURNING *',
    [passwordHash, userId]
  );
  return rows[0];
}

async function createEmailUser({ email, passwordHash, nickname }) {
  const { rows } = await pool.query(
    `INSERT INTO users (provider, provider_id, email, nickname, password_hash)
     VALUES ('email', $1, $1, $2, $3)
     RETURNING *`,
    [email, nickname, passwordHash]
  );
  return rows[0];
}

module.exports = {
  findByProviderId,
  updateKakaoProfile,
  findById,
  create,
  softDeleteAndAnonymize,
  findByEmail,
  findByNickname,
  createEmailUser,
  updateNickname,
  updateProfileImage,
  updatePasswordHash,
};
