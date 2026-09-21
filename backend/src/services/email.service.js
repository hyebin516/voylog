const nodemailer = require('nodemailer');
const env = require('../config/env');

let transporter = null;

function getTransporter() {
  if (!transporter) {
    transporter = nodemailer.createTransport({
      host: env.smtpHost,
      port: env.smtpPort,
      secure: env.smtpPort === 465,
      auth: { user: env.smtpUser, pass: env.smtpPassword },
    });
  }
  return transporter;
}

async function sendOtpEmail(email, code) {
  await getTransporter().sendMail({
    from: env.smtpFrom,
    to: email,
    subject: '[Voylog] 이메일 인증번호',
    text: `Voylog 회원가입 인증번호는 ${code} 입니다. 5분 이내에 입력해 주세요.`,
  });
}

/**
 * Forwards a FR-13 inquiry to the support mailbox. `replyTo` is the asker's
 * address, so answering is a plain reply -- there is no admin console.
 */
async function sendSupportInquiryEmail(inquiry) {
  await getTransporter().sendMail({
    from: env.smtpFrom,
    to: env.supportEmail,
    replyTo: inquiry.email,
    subject: `[Voylog 문의] ${inquiry.category} - ${inquiry.inquiry_id}`,
    text: [
      `분류: ${inquiry.category}`,
      `보낸 사람: ${inquiry.email}`,
      `사용자 ID: ${inquiry.user_id || '(비회원)'}`,
      '',
      inquiry.message,
    ].join('\n'),
  });
}

module.exports = { sendOtpEmail, sendSupportInquiryEmail };
