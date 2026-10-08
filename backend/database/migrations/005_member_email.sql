USE shan_jie_ren_yi;

ALTER TABLE users ADD COLUMN email_verified_at DATETIME NULL AFTER password_hash;
UPDATE users SET email_verified_at = UTC_TIMESTAMP() WHERE email_verified_at IS NULL;

CREATE TABLE member_email_codes (
  user_id BIGINT UNSIGNED NOT NULL,
  purpose ENUM('verify_email', 'reset_password') NOT NULL,
  code_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  expires_at DATETIME NOT NULL,
  attempts TINYINT UNSIGNED NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, purpose),
  CONSTRAINT member_email_codes_user_fk
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
);


