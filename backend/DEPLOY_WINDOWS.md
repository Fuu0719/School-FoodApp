# Windows 會員服務部署

## 目前範圍

會員註冊、登入、登出、個人資料與飲食偏好已使用 MySQL。
商品和推薦清單仍是模擬資料；App 的收藏、購物車和購買紀錄仍存於裝置，已按伺服器和會員分開保存，不會跨帳號顯示。
舊版不分會員的本機紀錄不會自動移轉到任何新帳號，原資料不刪除。
App 雲端模式已串接會員活動及獨立商家商品管理；尚未實作正式驗證的回饋原型寫入仍回應 501。
既有主機更新商家管理前，務必先依 [商家部署](MERCHANT_MANAGEMENT.md) 備份及套用 003，不能只更新程式後重啟。
更新刪除門市功能前另需套用 `database/migrations/004_store_deletion.sql`。此遷移只新增 `stores.deleted_at`，不清除資料，可重跑；若以最新版 schema 初始化則已包含此欄位。既有主機勿重匯 schema 或重跑 003。

## 學校伺服器更新

全部指令在遠端桌面執行。先在執行 API 的 PowerShell 按 Ctrl+C 停止服務。

```powershell
cd C:\School\my_app
git status
git pull --ff-only
cd backend
npm.cmd ci
```

如果 git 顯示專案檔案有未提交修改，先確認內容，不覆蓋修改；backend/.env 是忽略檔，不受 pull 影響。

用新 MySQL 服務的 root 登入（使用 3307）：

```powershell
& "C:\Program Files\MySQL\MySQL Server 26.7\bin\mysql.exe" --protocol=TCP -h 127.0.0.1 -P 3307 -u root -p
```

在 mysql> 執行：

```sql
SELECT @@port, @@datadir;
SOURCE C:/School/my_app/backend/database/migrations/001_user_sessions.sql;
USE shan_jie_ren_yi;
SHOW TABLES;
EXIT;
```

確認連接的是新資料目錄、3307。原本 14 張資料表會增加為 15 張，不要重新匯入 schema.sql。
第一次全新部署的環境才先匯入 schema.sql，再匯入 migration。
原本 food_app 的 SELECT、INSERT、UPDATE、DELETE 資料庫權限也適用於新增的 user_sessions。

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
npm.cmd start
```

db:check 檢查實際資料庫和登入紀錄表。test:mysql 會建立隨機測試會員，實際驗證註冊、登入、改偏好、另一個 API 實例讀取、登出撤銷與再次登入，再刪除該測試會員。
一般 npm test 使用替代 repository 驗證 HTTP 行為，不代表雲端 MySQL 驗證完成。
test:mysql 中的另一個 API 實例測試不等於已驗證 Windows 重新開機後的常駐服務。

## App 連線

VS Code 選 Flutter Member API (Debug)，選已啟動的 Android 裝置，按 F5，輸入包含 /api 的 API 網址。
這個啟動設定使用本機工作目錄程式，不會因未提交的修改中止；需自行 pull 已核對的新版。

同一台開發電腦的 Android 模擬器連本機 API 使用 http://10.0.2.2:3000/api。
這個位址不會指向學校雲端伺服器。

學校伺服器目前綁定 127.0.0.1，只能在該伺服器內測試。
從專研筆電或手機連線前，需另外完成 HTTPS 反向代理、學校網路路由及允許 API 連線的規則。
後端的 3307 不需要對外開放。真實密碼和憑證不應經由公開 HTTP 傳輸。
若使用受控 VPN 做 HTTP 開發測試，須先依學校允許的範圍設定 API 監聽與防火牆；Debug 支援 HTTP，正式發佈使用 HTTPS。

命令列也可指定網址：

```powershell
flutter run --dart-define=API_BASE_URL=https://YOUR_API_HOST/api
```

新增安全儲存外掛後需停止 App 再完整編譯，Hot Reload 無法載入新原生外掛。
Windows 桌面外掛的符號連結錯誤需在開發電腦處理；與伺服器 MySQL 無關。

## 手動驗收

1. 用新 Email 註冊，密碼 12 至 128 字元；兩次密碼不一致應阻止送出。
2. 用相同 Email 再註冊，應顯示已註冊；錯誤密碼不應登入。
3. 正確登入應返回首頁。編輯姓名、電話、身高、體重、健康目標、偏好及不限預算/距離，儲存成功後推薦使用新偏好。
4. 關閉重開 App，應向伺服器重新驗證憑證並取得最新會員資料；離線時不以舊資料自動登入。
5. 登出後登入另一個帳號，不應看到前一人的收藏、購物車或購買紀錄；切回原帳號可讀取該裝置內原紀錄。
6. 儲存時斷網，應顯示錯誤且不宣告成功；恢復連線後可重試。
7. 停止並重啟 API 後再次登入，會員資料與偏好仍存在。

## 待部署項目

學校防火牆申請與 HTTPS 尚未完成，不能宣稱外部 App 已連線。請持續追蹤 [部署狀態](../docs/deployment_status.md)。
會員活動已在學校驗收 002；App 雲端模式已串接。新商家後端另需 003，步驟見 [商家部署](MERCHANT_MANAGEMENT.md)。

已提供 [Windows 常駐服務工具](windows-service/README.md)，需在學校伺服器安裝並驗證開機啟動。
HTTPS、定期異機備份與還原驗證仍待完成；Email 驗證、忘記密碼仍未實作。商家正式帳號由管理者本機建立，需先完成商家部署。
目前登入憑證有效七天，資料庫只存 SHA-256 摘要；每次請求查驗效期，登出即撤銷該憑證。
App 安全儲存憑證，不保存會員密碼。密碼使用 Node.js scrypt 加上隨機 salt。
