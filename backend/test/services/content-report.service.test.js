jest.mock('../../src/repositories/content-report.repository');
jest.mock('../../src/repositories/shared-route.repository');
jest.mock('../../src/services/email.service');

const contentReportRepository = require('../../src/repositories/content-report.repository');
const sharedRouteRepository = require('../../src/repositories/shared-route.repository');
const emailService = require('../../src/services/email.service');
const contentReportService = require('../../src/services/content-report.service');

const REPORTER_ID = 'reporter-1';
const AUTHOR_ID = 'author-1';
const ROUTE_ID = 'route-1';

const route = { shared_route_id: ROUTE_ID, user_id: AUTHOR_ID, title: '제주 서쪽 코스' };

beforeEach(() => {
  sharedRouteRepository.findById.mockResolvedValue(route);
  contentReportRepository.findByReporterAndRoute.mockResolvedValue(null);
  contentReportRepository.create.mockImplementation(async (args) => ({
    report_id: 'report-1',
    reporter_user_id: args.reporterUserId,
    shared_route_id: args.sharedRouteId,
    reason: args.reason,
    detail: args.detail ?? null,
  }));
});

afterEach(() => jest.clearAllMocks());

describe('reportSharedRoute', () => {
  it('저장한 뒤 신고 메일을 보낸다', async () => {
    const report = await contentReportService.reportSharedRoute({
      reporterUserId: REPORTER_ID,
      sharedRouteId: ROUTE_ID,
      reason: 'offensive',
      detail: '제목이 욕설입니다',
    });

    expect(report.report_id).toBe('report-1');
    expect(contentReportRepository.create).toHaveBeenCalledWith({
      reporterUserId: REPORTER_ID,
      sharedRouteId: ROUTE_ID,
      reason: 'offensive',
      detail: '제목이 욕설입니다',
    });
    expect(emailService.sendContentReportEmail).toHaveBeenCalledWith(report, route);
  });

  it('메일 발송이 실패해도 신고 접수는 성공한다', async () => {
    emailService.sendContentReportEmail.mockRejectedValue(new Error('SMTP down'));
    jest.spyOn(console, 'warn').mockImplementation(() => {});

    await expect(
      contentReportService.reportSharedRoute({
        reporterUserId: REPORTER_ID,
        sharedRouteId: ROUTE_ID,
        reason: 'spam',
      })
    ).resolves.toMatchObject({ report_id: 'report-1' });

    console.warn.mockRestore();
  });

  it('같은 동선을 다시 신고하면 새 행을 만들지 않고 기존 신고를 돌려준다', async () => {
    contentReportRepository.findByReporterAndRoute.mockResolvedValue({ report_id: 'report-0' });

    const report = await contentReportService.reportSharedRoute({
      reporterUserId: REPORTER_ID,
      sharedRouteId: ROUTE_ID,
      reason: 'spam',
    });

    expect(report.report_id).toBe('report-0');
    expect(contentReportRepository.create).not.toHaveBeenCalled();
    expect(emailService.sendContentReportEmail).not.toHaveBeenCalled();
  });

  it('존재하지 않는 동선이면 404 SHARED_ROUTE_NOT_FOUND', async () => {
    sharedRouteRepository.findById.mockResolvedValue(null);

    await expect(
      contentReportService.reportSharedRoute({
        reporterUserId: REPORTER_ID,
        sharedRouteId: ROUTE_ID,
        reason: 'spam',
      })
    ).rejects.toMatchObject({ statusCode: 404, code: 'SHARED_ROUTE_NOT_FOUND' });
  });

  it('본인이 게시한 동선은 신고할 수 없다', async () => {
    await expect(
      contentReportService.reportSharedRoute({
        reporterUserId: AUTHOR_ID,
        sharedRouteId: ROUTE_ID,
        reason: 'spam',
      })
    ).rejects.toMatchObject({ statusCode: 400, code: 'INVALID_REQUEST' });

    expect(contentReportRepository.create).not.toHaveBeenCalled();
  });
});
