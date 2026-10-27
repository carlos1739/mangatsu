-- One-time migration from numeric MAL IDs to MangaDex UUIDs.
-- This intentionally clears old bookmarks; user accounts remain untouched.
DELETE FROM bookmarks;

ALTER TABLE bookmarks
  DROP INDEX uniq_user_manga,
  MODIFY manga_id CHAR(36) NOT NULL,
  ADD UNIQUE KEY uniq_user_manga (user_id, manga_id);
