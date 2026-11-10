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

/**
 * Forwards a FR-21 feed report to the support mailbox. There is no admin
 * console, so this mail is how a report is actually seen. No `replyTo`: the
 * reporter's address is not collected (a Kakao account may not have one).
 */
async function sendContentReportEmail(report, route) {
  await getTransporter().sendMail({
    from: env.smtpFrom,
    to: env.supportEmail,
    subject: `[Voylog 신고] ${report.reason} - ${report.report_id}`,
    text: [
      `사유: ${report.reason}`,
      `신고한 사용자 ID: ${report.reporter_user_id}`,
      `신고된 동선 ID: ${report.shared_route_id}`,
      `동선 제목: ${route.title}`,
      `게시자 ID: ${route.user_id}`,
      '',
      report.detail || '(추가 설명 없음)',
    ].join('\n'),
  });
}

module.exports = { sendOtpEmail, sendSupportInquiryEmail, sendContentReportEmail };
