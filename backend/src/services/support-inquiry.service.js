const supportInquiryRepository = require('../repositories/support-inquiry.repository');
const emailService = require('./email.service');

/**
 * FR-13 고객센터 문의. The screen used to show a support address and
 * nothing else; an inquiry now gets stored first and mailed second, so a
 * mail outage never loses what the user wrote.
 */
async function submitInquiry({ userId, email, category, message }) {
  const inquiry = await supportInquiryRepository.create({ userId, email, category, message });

  try {
    await emailService.sendSupportInquiryEmail(inquiry);
  } catch (err) {
    // Stored is what matters -- the team can read the table. Mail failing
    // must not tell the user their question was lost.
    console.warn(`Could not forward support inquiry ${inquiry.inquiry_id}: ${err.message}`);
  }

  return inquiry;
}

async function listInquiries(userId) {
  return supportInquiryRepository.findAllByUser(userId);
}

module.exports = { submitInquiry, listInquiries };
