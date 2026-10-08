USE shan_jie_ren_yi;

ALTER TABLE users
  MODIFY COLUMN avatar_key MEDIUMTEXT NULL;

UPDATE users SET avatar_key = NULL;
