# 商家帳號與商品管理

## 本機驗證

2026-09-10：flutter analyze 無問題；完整 Flutter 測試 96 項通過、2 項僅雲端旗標測試跳過。
以 CLOUD_CATALOG=true 執行雲端商品、會員活動與商家測試共 24 項，全數通過；Android debug APK 編譯成功。
編譯檢查未指定正式 API_BASE_URL，不能直接當作學校正式安裝包。
後端 npm test 34 項通過、3 項真實 MySQL 測試跳過；其中 3 項通過的 VPN 測試是原有工作目錄修改，未納入本次提交。
帳號建立 PowerShell 已通過語法檢查，未在本機執行建立帳號。此電腦未提供 MySQL 執行環境，003 遷移、真實 SQL 整合與學校帳號建立仍待驗收。

## 範圍與限制

雲端模式的商家登入與一般會員分開。商家使用 scrypt 密碼雜湊、隨機 256-bit token、獨立 merchant_sessions；只保存 token 的 SHA-256 雜湊，有效期 8 小時。
登入有限流；停用商家、過期或已撤銷 session 無法管理商品。一般會員 token 不可使用商家 API，商家 token 也不等於會員登入。
2026-09-15 起採商家自行註冊，不需審核。App 雲端模式的商家登入頁可選「註冊商家帳號」，填寫帳號密碼、商家與第一間門市資料及營業日。註冊成功後返回登入頁，以新帳號登入。
後端在同一交易建立 active 商家、新門市及營業日；失敗全部回復。一般會員與商家分別存放於 users、merchants，同一 Email 可各自註冊，但密碼及登入 session 不共用。客戶端不可指定既有門市所有權或管理員角色。
此階段可新增草稿、列出／編輯自有商品、上架與下架；不是金流、商家訂單接單、圖片檔案上傳、Email 驗證或忘記密碼功能。

商品包含名稱、分類、售價／原價、庫存、營養、食材、標籤、HTTPS 圖片網址與即期期限。
沒有圖片時保留替代圖示；伺服器不下載外部圖片。保存期限由 App 本機時區轉 UTC；即期品必須有期限。
eco_priority_score 由後端暫定規則計算（即期品 0.8，其餘 0），不接受客戶端任意指定積分或排名；並非已驗證的 AI 分數。
門市地址與營業日由帳號建立工具設定，商品編輯不能暗中修改整間門市的營業日。此工具未設定超商品牌、GPS 或距離，距離仍可能顯示未提供。

## API

除註冊與登入外，皆需商家 Bearer token；未知路徑不退回展示用原型。註冊與登入共用限流。

| Method | 路徑 | 用途 |
| --- | --- | --- |
| POST | /api/merchant/auth/register | email/password、businessName、storeName、address、businessHours、businessWeekdays（1–7）、contactPhone（選填）；成功 201，重複商家 Email 409 |
| POST | /api/merchant/auth/login | email/password；只有 active 商家可登入 |
| POST | /api/merchant/auth/logout | 撤銷目前商家 token |
| GET | /api/merchant/me | 商家資料及其可管理門市 ID，不回傳密碼 |
| GET | /api/merchant/products | 自有商品，含草稿／下架／售完，每頁 20 筆，before=nextCursor |
| GET | /api/merchant/products/:id | 自有商品及 revision；他人商品回 404 |
| POST | /api/merchant/products | 建立草稿，需 UUID Idempotency-Key；重送同內容回原商品 |
| PUT | /api/merchant/products/:id | 提交完整商品與 revision；不可移轉門市，上架中不可編輯 |
| PUT | /api/merchant/products/:id/status | revision 與 status（active 或 paused） |

建立、編輯、上下架使用交易與鎖定，所有權由 session 及資料庫核對，不信任 body 的 merchantId。
草稿不在公開目錄出現。上架須庫存大於零、未過期、門市已有營業日；實際下單另依台灣當日星期檢查。
上架中須先下架再編輯；儲存後回到草稿。revision 衝突回 409，避免舊表單覆蓋別處修改。
App 在送出新草稿前，先依 API 網址及商家 ID 保存 UUID 與完整內容。逾時／斷線後可用「確認待建立草稿」重送原內容。
未確認的草稿禁止編輯原送出內容；重開後仍可重試。持久資料損壞時停止新增，不自動刪除防重送資料。
編輯／上下架的回應若遺失，請重新載入商品核對 revision 與狀態，不能以錯誤訊息推定伺服器沒有完成。

## 學校伺服器部署

**自行註冊沿用 003 結構，沒有新增遷移。學校已驗證套用 003，不必重跑。以下首次部署程序僅供尚未套用 003 的環境參考。**
僅在學校遠端桌面的管理員 PowerShell 操作，保持 MySQLFoodApp 3307、AppServ 3306、Apache 與防火牆既有設定不變。
每一步成功才繼續，有錯誤請停下並保留輸出；不要一次貼完所有區段。

### 1. 維護與備份

```powershell
cd C:\School\my_app
git status --short --branch
```

確認沒有未處理的修改，再停止 API 並備份：

```powershell
cd backend
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\api_service.ps1 -Action Stop
$mysqlBin = 'C:\Program Files\MySQL\MySQL Server 26.7\bin'
$backupDir = Join-Path $env:USERPROFILE 'FoodAppBackups'
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
$backupFile = Join-Path $backupDir ('foodapp-before-003-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.sql')
& "$mysqlBin\mysqldump.exe" --protocol=TCP -h 127.0.0.1 -P 3307 -u root -p --single-transaction --no-tablespaces --set-gtid-purged=OFF --databases shan_jie_ren_yi --result-file=$backupFile
if ($LASTEXITCODE -ne 0) { throw 'Backup failed. Stop here.' }
Get-Item -LiteralPath $backupFile | Select-Object FullName, Length
```

此時 API 已停止；若備份失敗，不套用遷移。原版程式未更新前可用既有 Start 恢復服務再排除備份問題。
備份仍須另存異機並驗證還原；不要將備份或密碼提交 Git。

### 2. 更新程式

```powershell
cd C:\School\my_app
git pull --ff-only
cd backend
npm.cmd ci
& "$mysqlBin\mysql.exe" --protocol=TCP -h 127.0.0.1 -P 3307 -u root -p
```

### 3. 僅首次套用 003

在 mysql> 內先確認目標：

```sql
SELECT @@port;
USE shan_jie_ren_yi;
SHOW COLUMNS FROM foods LIKE 'merchant_revision';
SHOW TABLES LIKE 'merchant_sessions';
SHOW TABLES LIKE 'merchant_product_requests';
```

埠須為 3307，且以上新欄位／新表三個查詢皆為空，才執行一次：

```sql
SOURCE C:/School/my_app/backend/database/migrations/003_merchant_management.sql;
EXIT;
```

若任何新欄位／資料表已存在，先查核遷移狀態；不可盲目重跑。MySQL DDL 不提供整份檔案的交易回滾，部分失敗須逐項處理。
不重新執行 schema.sql、001、002。只有全新空資料庫才匯入最新版 schema.sql 再套用 001；新版 schema 已含 002／003 的結構。

### 4. 驗證並啟動

```powershell
npm.cmd run db:check
npm.cmd test
npm.cmd run test:mysql
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\api_service.ps1 -Action Start
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\api_service.ps1 -Action Status
```

test:mysql 現在包含商家真實 MySQL 測試，須零失敗且零跳過。它只建立／清理自己的臨時測試資料，不會建立可供使用者登入的永久帳號。
測試若失敗，勿繼續 Start 或重跑遷移；保留完整錯誤供查核。這是服務重啟，不是整台主機重開機驗收。

## 管理者代建帳號（選用）

日常註冊改由 App 完成，不需執行此工具。下列工具僅保留給管理者代建帳號，不代表仍有審核流程。

上述步驟通過後，才在學校主機的管理員 PowerShell 執行：

```powershell
cd C:\School\my_app\backend
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\provision_merchant.ps1
```

依序輸入真實或明確標示測試用途的商家名稱、Email、門市名稱、地址、營業時間、電話、營業日（週一=1，週日=7）。
輸入 CREATE 確認後，密碼以隱藏輸入並再次確認，不放在命令列、.env 或 SQL 明文範例。
工具讀取 backend/.env 的資料庫連線設定，以交易新增 active 商家、第一間門市及營業日；不需要將 App DB 帳號改成 root。
管理員主機存取本身是授權邊界，請保護 .env。工具沒有 HTTP 開通入口。
成功僅輸出 merchantId、storeId、status；重複 Email 會失敗，不會覆寫原密碼或取得其他商家門市。
不要把密碼傳給我或貼在截圖。停用帳號與重設密碼仍由資料庫管理者處理，本次不提供公開重設流程。

## App 驗收

使用 Flutter Cloud Catalog (Debug) 及獲核准的 HTTPS API 網址；展示模式仍只建立本機展示草稿。
商家入口以剛建立的帳號登入，新增草稿後應可重新登入讀回。選擇上架後，重新載入公開目錄應可看到可售商品。
下架後公開目錄不再顯示，修改後須重新上架。另一商家不應讀取或修改它。
目前外部防火牆／HTTPS 仍未解決，不能宣稱真機上架、跨裝置或接單已驗收。
