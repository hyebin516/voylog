const contentReportRepository = require('../repositories/content-report.repository');
const sharedRouteRepository = require('../repositories/shared-route.repository');
const emailService = require('./email.service');
const AppError = require('../utils/AppError');

/**
 * FR-21 공개 피드의 신고. Google Play's user-generated content policy wants
 * an in-app reporting path for content other users wrote; the feed's titles
 * are exactly that.
 *
 * Stored first and mailed second, like a support inquiry -- a mail outage
 * must not swallow a report.
 */
async function reportSharedRoute({ reporterUserId, sharedRouteId, reason, detail }) {
  const route = await sharedRouteRepository.findById(sharedRouteId);
  if (!route) {
    throw new AppError(404, 'SHARED_ROUTE_NOT_FOUND', 'Shared route not found');
  }
  if (route.user_id === reporterUserId) {
    throw new AppError(400, 'INVALID_REQUEST', 'Cannot report your own shared route');
  }

  // Reporting the same route twice is the same report, not a second one.
  // Answer success so the UI never has to explain a duplicate to the user.
  const existing = await contentReportRepository.findByReporterAndRoute(reporterUserId, sharedRouteId);
  if (existing) return existing;

  const report = await contentReportRepository.create({
    reporterUserId,
    sharedRouteId,
    reason,
    detail,
  });

  try {
    await emailService.sendContentReportEmail(report, route);
  } catch (err) {
    console.warn(`Could not forward content report ${report.report_id}: ${err.message}`);
  }

  return report;
}

module.exports = { reportSharedRoute };
