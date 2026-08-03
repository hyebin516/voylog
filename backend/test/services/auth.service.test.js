jest.mock('axios');
jest.mock('../../src/repositories/user.repository');

const axios = require('axios');
const jwt = require('jsonwebtoken');
const userRepository = require('../../src/repositories/user.repository');
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
