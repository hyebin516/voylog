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

afterEach(() => jest.clearAllMocks());

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

    await expect(authService.kakaoLogin('bad-token')).rejects.toBeInstanceOf(AppError);
    await expect(authService.kakaoLogin('bad-token')).rejects.toMatchObject({ statusCode: 503 });
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
