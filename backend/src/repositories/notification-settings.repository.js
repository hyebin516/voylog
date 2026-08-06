const pool = require('../config/db');

async function find(userId) {
  const { rows } = await pool.query('SELECT * FROM notification_settings WHERE user_id = $1', [userId]);
  return rows[0] || null;
}

async function upsert(userId, { tripAlerts, serviceAlerts, marketingAlerts }) {
  const { rows } = await pool.query(
    `INSERT INTO notification_settings (user_id, trip_alerts, service_alerts, marketing_alerts)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (user_id) DO UPDATE
       SET trip_alerts = EXCLUDED.trip_alerts,
           service_alerts = EXCLUDED.service_alerts,
           marketing_alerts = EXCLUDED.marketing_alerts,
           updated_at = now()
     RETURNING *`,
    [userId, tripAlerts, serviceAlerts, marketingAlerts]
  );
  return rows[0];
}

module.exports = { find, upsert };
