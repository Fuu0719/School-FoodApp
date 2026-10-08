USE shan_jie_ren_yi;

ALTER TABLE users
  ADD COLUMN avatar_key VARCHAR(24) NOT NULL DEFAULT 'sprout' AFTER phone;
