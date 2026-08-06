jest.mock('nodemailer');

const nodemailer = require('nodemailer');
const emailService = require('../../src/services/email.service');

afterEach(() => jest.clearAllMocks());

describe('sendOtpEmail', () => {
  it('sends an email containing the code via the SMTP transporter', async () => {
    const sendMail = jest.fn().mockResolvedValue();
    nodemailer.createTransport.mockReturnValue({ sendMail });

    await emailService.sendOtpEmail('a@b.com', '123456');

    expect(nodemailer.createTransport).toHaveBeenCalled();
    expect(sendMail).toHaveBeenCalledWith(
      expect.objectContaining({
        to: 'a@b.com',
        text: expect.stringContaining('123456'),
      })
    );
  });
});
