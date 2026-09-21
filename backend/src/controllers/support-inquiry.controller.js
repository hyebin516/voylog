const supportInquiryService = require('../services/support-inquiry.service');
const { success } = require('../utils/response');

function toResponse(inquiry) {
  return {
    inquiryId: inquiry.inquiry_id,
    email: inquiry.email,
    category: inquiry.category,
    message: inquiry.message,
    createdAt: inquiry.created_at,
  };
}

async function submit(req, res, next) {
  try {
    const { email, category, message } = req.body;
    const inquiry = await supportInquiryService.submitInquiry({
      // Optional auth: someone who cannot log in still needs to ask.
      userId: req.user ? req.user.userId : null,
      email,
      category,
      message,
    });
    return success(res, toResponse(inquiry), 201);
  } catch (err) {
    return next(err);
  }
}

async function list(req, res, next) {
  try {
    const inquiries = await supportInquiryService.listInquiries(req.user.userId);
    return success(res, { inquiries: inquiries.map(toResponse) });
  } catch (err) {
    return next(err);
  }
}

module.exports = { submit, list };
