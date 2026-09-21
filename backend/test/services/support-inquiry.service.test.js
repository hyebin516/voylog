jest.mock('../../src/repositories/support-inquiry.repository');
jest.mock('../../src/services/email.service');

const supportInquiryRepository = require('../../src/repositories/support-inquiry.repository');
const emailService = require('../../src/services/email.service');
const { submitInquiry, listInquiries } = require('../../src/services/support-inquiry.service');

const STORED = {
  inquiry_id: 'i1',
  user_id: 'u1',
  email: 'a@b.com',
  category: 'bug',
  message: '분석이 멈춰요',
  created_at: new Date(),
};

beforeEach(() => {
  supportInquiryRepository.create.mockResolvedValue(STORED);
  emailService.sendSupportInquiryEmail.mockResolvedValue(undefined);
});

afterEach(() => jest.clearAllMocks());

describe('submitInquiry', () => {
  it('stores the inquiry and forwards it to the support mailbox', async () => {
    const result = await submitInquiry({ userId: 'u1', email: 'a@b.com', category: 'bug', message: '분석이 멈춰요' });

    expect(supportInquiryRepository.create).toHaveBeenCalledWith({
      userId: 'u1',
      email: 'a@b.com',
      category: 'bug',
      message: '분석이 멈춰요',
    });
    expect(emailService.sendSupportInquiryEmail).toHaveBeenCalledWith(STORED);
    expect(result).toBe(STORED);
  });

  it('accepts an inquiry from someone who is not logged in', async () => {
    await submitInquiry({ userId: null, email: 'a@b.com', category: 'account', message: '로그인이 안 돼요' });

    expect(supportInquiryRepository.create).toHaveBeenCalledWith(expect.objectContaining({ userId: null }));
  });

  it('still succeeds when the mail cannot be sent -- the inquiry is already stored', async () => {
    emailService.sendSupportInquiryEmail.mockRejectedValue(new Error('SMTP down'));
    jest.spyOn(console, 'warn').mockImplementation(() => {});

    await expect(
      submitInquiry({ userId: 'u1', email: 'a@b.com', category: 'bug', message: 'x' })
    ).resolves.toBe(STORED);
  });

  it('propagates a storage failure -- there would be nothing to answer', async () => {
    supportInquiryRepository.create.mockRejectedValue(new Error('db down'));

    await expect(submitInquiry({ userId: 'u1', email: 'a@b.com', category: 'bug', message: 'x' })).rejects.toThrow(
      'db down'
    );
    expect(emailService.sendSupportInquiryEmail).not.toHaveBeenCalled();
  });
});

describe('listInquiries', () => {
  it('returns only the requesting user\'s inquiries', async () => {
    supportInquiryRepository.findAllByUser.mockResolvedValue([STORED]);

    expect(await listInquiries('u1')).toEqual([STORED]);
    expect(supportInquiryRepository.findAllByUser).toHaveBeenCalledWith('u1');
  });
});
