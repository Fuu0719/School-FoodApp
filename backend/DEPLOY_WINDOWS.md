# Windows 會員服務部署

## 目前範圍

會員註冊、Email 驗證、登入、登出、個人資料、頭像與飲食偏好已使用 MySQL。雲端模式已串接商品、收藏、瀏覽、排行榜、訂單、綠界 Stage 測試付款及獨立商家商品管理；同一 Node.js 服務也提供專題網站與管理後台。
GitHub 最新版需要 migration `001` 至 `011`。學校最後已確認至 `010`；部署最新版前須備份並套用 `011` 一次。不可重跑既有 migration，也不可重新匯入 `schema.sql`。
資料庫查詢、備份及刪除測試會員的完整步驟見 [資料庫操作手冊](DATABASE_OPERATIONS.md)。

## 學校伺服器更新

全部指令在遠端桌面以系統管理員 PowerShell 執行。既有主機先停止 API Windows 服務：

```powershell
cd C:\School\my_app\backend
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\api_service.ps1 -Action Stop
```

```powershell
cd C:\School\my_app
git status
git pull --ff-only origin main
cd backend
npm.cmd ci
```

如果 git 顯示專案檔案有未提交修改，先確認內容，不覆蓋修改；backend/.env 是忽略檔，不受 pull 影響。

用新 MySQL 服務的 root 登入（使用 3307）：

```powershell
& "C:\Program Files\MySQL\MySQL Server 26.7\bin\mysql.exe" --protocol=TCP -h 127.0.0.1 -P 3307 -u root -p
```

平常更新只需確認資料庫與資料表。只有版本明確新增尚未套用的 migration，才執行指定檔案：

```sql
SELECT @@port, @@datadir;
USE shan_jie_ren_yi;
SHOW TABLES LIKE 'pending_member_registrations';
SHOW TABLES LIKE 'member_password_reset_tokens';
SHOW COLUMNS FROM purchase_orders LIKE 'payment_expires_at';
SHOW TABLES;
EXIT;
```

確認連接的是專案資料目錄與 3307；兩張 `009` 資料表都應存在。若 `payment_expires_at` 不存在，在已完成備份且 API 已停止的情況下執行一次：

```sql
USE shan_jie_ren_yi;
SOURCE C:/School/my_app/backend/database/migrations/011_order_reservations_and_linked_sessions.sql;
SHOW COLUMNS FROM purchase_orders LIKE 'payment_expires_at';
SHOW COLUMNS FROM user_sessions LIKE 'switched_from_merchant_id';
SHOW COLUMNS FROM merchant_sessions LIKE 'switched_from_user_id';
EXIT;
```

`011` 會清除既有會員與商家 session，以免無來源資訊的舊切換 session 繼續有效；部署後所有帳號需要重新登入。若欄位已存在，不可重跑。只有全新空白資料庫才使用最新版 `schema.sql`；既有環境一律依尚未套用的 migration 升級。

保留 backend/.env 裡原有密碼，確認以下設定：

```dotenv
HOST=127.0.0.1
PORT=3000
DB_HOST=127.0.0.1
DB_PORT=3307
DB_USER=food_app
DB_PASSWORD="填入 food_app 密碼"
DB_NAME=shan_jie_ren_yi
```

如果密碼本身含雙引號，dotenv 可使用單引號包住；不要把 .env 或密碼輸出傳到對話或 Git。

```powershell
npm.cmd run db:check
npm.cmd test
npm.cmd run test:mysql
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\api_service.ps1 -Action Start
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\api_service.ps1 -Action Status
```

db:check 檢查實際資料庫和登入紀錄表。test:mysql 會建立隨機測試會員，實際驗證註冊、登入、改偏好、另一個 API 實例讀取、登出撤銷與再次登入，再刪除該測試會員。
一般 npm test 使用替代 repository 驗證 HTTP 行為，不代表雲端 MySQL 驗證完成。
test:mysql 中的另一個 API 實例測試不等於已驗證 Windows 重新開機後的常駐服務。

## App 連線

VS Code 選 Flutter Member API (Debug)，選已啟動的 Android 裝置，按 F5，輸入包含 /api 的 API 網址。
這個啟動設定使用本機工作目錄程式，不會因未提交的修改中止；需自行 pull 已核對的新版。

同一台開發電腦的 Android 模擬器連本機 API 使用 http://10.0.2.2:3000/api。
這個位址不會指向學校雲端伺服器。

學校 API 維持綁定 `127.0.0.1:3000`，MySQL 維持 `127.0.0.1:3307`；兩者都不直接對外開放。固定 HTTPS 入口為 `https://api.mealmind-app.online`，由 Cloudflare Named Tunnel Windows 服務轉送至本機 API。App 的 `API_BASE_URL` 須包含 `/api`。

`MySQLFoodApp`、`SchoolFoodAppApi` 與 `cloudflared` 均設為 Automatic。PowerShell 驗證：

```powershell
Get-Service MySQLFoodApp, SchoolFoodAppApi, cloudflared
Invoke-RestMethod "https://api.mealmind-app.online/api/health"
```

命令列也可指定網址：

```powershell
flutter run --dart-define=CLOUD_CATALOG=true `
  --dart-define=API_BASE_URL=https://api.mealmind-app.online/api
```

## 正式 Email 與付款網址

正式品牌寄件者使用 `noreply@mealmind-app.online`，不得再使用 Gmail 地址。先在交易郵件服務商驗證 `mealmind-app.online`，將服務商提供的 SPF、DKIM 等 DNS 紀錄加到 Cloudflare，驗證通過後才更新學校端 `.env`：

```dotenv
SMTP_HOST=smtp.resend.com
SMTP_PORT=465
SMTP_SECURE=true
SMTP_USER=resend
SMTP_PASSWORD=由郵件服務商建立的API金鑰
SMTP_FROM="MealMind <noreply@mealmind-app.online>"
SMTP_ALLOWED_FROM_DOMAIN=mealmind-app.online
APP_PUBLIC_URL=https://mealmind-app.online
PUBLIC_BASE_URL=https://api.mealmind-app.online
```

`.env` 不可提交 Git。更新後先執行寄信測試，再重啟正式 API。舊通道停用及稽核方式見 [通道遷移紀錄](../docs/tunnel_migration_history.md)。

新增安全儲存外掛後需停止 App 再完整編譯，Hot Reload 無法載入新原生外掛。
Windows 桌面外掛的符號連結錯誤需在開發電腦處理；與伺服器 MySQL 無關。

## 手動驗收

1. 用新 Email 註冊，密碼 8 至 16 字元；兩次密碼不一致應阻止送出。
2. 用相同 Email 再註冊，應顯示已註冊；錯誤密碼不應登入。
3. 正確登入應返回首頁。編輯姓名、電話、身高、體重、健康目標、偏好及不限預算/距離，儲存成功後推薦使用新偏好。
4. 關閉重開 App，應向伺服器重新驗證憑證並取得最新會員資料；離線時不以舊資料自動登入。
5. 登出後登入另一個帳號，不應看到前一人的收藏、購物車或購買紀錄；切回原帳號可讀取該裝置內原紀錄。
6. 儲存時斷網，應顯示錯誤且不宣告成功；恢復連線後可重試。
7. 停止並重啟 API 後再次登入，會員資料與偏好仍存在。

## 待完成項目

固定 HTTPS、migration `001` 至 `010`、資料搬移、綠界 Stage、Resend 網域寄件與必要 Windows 服務已有歷史驗收。GitHub 最新版的 migration `011`、網站／管理後台與 App `1.0.0+36` 尚待學校端部署及回歸；仍需完成正式金流申請及退款／對帳流程、真實商家接單流程、定期異機備份與還原演練。
目前登入憑證有效七天，資料庫只存 SHA-256 摘要；每次請求查驗效期，登出即撤銷該憑證。
App 安全儲存憑證，不保存會員密碼。密碼使用 Node.js scrypt 加上隨機 salt。
