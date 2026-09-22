jest.mock('../../src/repositories/user.repository');

const fs = require('fs/promises');
const path = require('path');
const os = require('os');
const userRepository = require('../../src/repositories/user.repository');
const profileImageService = require('../../src/services/profile-image.service');

const { UPLOAD_DIR, PUBLIC_PREFIX } = profileImageService;

const USER = { user_id: 'u1', profile_image: null };
const JPEG = { mimetype: 'image/jpeg', buffer: Buffer.from('fake-jpeg-bytes') };

async function storedFiles() {
  try {
    return (await fs.readdir(UPLOAD_DIR)).filter((f) => f.startsWith('u1-') || f.startsWith('u2-'));
  } catch (err) {
    return [];
  }
}

afterEach(async () => {
  for (const file of await storedFiles()) {
    await fs.unlink(path.join(UPLOAD_DIR, file));
  }
  jest.clearAllMocks();
});

describe('replaceProfileImage', () => {
  it('writes the file and points the row at it', async () => {
    userRepository.updateProfileImage.mockImplementation(async (id, url) => ({ user_id: id, profile_image: url }));

    const updated = await profileImageService.replaceProfileImage(USER, JPEG);

    expect(updated.profile_image).toMatch(new RegExp(`^${PUBLIC_PREFIX}/u1-[0-9a-f]{16}\\.jpg$`));
    const written = await fs.readFile(path.join(UPLOAD_DIR, path.basename(updated.profile_image)));
    expect(written.equals(JPEG.buffer)).toBe(true);
  });

  it('gives each upload a new name, so a replaced photo is never served from cache', async () => {
    userRepository.updateProfileImage.mockImplementation(async (id, url) => ({ user_id: id, profile_image: url }));

    const first = await profileImageService.replaceProfileImage(USER, JPEG);
    const second = await profileImageService.replaceProfileImage(USER, JPEG);

    expect(second.profile_image).not.toBe(first.profile_image);
  });

  it('deletes the photo it replaced instead of leaving it on disk', async () => {
    userRepository.updateProfileImage.mockImplementation(async (id, url) => ({ user_id: id, profile_image: url }));
    const first = await profileImageService.replaceProfileImage(USER, JPEG);

    await profileImageService.replaceProfileImage(
      { user_id: 'u1', profile_image: first.profile_image },
      JPEG
    );

    await expect(fs.access(path.join(UPLOAD_DIR, path.basename(first.profile_image)))).rejects.toThrow();
  });

  it('leaves a Kakao CDN photo alone -- it is not ours to delete', async () => {
    userRepository.updateProfileImage.mockImplementation(async (id, url) => ({ user_id: id, profile_image: url }));

    await expect(
      profileImageService.replaceProfileImage({ user_id: 'u2', profile_image: 'http://k.kakaocdn.net/x.jpg' }, JPEG)
    ).resolves.toBeDefined();
  });

  it('picks the extension from the type, not from a client-supplied name', async () => {
    userRepository.updateProfileImage.mockImplementation(async (id, url) => ({ user_id: id, profile_image: url }));

    const png = await profileImageService.replaceProfileImage(USER, {
      mimetype: 'image/png',
      buffer: Buffer.from('png'),
      originalname: '../../evil.sh',
    });

    expect(png.profile_image.endsWith('.png')).toBe(true);
    expect(png.profile_image).not.toContain('evil');
  });

  it('refuses a type it has no extension for', async () => {
    await expect(
      profileImageService.replaceProfileImage(USER, { mimetype: 'image/gif', buffer: Buffer.from('gif') })
    ).rejects.toThrow('Unsupported image type');
  });
});

describe('clearProfileImage', () => {
  it('nulls the row and removes the file', async () => {
    userRepository.updateProfileImage.mockImplementation(async (id, url) => ({ user_id: id, profile_image: url }));
    const stored = await profileImageService.replaceProfileImage(USER, JPEG);

    const cleared = await profileImageService.clearProfileImage({
      user_id: 'u1',
      profile_image: stored.profile_image,
    });

    expect(userRepository.updateProfileImage).toHaveBeenLastCalledWith('u1', null);
    expect(cleared.profile_image).toBeNull();
    await expect(fs.access(path.join(UPLOAD_DIR, path.basename(stored.profile_image)))).rejects.toThrow();
  });

  it('still clears the row when the file is already gone', async () => {
    userRepository.updateProfileImage.mockResolvedValue({ user_id: 'u1', profile_image: null });

    await expect(
      profileImageService.clearProfileImage({ user_id: 'u1', profile_image: `${PUBLIC_PREFIX}/u1-missing.jpg` })
    ).resolves.toMatchObject({ profile_image: null });
  });
});

describe('toPublicUrl', () => {
  const req = { protocol: 'http', get: () => 'localhost:4000' };

  it('resolves an uploaded path against the host the client reached us on', () => {
    expect(profileImageService.toPublicUrl(`${PUBLIC_PREFIX}/u1-abc.jpg`, req)).toBe(
      `http://localhost:4000${PUBLIC_PREFIX}/u1-abc.jpg`
    );
  });

  it('passes a Kakao CDN url through untouched', () => {
    const kakao = 'https://k.kakaocdn.net/profile.jpg';
    expect(profileImageService.toPublicUrl(kakao, req)).toBe(kakao);
  });

  it('keeps null as null', () => {
    expect(profileImageService.toPublicUrl(null, req)).toBeNull();
  });
});
