-- Redesigns notification_settings to match the design handoff's toggle set:
-- a "추천 알림" section (new vlog recommendations, route generation complete)
-- and a "기타" section (marketing, night-time quiet hours). The old
-- trip_alerts/service_alerts columns are renamed rather than dropped so
-- existing users' preferences carry over instead of resetting.
ALTER TABLE notification_settings RENAME COLUMN trip_alerts TO new_vlog_alerts;
ALTER TABLE notification_settings RENAME COLUMN service_alerts TO route_complete_alerts;
ALTER TABLE notification_settings ADD COLUMN night_silent BOOLEAN NOT NULL DEFAULT false;
