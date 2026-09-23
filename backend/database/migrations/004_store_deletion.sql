USE shan_jie_ren_yi;

-- Preserve purchased food references while removing stores from active use.
-- Safe to rerun after an interrupted deployment.
SET @store_deletion_sql = IF(
  EXISTS (SELECT 1 FROM information_schema.columns
          WHERE table_schema = DATABASE() AND table_name = 'stores' AND column_name = 'deleted_at'),
  'SELECT 1',
  'ALTER TABLE stores ADD COLUMN deleted_at DATETIME NULL'
);
PREPARE store_deletion_statement FROM @store_deletion_sql;
EXECUTE store_deletion_statement;
DEALLOCATE PREPARE store_deletion_statement;
