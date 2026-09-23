CREATE DATABASE IF NOT EXISTS shan_jie_ren_yi
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE shan_jie_ren_yi;

CREATE TABLE users (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name VARCHAR(80) NOT NULL,
  email VARCHAR(160) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  phone VARCHAR(40) NULL,
  height_cm DECIMAL(5,2) NULL,
  weight_kg DECIMAL(5,2) NULL,
  health_goal ENUM('maintain', 'muscle_gain', 'fat_loss') NOT NULL DEFAULT 'maintain',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY users_email_unique (email)
);

CREATE TABLE user_preferences (
  user_id BIGINT UNSIGNED NOT NULL,
  budget_min INT UNSIGNED NOT NULL DEFAULT 0,
  budget_max INT UNSIGNED NULL,
  distance_limit_meters INT UNSIGNED NULL,
  waste_reduction_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  avoid_ingredients JSON NULL,
  dietary_tags JSON NOT NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id),
  CONSTRAINT user_preferences_user_fk
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
);

CREATE TABLE merchants (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  business_name VARCHAR(120) NOT NULL,
  email VARCHAR(160) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  contact_phone VARCHAR(40) NULL,
  status ENUM('pending', 'active', 'paused') NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY merchants_email_unique (email)
);

CREATE TABLE stores (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  merchant_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(120) NOT NULL,
  brand VARCHAR(60) NULL,
  address VARCHAR(255) NOT NULL,
  latitude DECIMAL(10,7) NULL,
  longitude DECIMAL(10,7) NULL,
  distance_meters INT UNSIGNED NULL,
  business_hours VARCHAR(80) NOT NULL,
  contact_phone VARCHAR(40) NULL,
  deleted_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY stores_merchant_id_index (merchant_id),
  CONSTRAINT stores_merchant_fk
    FOREIGN KEY (merchant_id) REFERENCES merchants(id)
    ON DELETE CASCADE
);

CREATE TABLE store_business_weekdays (
  store_id BIGINT UNSIGNED NOT NULL,
  weekday TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (store_id, weekday),
  CONSTRAINT store_business_weekdays_store_fk
    FOREIGN KEY (store_id) REFERENCES stores(id)
    ON DELETE CASCADE,
  CONSTRAINT store_business_weekdays_range
    CHECK (weekday BETWEEN 1 AND 7)
);

CREATE TABLE foods (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  store_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(120) NOT NULL,
  category VARCHAR(40) NOT NULL,
  price INT UNSIGNED NOT NULL,
  original_price INT UNSIGNED NULL,
  discount_label VARCHAR(40) NULL,
  image_url VARCHAR(600) NULL,
  stock_count INT UNSIGNED NOT NULL DEFAULT 0,
  calories INT UNSIGNED NOT NULL DEFAULT 0,
  weight_grams INT UNSIGNED NOT NULL DEFAULT 0,
  protein_grams INT UNSIGNED NOT NULL DEFAULT 0,
  fat_grams INT UNSIGNED NOT NULL DEFAULT 0,
  carbs_grams INT UNSIGNED NOT NULL DEFAULT 0,
  expires_at DATETIME NULL,
  is_expiring_soon BOOLEAN NOT NULL DEFAULT FALSE,
  eco_priority_score DECIMAL(4,3) NOT NULL DEFAULT 0,
  recommendation_reason VARCHAR(255) NULL,
  status ENUM('draft', 'active', 'sold_out', 'paused') NOT NULL DEFAULT 'draft',
  merchant_revision INT UNSIGNED NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY foods_store_id_index (store_id),
  KEY foods_category_index (category),
  KEY foods_expiring_index (is_expiring_soon, expires_at),
  CONSTRAINT foods_store_fk
    FOREIGN KEY (store_id) REFERENCES stores(id)
    ON DELETE CASCADE
);

CREATE TABLE merchant_sessions (
  token_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  merchant_id BIGINT UNSIGNED NOT NULL,
  expires_at DATETIME NOT NULL,
  PRIMARY KEY (token_hash),
  KEY merchant_sessions_expiry (merchant_id, expires_at),
  CONSTRAINT merchant_sessions_merchant_fk FOREIGN KEY (merchant_id) REFERENCES merchants(id) ON DELETE CASCADE
);

CREATE TABLE merchant_product_requests (
  merchant_id BIGINT UNSIGNED NOT NULL,
  request_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  request_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  food_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (merchant_id, request_id),
  CONSTRAINT merchant_requests_merchant_fk FOREIGN KEY (merchant_id) REFERENCES merchants(id) ON DELETE CASCADE,
  CONSTRAINT merchant_requests_food_fk FOREIGN KEY (food_id) REFERENCES foods(id) ON DELETE CASCADE
);

CREATE TABLE food_tags (
  food_id BIGINT UNSIGNED NOT NULL,
  tag VARCHAR(40) NOT NULL,
  PRIMARY KEY (food_id, tag),
  CONSTRAINT food_tags_food_fk
    FOREIGN KEY (food_id) REFERENCES foods(id)
    ON DELETE CASCADE
);

CREATE TABLE food_ingredients (
  food_id BIGINT UNSIGNED NOT NULL,
  ingredient VARCHAR(60) NOT NULL,
  PRIMARY KEY (food_id, ingredient),
  CONSTRAINT food_ingredients_food_fk
    FOREIGN KEY (food_id) REFERENCES foods(id)
    ON DELETE CASCADE
);

CREATE TABLE favorites (
  user_id BIGINT UNSIGNED NOT NULL,
  food_id BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, food_id),
  CONSTRAINT favorites_user_fk
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  CONSTRAINT favorites_food_fk
    FOREIGN KEY (food_id) REFERENCES foods(id)
    ON DELETE CASCADE
);

CREATE TABLE browsing_histories (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  food_id BIGINT UNSIGNED NOT NULL,
  viewed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY browsing_histories_user_viewed_index (user_id, viewed_at),
  CONSTRAINT browsing_histories_user_fk
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  CONSTRAINT browsing_histories_food_fk
    FOREIGN KEY (food_id) REFERENCES foods(id)
    ON DELETE CASCADE
);

CREATE TABLE search_logs (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  keyword VARCHAR(120) NULL,
  filter_summary VARCHAR(255) NULL,
  searched_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY search_logs_user_time_index (user_id, searched_at),
  CONSTRAINT search_logs_user_fk
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
);

CREATE TABLE purchase_orders (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  total_quantity INT UNSIGNED NOT NULL,
  total_price INT UNSIGNED NOT NULL,
  eco_points INT UNSIGNED NOT NULL DEFAULT 0,
  saved_amount INT UNSIGNED NOT NULL DEFAULT 0,
  client_request_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  request_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
  purchased_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY purchase_orders_user_time_index (user_id, purchased_at),
  UNIQUE KEY purchase_orders_request_unique (user_id, client_request_id),
  CONSTRAINT purchase_orders_user_fk
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
);

CREATE TABLE purchase_order_items (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  purchase_order_id BIGINT UNSIGNED NOT NULL,
  food_id BIGINT UNSIGNED NOT NULL,
  quantity INT UNSIGNED NOT NULL,
  unit_price INT UNSIGNED NOT NULL,
  original_unit_price INT UNSIGNED NULL,
  food_snapshot JSON NULL,
  eco_points INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  CONSTRAINT purchase_order_items_order_fk
    FOREIGN KEY (purchase_order_id) REFERENCES purchase_orders(id)
    ON DELETE CASCADE,
  CONSTRAINT purchase_order_items_food_fk
    FOREIGN KEY (food_id) REFERENCES foods(id)
);

CREATE TABLE recommendation_feedback (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  food_id BIGINT UNSIGNED NOT NULL,
  action ENUM('view', 'favorite', 'unfavorite', 'add_to_cart', 'purchase', 'rating') NOT NULL,
  rating TINYINT UNSIGNED NULL,
  preference_score DECIMAL(4,3) NULL,
  distance_score DECIMAL(4,3) NULL,
  budget_score DECIMAL(4,3) NULL,
  eco_score DECIMAL(4,3) NULL,
  final_score DECIMAL(4,3) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY recommendation_feedback_user_time_index (user_id, created_at),
  CONSTRAINT recommendation_feedback_user_fk
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  CONSTRAINT recommendation_feedback_food_fk
    FOREIGN KEY (food_id) REFERENCES foods(id)
    ON DELETE CASCADE,
  CONSTRAINT recommendation_feedback_rating_range
    CHECK (rating IS NULL OR rating BETWEEN 1 AND 5)
);
