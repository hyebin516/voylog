-- FR-12: "새 브이로그 추천" alerts are dropped. Sending them would need a
-- daily YouTube keyword search per user (API quota, a scheduler, and no
-- clear signal for what counts as "new to this user") -- while a trip's
-- start date is already stored, so a D-1 reminder needs nothing new.
ALTER TABLE notification_settings RENAME COLUMN new_vlog_alerts TO trip_start_alerts;

-- One reminder per trip: without this the daily job would send it again on
-- every run of the same day.
ALTER TABLE trips ADD COLUMN start_alert_sent_at TIMESTAMPTZ;
