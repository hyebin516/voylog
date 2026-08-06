const pool = require('../config/db');

async function create(userId, name) {
  const { rows } = await pool.query(
    'INSERT INTO bookmark_folders (user_id, name) VALUES ($1, $2) RETURNING *',
    [userId, name]
  );
  return rows[0];
}

async function findAllByUser(userId) {
  const { rows } = await pool.query(
    `SELECT f.*, count(i.bookmark_id)::int AS bookmark_count
     FROM bookmark_folders f
     LEFT JOIN bookmark_folder_items i ON i.folder_id = f.folder_id
     WHERE f.user_id = $1 AND f.deleted_at IS NULL
     GROUP BY f.folder_id
     ORDER BY f.created_at DESC`,
    [userId]
  );
  return rows;
}

async function findById(folderId) {
  const { rows } = await pool.query(
    'SELECT * FROM bookmark_folders WHERE folder_id = $1 AND deleted_at IS NULL',
    [folderId]
  );
  return rows[0] || null;
}

async function softDelete(folderId) {
  await pool.query('UPDATE bookmark_folders SET deleted_at = now() WHERE folder_id = $1', [folderId]);
}

async function addItem(folderId, bookmarkId) {
  await pool.query(
    `INSERT INTO bookmark_folder_items (folder_id, bookmark_id)
     VALUES ($1, $2)
     ON CONFLICT (folder_id, bookmark_id) DO NOTHING`,
    [folderId, bookmarkId]
  );
}

async function removeItem(folderId, bookmarkId) {
  await pool.query(
    'DELETE FROM bookmark_folder_items WHERE folder_id = $1 AND bookmark_id = $2',
    [folderId, bookmarkId]
  );
}

async function findBookmarksInFolder(folderId) {
  const { rows } = await pool.query(
    `SELECT b.bookmark_id, b.created_at, p.*
     FROM bookmark_folder_items i
     JOIN bookmarks b ON b.bookmark_id = i.bookmark_id
     JOIN places p ON p.place_id = b.place_id
     WHERE i.folder_id = $1
     ORDER BY i.created_at DESC`,
    [folderId]
  );
  return rows;
}

module.exports = { create, findAllByUser, findById, softDelete, addItem, removeItem, findBookmarksInFolder };
