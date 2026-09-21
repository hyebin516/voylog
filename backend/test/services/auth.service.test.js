jest.mock('axios');
jest.mock('../../src/repositories/user.repository');
jest.mock('../../src/repositories/email-otp.repository');
jest.mock('../../src/services/email.service');

const axios = require('axios');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const userRepository = require('../../src/repositories/user.repository');
const emailOtpRepository = require('../../src/repositories/email-otp.repository');
const emailService = require('../../src/services/email.service');
const authService = require('../../src/services/auth.service');
const AppError = require('../../src/utils/AppError');

afterEach(() => jest.resetAllMocks());

describe('kakaoLogin', () => {
  const kakaoProfileResponse = {
    data: {
      id: 123456,
      kakao_account: { email: 'a@b.com', profile: { nickname: 'Nagyeong', profile_image_url: 'http://img' } },
    },
  };

  it('logs in an existing user without creating a duplicate', async () => {
    axios.get.mockResolvedValue(kakaoProfileResponse);
    userRepository.findByProviderId.mockResolvedValue({ user_id: 'u1', email: 'a@b.com' });

    const { token, user } = await authService.kakaoLogin('kakao-token');

    expect(userRepository.findByProviderId).toHaveBeenCalledWith('123456');
    expect(userRepository.create).not.toHaveBeenCalled();
    expect(user.user_id).toBe('u1');
    expect(jwt.verify(token, process.env.JWT_SECRET)).toMatchObject({ userId: 'u1' });
  });

  it('fills in an email a returning user signed up without', async () => {
    // The Kakao app's 동의항목 for email can be added after someone already
    // signed up, so their row was created with email null.
    axios.get.mockResolvedValue(kakaoProfileResponse);
    userRepository.findByProviderId.mockResolvedValue({
      user_id: 'u1',
      email: null,
      nickname: '내가정한이름',
      profile_image: null,
    });
    userRepository.updateKakaoProfile.mockResolvedValue({ user_id: 'u1', email: 'a@b.com', nickname: '내가정한이름' });

    const { user } = await authService.kakaoLogin('kakao-token');

    expect(userRepository.updateKakaoProfile).toHaveBeenCalledWith('u1', {
      email: 'a@b.com',
      profileImage: 'http://img',
    });
    // The nickname is this app's once the account exists -- a rename here
    // must survive every later Kakao login.
    expect(user.nickname).toBe('내가정한이름');
  });

  it('leaves a returning user alone when Kakao has nothing new', async () => {
    axios.get.mockResolvedValue(kakaoProfileResponse);
    userRepository.findByProviderId.mockResolvedValue({
      user_id: 'u1',
      email: 'a@b.com',
      profile_image: 'http://img',
    });

    await authService.kakaoLogin('kakao-token');

    expect(userRepository.updateKakaoProfile).not.toHaveBeenCalled();
  });

  it('still logs the user in when the profile sync fails', async () => {
    axios.get.mockResolvedValue(kakaoProfileResponse);
    userRepository.findByProviderId.mockResolvedValue({ user_id: 'u1', email: null, profile_image: null });
    userRepository.updateKakaoProfile.mockRejectedValue(new Error('duplicate key value violates uq_users_email'));
    const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});

    const { token, user } = await authService.kakaoLogin('kakao-token');

    expect(user.user_id).toBe('u1');
    expect(jwt.verify(token, process.env.JWT_SECRET)).toMatchObject({ userId: 'u1' });
    warn.mockRestore();
  });

  it('creates a new user on first login and issues a JWT for them', async () => {
    axios.get.mockResolvedValue(kakaoProfileResponse);
    userRepository.findByProviderId.mockResolvedValue(null);
    userRepository.create.mockResolvedValue({ user_id: 'new-user' });

    const { token, user } = await authService.kakaoLogin('kakao-token');

    expect(userRepository.create).toHaveBeenCalledWith({
      providerId: '123456',
      email: 'a@b.com',
      nickname: 'Nagyeong',
      profileImage: 'http://img',
    });
    expect(user.user_id).toBe('new-user');
    expect(jwt.verify(token, process.env.JWT_SECRET)).toMatchObject({ userId: 'new-user' });
  });

  it('defaults nickname/email/profileImage when Kakao omits optional account fields', async () => {
    axios.get.mockResolvedValue({ data: { id: 999, kakao_account: {} } });
    userRepository.findByProviderId.mockResolvedValue(null);
    userRepository.create.mockResolvedValue({ user_id: 'u2' });

    await authService.kakaoLogin('kakao-token');

    expect(userRepository.create).toHaveBeenCalledWith({
      providerId: '999',
      email: null,
      nickname: 'Kakao User',
      profileImage: null,
    });
  });

  it('wraps a failed Kakao token verification in a 503 AppError', async () => {
    axios.get.mockRejectedValue(new Error('401 from kakao'));
    const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});

    await expect(authService.kakaoLogin('bad-token')).rejects.toBeInstanceOf(AppError);
    await expect(authService.kakaoLogin('bad-token')).rejects.toMatchObject({ statusCode: 503 });

    warn.mockRestore();
  });

  it("logs Kakao's own error code for a rejected token, never the token itself", async () => {
    axios.get.mockRejectedValue({
      response: { status: 401, data: { code: -401, msg: 'this access token does not exist' } },
    });
    const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});

    await expect(authService.kakaoLogin('bad-token')).rejects.toBeInstanceOf(AppError);

    const logged = warn.mock.calls[0][0];
    expect(logged).toContain('status=401');
    expect(logged).toContain('code=-401');
    expect(logged).not.toContain('bad-token');
    warn.mockRestore();
  });

  it('appends a numeric suffix when the Kakao nickname is already taken', async () => {
    axios.get.mockResolvedValue(kakaoProfileResponse);
    userRepository.findByProviderId.mockResolvedValue(null);
    userRepository.findByNickname
      .mockResolvedValueOnce({ user_id: 'someone-else' }) // 'Nagyeong' taken
      .mockResolvedValueOnce({ user_id: 'someone-else' }) // 'Nagyeong2' taken
      .mockResolvedValueOnce(null); // 'Nagyeong3' free
    userRepository.create.mockResolvedValue({ user_id: 'new-user', nickname: 'Nagyeong3' });

    await authService.kakaoLogin('kakao-token');

    expect(userRepository.create).toHaveBeenCalledWith(
      expect.objectContaining({ nickname: 'Nagyeong3' })
    );
  });
});

describe('getProfile', () => {
  it('returns the user when found', async () => {
    userRepository.findById.mockResolvedValue({ user_id: 'u1' });
    const user = await authService.getProfile('u1');
    expect(user.user_id).toBe('u1');
  });

  it('throws 404 USER_NOT_FOUND when the user does not exist', async () => {
    userRepository.findById.mockResolvedValue(null);
    await expect(authService.getProfile('missing')).rejects.toMatchObject({
      statusCode: 404,
      code: 'USER_NOT_FOUND',
    });
  });
});

describe('deleteAccount', () => {
  it('soft-deletes the user by id', async () => {
    userRepository.softDelete.mockResolvedValue();

    await authService.deleteAccount('u1');

    expect(userRepository.softDelete).toHaveBeenCalledWith('u1');
  });
});

describe('updateNickname', () => {
  it('updates the nickname of an existing user', async () => {
    userRepository.findById.mockResolvedValue({ user_id: 'u1', nickname: 'old' });
    userRepository.updateNickname.mockResolvedValue({ user_id: 'u1', nickname: 'new' });

    const user = await authService.updateNickname('u1', 'new');

    expect(userRepository.updateNickname).toHaveBeenCalledWith('u1', 'new');
    expect(user.nickname).toBe('new');
  });

  it('throws 404 USER_NOT_FOUND when the user does not exist', async () => {
    userRepository.findById.mockResolvedValue(null);

    await expect(authService.updateNickname('missing', 'new')).rejects.toMatchObject({
      statusCode: 404,
      code: 'USER_NOT_FOUND',
    });
    expect(userRepository.updateNickname).not.toHaveBeenCalled();
  });

  it('throws 409 NICKNAME_EXISTS when another user already has that nickname', async () => {
    userRepository.findById.mockResolvedValue({ user_id: 'u1', nickname: 'old' });
    userRepository.findByNickname.mockResolvedValue({ user_id: 'u2', nickname: 'new' });

    await expect(authService.updateNickname('u1', 'new')).rejects.toMatchObject({
      statusCode: 409,
      code: 'NICKNAME_EXISTS',
    });
    expect(userRepository.updateNickname).not.toHaveBeenCalled();
  });

  it('does not check availability when the nickname is unchanged', async () => {
    userRepository.findById.mockResolvedValue({ user_id: 'u1', nickname: 'same' });
    userRepository.updateNickname.mockResolvedValue({ user_id: 'u1', nickname: 'same' });

    await authService.updateNickname('u1', 'same');

    expect(userRepository.findByNickname).not.toHaveBeenCalled();
    expect(userRepository.updateNickname).toHaveBeenCalledWith('u1', 'same');
  });
});

describe('checkNicknameAvailability', () => {
  it('returns available: true when no user has the nickname', async () => {
    userRepository.findByNickname.mockResolvedValue(null);

    await expect(authService.checkNicknameAvailability('새닉네임')).resolves.toEqual({ available: true });
  });

  it('returns available: false when the nickname is taken', async () => {
    userRepository.findByNickname.mockResolvedValue({ user_id: 'u1' });

    await expect(authService.checkNicknameAvailability('taken')).resolves.toEqual({ available: false });
  });
});

describe('requestSignupOtp', () => {
  it('throws 409 EMAIL_EXISTS when the email is already registered', async () => {
    userRepository.findByEmail.mockResolvedValue({ user_id: 'u1' });

    await expect(authService.requestSignupOtp('a@b.com')).rejects.toMatchObject({
      statusCode: 409,
      code: 'EMAIL_EXISTS',
    });
    expect(emailOtpRepository.create).not.toHaveBeenCalled();
  });

  it('creates an OTP row and emails the 6-digit code', async () => {
    userRepository.findByEmail.mockResolvedValue(null);

    await authService.requestSignupOtp('a@b.com');

    expect(emailOtpRepository.create).toHaveBeenCalledWith('a@b.com', expect.any(String));
    expect(emailService.sendOtpEmail).toHaveBeenCalledWith('a@b.com', expect.stringMatching(/^\d{6}$/));
  });
});

describe('verifySignupOtp', () => {
  it('marks the OTP verified when the code matches', async () => {
    const codeHash = crypto.createHash('sha256').update('123456').digest('hex');
    emailOtpRepository.findLatestUnverifiedByEmail.mockResolvedValue({
      otp_id: 'otp1',
      code_hash: codeHash,
      expires_at: new Date(Date.now() + 60_000),
      attempts: 0,
    });

    await authService.verifySignupOtp('a@b.com', '123456');

    expect(emailOtpRepository.markVerified).toHaveBeenCalledWith('otp1');
  });

  it('throws 400 OTP_EXPIRED when there is no pending code', async () => {
    emailOtpRepository.findLatestUnverifiedByEmail.mockResolvedValue(null);

    await expect(authService.verifySignupOtp('a@b.com', '123456')).rejects.toMatchObject({
      statusCode: 400,
      code: 'OTP_EXPIRED',
    });
  });

  it('throws 400 OTP_EXPIRED when the code has expired', async () => {
    emailOtpRepository.findLatestUnverifiedByEmail.mockResolvedValue({
      otp_id: 'otp1',
      code_hash: 'x',
      expires_at: new Date(Date.now() - 1000),
      attempts: 0,
    });

    await expect(authService.verifySignupOtp('a@b.com', '123456')).rejects.toMatchObject({ code: 'OTP_EXPIRED' });
  });

  it('throws 400 OTP_INVALID and increments attempts when the code is wrong', async () => {
    emailOtpRepository.findLatestUnverifiedByEmail.mockResolvedValue({
      otp_id: 'otp1',
      code_hash: 'not-matching',
      expires_at: new Date(Date.now() + 60_000),
      attempts: 1,
    });

    await expect(authService.verifySignupOtp('a@b.com', '000000')).rejects.toMatchObject({ code: 'OTP_INVALID' });
    expect(emailOtpRepository.incrementAttempts).toHaveBeenCalledWith('otp1');
  });

  it('throws 400 OTP_EXPIRED once the attempt limit is reached', async () => {
    emailOtpRepository.MAX_ATTEMPTS = 5;
    emailOtpRepository.findLatestUnverifiedByEmail.mockResolvedValue({
      otp_id: 'otp1',
      code_hash: 'x',
      expires_at: new Date(Date.now() + 60_000),
      attempts: 5,
    });

    await expect(authService.verifySignupOtp('a@b.com', '123456')).rejects.toMatchObject({ code: 'OTP_EXPIRED' });
  });
});

describe('signup', () => {
  it('throws 409 EMAIL_EXISTS when the email is already registered', async () => {
    userRepository.findByEmail.mockResolvedValue({ user_id: 'u1' });

    await expect(authService.signup('a@b.com', 'password123', 'Nagyeong')).rejects.toMatchObject({
      statusCode: 409,
      code: 'EMAIL_EXISTS',
    });
  });

  it('throws 409 NICKNAME_EXISTS when the nickname is already taken', async () => {
    userRepository.findByEmail.mockResolvedValue(null);
    userRepository.findByNickname.mockResolvedValue({ user_id: 'u2' });

    await expect(authService.signup('a@b.com', 'password123', 'Nagyeong')).rejects.toMatchObject({
      statusCode: 409,
      code: 'NICKNAME_EXISTS',
    });
    expect(userRepository.createEmailUser).not.toHaveBeenCalled();
  });

  it('throws 400 OTP_NOT_VERIFIED when the email was never verified', async () => {
    userRepository.findByEmail.mockResolvedValue(null);
    emailOtpRepository.findLatestVerifiedByEmail.mockResolvedValue(null);

    await expect(authService.signup('a@b.com', 'password123', 'Nagyeong')).rejects.toMatchObject({
      statusCode: 400,
      code: 'OTP_NOT_VERIFIED',
    });
  });

  it('creates the user, consumes the OTP, and issues a JWT', async () => {
    userRepository.findByEmail.mockResolvedValue(null);
    emailOtpRepository.findLatestVerifiedByEmail.mockResolvedValue({ otp_id: 'otp1' });
    userRepository.createEmailUser.mockResolvedValue({ user_id: 'new-user', email: 'a@b.com' });

    const { token, user } = await authService.signup('a@b.com', 'password123', 'Nagyeong');

    expect(userRepository.createEmailUser).toHaveBeenCalledWith({
      email: 'a@b.com',
      passwordHash: expect.any(String),
      nickname: 'Nagyeong',
    });
    expect(emailOtpRepository.deleteByEmail).toHaveBeenCalledWith('a@b.com');
    expect(user.user_id).toBe('new-user');
    expect(jwt.verify(token, process.env.JWT_SECRET)).toMatchObject({ userId: 'new-user' });
  });
});

describe('login', () => {
  it('logs in with a matching password and issues a JWT', async () => {
    const passwordHash = await bcrypt.hash('password123', 10);
    userRepository.findByEmail.mockResolvedValue({ user_id: 'u1', password_hash: passwordHash });

    const { token, user } = await authService.login('a@b.com', 'password123');

    expect(user.user_id).toBe('u1');
    expect(jwt.verify(token, process.env.JWT_SECRET)).toMatchObject({ userId: 'u1' });
  });

  it('throws 401 INVALID_CREDENTIALS when no account exists for the email', async () => {
    userRepository.findByEmail.mockResolvedValue(null);

    await expect(authService.login('a@b.com', 'password123')).rejects.toMatchObject({
      statusCode: 401,
      code: 'INVALID_CREDENTIALS',
    });
  });

  it('throws 401 INVALID_CREDENTIALS when the password does not match', async () => {
    const passwordHash = await bcrypt.hash('correct-password', 10);
    userRepository.findByEmail.mockResolvedValue({ user_id: 'u1', password_hash: passwordHash });

    await expect(authService.login('a@b.com', 'wrong-password')).rejects.toMatchObject({
      statusCode: 401,
      code: 'INVALID_CREDENTIALS',
    });
  });

  it('throws 401 INVALID_CREDENTIALS for a Kakao-only account with no password set', async () => {
    userRepository.findByEmail.mockResolvedValue({ user_id: 'u1', password_hash: null });

    await expect(authService.login('a@b.com', 'anything')).rejects.toMatchObject({
      statusCode: 401,
      code: 'INVALID_CREDENTIALS',
    });
  });
});

describe('changePassword', () => {
  it('updates the password when the current password matches', async () => {
    const passwordHash = await bcrypt.hash('old-password', 10);
    userRepository.findById.mockResolvedValue({ user_id: 'u1', password_hash: passwordHash });
    userRepository.updatePasswordHash.mockResolvedValue({ user_id: 'u1' });

    await authService.changePassword('u1', 'old-password', 'new-password123');

    expect(userRepository.updatePasswordHash).toHaveBeenCalledWith('u1', expect.any(String));
    const newHash = userRepository.updatePasswordHash.mock.calls[0][1];
    expect(await bcrypt.compare('new-password123', newHash)).toBe(true);
  });

  it('throws 404 USER_NOT_FOUND when the user does not exist', async () => {
    userRepository.findById.mockResolvedValue(null);

    await expect(authService.changePassword('u1', 'old-password', 'new-password123')).rejects.toMatchObject({
      statusCode: 404,
      code: 'USER_NOT_FOUND',
    });
    expect(userRepository.updatePasswordHash).not.toHaveBeenCalled();
  });

  it('throws 400 NO_PASSWORD_SET for a Kakao-only account', async () => {
    userRepository.findById.mockResolvedValue({ user_id: 'u1', password_hash: null });

    await expect(authService.changePassword('u1', 'old-password', 'new-password123')).rejects.toMatchObject({
      statusCode: 400,
      code: 'NO_PASSWORD_SET',
    });
    expect(userRepository.updatePasswordHash).not.toHaveBeenCalled();
  });

  it('throws 401 INVALID_CREDENTIALS when the current password does not match', async () => {
    const passwordHash = await bcrypt.hash('old-password', 10);
    userRepository.findById.mockResolvedValue({ user_id: 'u1', password_hash: passwordHash });

    await expect(authService.changePassword('u1', 'wrong-password', 'new-password123')).rejects.toMatchObject({
      statusCode: 401,
      code: 'INVALID_CREDENTIALS',
    });
    expect(userRepository.updatePasswordHash).not.toHaveBeenCalled();
  });
});

describe('requestPasswordResetOtp', () => {
  it('throws 404 EMAIL_NOT_FOUND when no account exists for the email', async () => {
    userRepository.findByEmail.mockResolvedValue(null);

    await expect(authService.requestPasswordResetOtp('a@b.com')).rejects.toMatchObject({
      statusCode: 404,
      code: 'EMAIL_NOT_FOUND',
    });
    expect(emailOtpRepository.create).not.toHaveBeenCalled();
  });

  it('throws 400 NO_PASSWORD_SET for a Kakao-only account', async () => {
    userRepository.findByEmail.mockResolvedValue({ user_id: 'u1', password_hash: null });

    await expect(authService.requestPasswordResetOtp('a@b.com')).rejects.toMatchObject({
      statusCode: 400,
      code: 'NO_PASSWORD_SET',
    });
    expect(emailOtpRepository.create).not.toHaveBeenCalled();
  });

  it('creates an OTP row and emails the 6-digit code', async () => {
    userRepository.findByEmail.mockResolvedValue({ user_id: 'u1', password_hash: 'hash' });

    await authService.requestPasswordResetOtp('a@b.com');

    expect(emailOtpRepository.create).toHaveBeenCalledWith('a@b.com', expect.any(String));
    expect(emailService.sendOtpEmail).toHaveBeenCalledWith('a@b.com', expect.stringMatching(/^\d{6}$/));
  });
});

describe('verifyPasswordResetOtp', () => {
  it('marks the OTP verified when the code matches', async () => {
    const codeHash = crypto.createHash('sha256').update('123456').digest('hex');
    emailOtpRepository.findLatestUnverifiedByEmail.mockResolvedValue({
      otp_id: 'otp1',
      code_hash: codeHash,
      expires_at: new Date(Date.now() + 60_000),
      attempts: 0,
    });

    await authService.verifyPasswordResetOtp('a@b.com', '123456');

    expect(emailOtpRepository.markVerified).toHaveBeenCalledWith('otp1');
  });

  it('throws 400 OTP_INVALID when the code is wrong', async () => {
    emailOtpRepository.findLatestUnverifiedByEmail.mockResolvedValue({
      otp_id: 'otp1',
      code_hash: 'not-matching',
      expires_at: new Date(Date.now() + 60_000),
      attempts: 0,
    });

    await expect(authService.verifyPasswordResetOtp('a@b.com', '000000')).rejects.toMatchObject({
      code: 'OTP_INVALID',
    });
  });
});

describe('resetPassword', () => {
  it('throws 404 EMAIL_NOT_FOUND when no account exists for the email', async () => {
    userRepository.findByEmail.mockResolvedValue(null);

    await expect(authService.resetPassword('a@b.com', 'new-password123')).rejects.toMatchObject({
      statusCode: 404,
      code: 'EMAIL_NOT_FOUND',
    });
  });

  it('throws 404 EMAIL_NOT_FOUND for a Kakao-only account', async () => {
    userRepository.findByEmail.mockResolvedValue({ user_id: 'u1', password_hash: null });

    await expect(authService.resetPassword('a@b.com', 'new-password123')).rejects.toMatchObject({
      statusCode: 404,
      code: 'EMAIL_NOT_FOUND',
    });
  });

  it('throws 400 OTP_NOT_VERIFIED when the email was never verified', async () => {
    userRepository.findByEmail.mockResolvedValue({ user_id: 'u1', password_hash: 'hash' });
    emailOtpRepository.findLatestVerifiedByEmail.mockResolvedValue(null);

    await expect(authService.resetPassword('a@b.com', 'new-password123')).rejects.toMatchObject({
      statusCode: 400,
      code: 'OTP_NOT_VERIFIED',
    });
    expect(userRepository.updatePasswordHash).not.toHaveBeenCalled();
  });

  it('updates the password and consumes the OTP', async () => {
    userRepository.findByEmail.mockResolvedValue({ user_id: 'u1', password_hash: 'old-hash' });
    emailOtpRepository.findLatestVerifiedByEmail.mockResolvedValue({ otp_id: 'otp1' });
    userRepository.updatePasswordHash.mockResolvedValue({ user_id: 'u1' });

    await authService.resetPassword('a@b.com', 'new-password123');

    expect(userRepository.updatePasswordHash).toHaveBeenCalledWith('u1', expect.any(String));
    const newHash = userRepository.updatePasswordHash.mock.calls[0][1];
    expect(await bcrypt.compare('new-password123', newHash)).toBe(true);
    expect(emailOtpRepository.deleteByEmail).toHaveBeenCalledWith('a@b.com');
  });
});
