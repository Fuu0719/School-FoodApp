# 學校 MySQL 資料庫操作手冊

本文件適用於學校伺服器 `C:\School\my_app`。資料庫服務使用 `127.0.0.1:3307`，資料庫名稱為 `shan_jie_ren_yi`。所有刪除操作都應先備份、查詢目標並使用交易；不要把密碼貼到指令、截圖、對話或 Git。

## 從 PowerShell 登入 MySQL

以系統管理員開啟 PowerShell：

```powershell
cd C:\School\my_app\backend

$mysql = "C:\Program Files\MySQL\MySQL Server 26.7\bin\mysql.exe"
& $mysql --protocol=TCP --host=127.0.0.1 --port=3307 --user=root --password
```

看到 `Enter password:` 後輸入 MySQL root 密碼。輸入過程不會顯示字元，完成後按 Enter。成功時會出現 `mysql>`。

先確認連線目標：

```sql
SELECT VERSION(), @@hostname, @@port, @@datadir;
USE shan_jie_ren_yi;
SELECT DATABASE();
SHOW TABLES;
```

結束 MySQL：

```sql
EXIT;
```

## 登入前先備份

以下在 PowerShell 執行，不是在 `mysql>` 內執行：

```powershell
$backupDir = "C:\School\FoodAppBackups"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$dumpFile = Join-Path $backupDir ("foodapp-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".sql")
$mysqldump = "C:\Program Files\MySQL\MySQL Server 26.7\bin\mysqldump.exe"

& $mysqldump `
  --protocol=TCP `
  --host=127.0.0.1 `
  --port=3307 `
  --user=root `
  --password `
  --single-transaction `
  --routines `
  --triggers `
  --no-tablespaces `
  --result-file="$dumpFile" `
  shan_jie_ren_yi

if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $dumpFile) -or (Get-Item -LiteralPath $dumpFile).Length -eq 0) {
  throw "資料庫備份失敗"
}
Get-Item -LiteralPath $dumpFile | Select-Object FullName, Length, LastWriteTime
```

只有最後列出非空白備份檔，才繼續刪除或 migration。

## 常用查詢

```sql
USE shan_jie_ren_yi;

-- 查看會員，不顯示密碼雜湊。
SELECT id, name, email, email_verified_at, created_at
FROM users
ORDER BY id;

-- 依 Email 查單一會員。
SELECT id, name, email, email_verified_at, created_at
FROM users
WHERE email = 'fengu0719@gmail.com';

-- 查看資料表欄位與索引。
DESCRIBE users;
SHOW INDEX FROM users;

-- 查看會員訂單。
SELECT id, user_id, total_price, payment_status, paid_at, purchased_at
FROM purchase_orders
WHERE user_id = 117
ORDER BY id DESC;

-- 查看目前資料量。
SELECT 'users' AS table_name, COUNT(*) AS row_count FROM users
UNION ALL SELECT 'purchase_orders', COUNT(*) FROM purchase_orders
UNION ALL SELECT 'favorites', COUNT(*) FROM favorites
UNION ALL SELECT 'browsing_histories', COUNT(*) FROM browsing_histories;
```

## 安全刪除單一測試會員及其全部關聯資料

`users` 的關聯外鍵設定為 `ON DELETE CASCADE`。刪除會員時，該會員的偏好、Email 驗證碼、登入 session、收藏、瀏覽紀錄、搜尋紀錄、訂單與訂單明細、推薦回饋會一併刪除。仍應在刪除前後查核，避免 Email 輸入錯誤。

先登入 MySQL 並執行：

```sql
USE shan_jie_ren_yi;
START TRANSACTION;

SET @target_email = 'fengu0719@gmail.com';
SET @target_user_id = (
  SELECT id FROM users WHERE email = @target_email LIMIT 1
);

SELECT id, name, email, email_verified_at, created_at
FROM users
WHERE id = @target_user_id;

SELECT 'user_preferences' AS related_table, COUNT(*) AS row_count FROM user_preferences WHERE user_id = @target_user_id
UNION ALL SELECT 'member_email_codes', COUNT(*) FROM member_email_codes WHERE user_id = @target_user_id
UNION ALL SELECT 'user_sessions', COUNT(*) FROM user_sessions WHERE user_id = @target_user_id
UNION ALL SELECT 'favorites', COUNT(*) FROM favorites WHERE user_id = @target_user_id
UNION ALL SELECT 'browsing_histories', COUNT(*) FROM browsing_histories WHERE user_id = @target_user_id
UNION ALL SELECT 'search_logs', COUNT(*) FROM search_logs WHERE user_id = @target_user_id
UNION ALL SELECT 'purchase_orders', COUNT(*) FROM purchase_orders WHERE user_id = @target_user_id
UNION ALL SELECT 'recommendation_feedback', COUNT(*) FROM recommendation_feedback WHERE user_id = @target_user_id;

DELETE FROM users WHERE id = @target_user_id AND email = @target_email;
SELECT ROW_COUNT() AS deleted_users;

SELECT COUNT(*) AS remaining_users
FROM users
WHERE email = @target_email;
```

確認 `deleted_users = 1` 且 `remaining_users = 0` 後才提交：

```sql
COMMIT;
```

若結果不正確，改為：

```sql
ROLLBACK;
```

最短指令雖然是：

```sql
DELETE FROM users WHERE email = 'fengu0719@gmail.com';
```

但正式操作應使用上面的交易與查核流程。

## 刪除後驗證無殘留

記下刪除前的會員 ID，例如 `117`，再執行：

```sql
SELECT COUNT(*) FROM users WHERE id = 117;
SELECT COUNT(*) FROM user_preferences WHERE user_id = 117;
SELECT COUNT(*) FROM member_email_codes WHERE user_id = 117;
SELECT COUNT(*) FROM user_sessions WHERE user_id = 117;
SELECT COUNT(*) FROM favorites WHERE user_id = 117;
SELECT COUNT(*) FROM browsing_histories WHERE user_id = 117;
SELECT COUNT(*) FROM search_logs WHERE user_id = 117;
SELECT COUNT(*) FROM purchase_orders WHERE user_id = 117;
SELECT COUNT(*) FROM recommendation_feedback WHERE user_id = 117;
```

全部都應為 `0`。訂單明細透過 `purchase_orders` 連鎖刪除，可額外查核：

```sql
SELECT COUNT(*)
FROM purchase_order_items i
LEFT JOIN purchase_orders o ON o.id = i.purchase_order_id
WHERE o.id IS NULL;
```

此查詢應為 `0`，表示沒有孤兒訂單明細。

## 更新程式後檢查資料庫

回到 PowerShell：

```powershell
cd C:\School\my_app\backend
npm.cmd run db:check
```

只有新版明確要求且已確認尚未套用時，才能執行對應 migration。學校現有資料庫已完成 `001` 至 `008`，不可重跑，也不可重新匯入 `schema.sql`。
