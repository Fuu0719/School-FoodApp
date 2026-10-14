ALTER TABLE foods
  ADD COLUMN deleted_at DATETIME NULL AFTER merchant_revision,
  ADD KEY foods_deleted_at_index (deleted_at);

CREATE TABLE member_merchant_links (
  user_id BIGINT UNSIGNED NOT NULL,
  merchant_id BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id),
  UNIQUE KEY member_merchant_links_merchant_unique (merchant_id),
  CONSTRAINT member_merchant_links_user_fk
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT member_merchant_links_merchant_fk
    FOREIGN KEY (merchant_id) REFERENCES merchants(id) ON DELETE CASCADE
);
