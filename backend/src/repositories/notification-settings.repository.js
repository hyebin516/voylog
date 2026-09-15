const pool = require('../config/db');

async function find(userId) {
  const { rows } = await pool.query('SELECT * FROM notification_settings WHERE user_id = $1', [userId]);
  return rows[0] || null;
}

async function upsert(userId, { newVlogAlerts, routeCompleteAlerts, marketingAlerts, nightSilent }) {
  const { rows } = await pool.query(
    `INSERT INTO notification_settings (user_id, new_vlog_alerts, route_complete_alerts, marketing_alerts, night_silent)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (user_id) DO UPDATE
       SET new_vlog_alerts = EXCLUDED.new_vlog_alerts,
           route_complete_alerts = EXCLUDED.route_complete_alerts,
           marketing_alerts = EXCLUDED.marketing_alerts,
           night_silent = EXCLUDED.night_silent,
           updated_at = now()
     RETURNING *`,
    [userId, newVlogAlerts, routeCompleteAlerts, marketingAlerts, nightSilent]
  );
  return rows[0];
}

module.exports = { find, upsert };
