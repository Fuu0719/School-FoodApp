USE shan_jie_ren_yi;

ALTER TABLE purchase_orders
  ADD COLUMN payment_expires_at DATETIME NULL AFTER payment_token_hash,
  ADD COLUMN released_at DATETIME NULL AFTER paid_at,
  ADD KEY purchase_orders_payment_expiry (payment_status, payment_expires_at);

ALTER TABLE user_sessions
  ADD COLUMN switched_from_merchant_id BIGINT UNSIGNED NULL AFTER user_id,
  ADD KEY user_sessions_switch_source (switched_from_merchant_id),
  ADD CONSTRAINT user_sessions_switch_merchant_fk
    FOREIGN KEY (switched_from_merchant_id) REFERENCES merchants(id) ON DELETE CASCADE;

ALTER TABLE merchant_sessions
  ADD COLUMN switched_from_user_id BIGINT UNSIGNED NULL AFTER merchant_id,
  ADD KEY merchant_sessions_switch_source (switched_from_user_id),
  ADD CONSTRAINT merchant_sessions_switch_user_fk
    FOREIGN KEY (switched_from_user_id) REFERENCES users(id) ON DELETE CASCADE;

-- Existing switched sessions have no provenance and cannot be revoked precisely.
-- A one-time sign-in is safer than leaving cross-account sessions active.
DELETE FROM user_sessions;
DELETE FROM merchant_sessions;

-- Existing abandoned orders are made eligible for the normal release worker.
UPDATE purchase_orders
SET payment_expires_at = DATE_ADD(purchased_at, INTERVAL 15 MINUTE)
WHERE payment_status = 'pending' AND payment_expires_at IS NULL;
