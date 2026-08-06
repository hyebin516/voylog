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

module.exports = { sendOtpEmail };
