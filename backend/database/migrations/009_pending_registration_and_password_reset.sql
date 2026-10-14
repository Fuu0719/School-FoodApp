USE shan_jie_ren_yi;

CREATE TABLE pending_member_registrations (
  email VARCHAR(160) NOT NULL,
  name VARCHAR(80) NOT NULL,
  password_hash VARCHAR(255) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  code_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  expires_at DATETIME NOT NULL,
  attempts TINYINT UNSIGNED NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (email),
  KEY pending_member_registrations_expiry (expires_at)
);

CREATE TABLE member_password_reset_tokens (
  token_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  expires_at DATETIME NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (token_hash),
  UNIQUE KEY member_password_reset_tokens_user (user_id),
  KEY member_password_reset_tokens_expiry (expires_at),
  CONSTRAINT member_password_reset_tokens_user_fk
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
);
