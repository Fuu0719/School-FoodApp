USE shan_jie_ren_yi;

ALTER TABLE purchase_orders
  ADD COLUMN payment_status ENUM('pending', 'paid', 'failed', 'cancelled') NOT NULL DEFAULT 'pending' AFTER saved_amount,
  ADD COLUMN merchant_trade_no VARCHAR(20) CHARACTER SET ascii COLLATE ascii_bin NULL AFTER payment_status,
  ADD COLUMN payment_token_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL AFTER merchant_trade_no,
  ADD COLUMN paid_at DATETIME NULL AFTER payment_token_hash,
  ADD UNIQUE KEY purchase_orders_trade_no_unique (merchant_trade_no),
  ADD UNIQUE KEY purchase_orders_payment_token_unique (payment_token_hash);

-- Orders created before online payment was introduced are completed historical orders.
UPDATE purchase_orders
SET payment_status = 'paid', paid_at = purchased_at
WHERE merchant_trade_no IS NULL;
