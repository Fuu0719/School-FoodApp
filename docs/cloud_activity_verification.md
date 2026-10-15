# App 雲端與實機驗收

更新日期：2026-10-15。

本文件是目前版本的驗收清單。歷史測試數量僅代表當次執行結果；GitHub 原始碼、學校部署、APK 建置及手機安裝必須分別確認。

## 已知測試基準

- App 原始碼版本：`1.0.0+32`。
- `flutter analyze`：0 issues。
- Flutter tests：123 passed、2 skipped。
- Node.js tests：59 passed、3 skipped；跳過項目為需要真實 MySQL 的整合測試。
- 學校伺服器 `npm.cmd run test:mysql`：27 passed、0 failed、0 skipped。
- 固定公開 API：`https://api.mealmind-app.online/api`。
- 學校 MySQL migration：`001` 至 `010` 已完成，不得重跑。

測試通過不能取代實機操作；Skipped 也不能寫成通過。

## 學校伺服器更新前檢查

使用系統管理員 PowerShell。先建立專案外的資料庫備份並確認檔案大小大於 0，再檢查工作目錄：

```powershell
cd C:\School\my_app
git status --short --branch
git log -1 --oneline
```

若有未知修改，先查明來源，不使用 `git reset --hard` 或 `git checkout --` 覆蓋。只有新版明確包含新 migration 時才執行資料庫升級；一般程式或文件更新不可重匯 `schema.sql`。

```powershell
cd C:\School\my_app\backend
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\api_service.ps1 -Action Stop

cd C:\School\my_app
git pull --ff-only origin main

cd C:\School\my_app\backend
npm.cmd ci
npm.cmd run db:check
npm.cmd test
npm.cmd run test:mysql

powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\api_service.ps1 -Action Start
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\api_service.ps1 -Action Status
```

任一步失敗就停止後續部署。`db:check` 應確認資料庫 `shan_jie_ren_yi`、port 3307 與應用帳號；`test:mysql` 不應跳過；服務狀態須為 Running、Automatic、`127.0.0.1:3000` 且 API healthy。

## 服務與公開入口驗收

```powershell
Get-Service MySQLFoodApp, SchoolFoodAppApi, cloudflared

Invoke-RestMethod "http://127.0.0.1:3000/api/health"
Invoke-RestMethod "https://api.mealmind-app.online/api/health"

Resolve-DnsName api.mealmind-app.online
```

三個服務都應為 Running，兩個 health request 都應回應 `status: ok`。`cloudflared` 應執行 Named Tunnel，不可另開 Quick Tunnel。Node.js 與 MySQL 只監聽本機，不對外開放 3000 或 3307。

## App 實機驗收

1. 新 Email 註冊時，驗證前 `users` 不應出現正式會員；錯誤或不存在的信箱不會因送出表單就建立會員。
2. 正確驗證碼建立會員、登入並收到歡迎信；寄件者顯示 `MealMind <noreply@mealmind-app.online>`，不可顯示 Gmail 或中文亂碼名稱。
3. 不選頭像可儲存會員資料；上傳、顯示與移除 JPG／PNG 頭像後皆正常，編輯完成不返回驗證頁。
4. 收藏、瀏覽與購買紀錄在重開 App 或另一裝置登入後仍存在；另一會員不可讀取。
5. 搜尋關鍵字、六類圖片與首頁「小確幸」皆有候選結果；過期、售罄、未上架或已刪除門市商品不可購買。
6. 五個底部分頁在目前分頁重複點擊可回頂端。
7. 新會員可立即查看全體排行榜；刪除會員後排行榜不顯示殘留姓名或頭像。
8. 綠界 Stage 在 App 內完成付款；成功後訂單顯示「模擬訂單，已付款」，重送或重新確認不得重複扣庫存。
9. 商家可新增及編輯門市、建立商品、上下架、刪除未上架商品、修改資料與密碼。
10. 綁定會員與商家後可雙向切換；切換會撤銷來源 session，登出後不得利用另一身分快速繞過登入。
11. 付款成功寄送會員訂單信；`.test` 模擬商家不寄信，也不產生 Gmail 退信。
12. 手機使用 Wi-Fi 與行動網路各完成一次公開 API 連線，確認不依賴校內網路或電腦上的臨時通道。

## 資料庫抽查

進入 MySQL：

```powershell
$mysql = "C:\Program Files\MySQL\MySQL Server 26.7\bin\mysql.exe"
& $mysql `
  --protocol=TCP `
  --host=127.0.0.1 `
  --port=3307 `
  --user=root `
  --password `
  --database=shan_jie_ren_yi
```

只讀抽查：

```sql
SELECT DATABASE(), NOW();
SELECT COUNT(*) AS members FROM users;
SELECT COUNT(*) AS merchants FROM merchants;
SELECT id, name, email, email_verified_at, created_at FROM users ORDER BY id;
SELECT id, business_name, email, status, created_at FROM merchants ORDER BY id;
SELECT id, user_id, status, payment_status, total_amount, created_at
FROM purchase_orders ORDER BY id DESC LIMIT 20;
```

刪除測試會員或重建資料前，依 [資料庫操作手冊](../backend/DATABASE_OPERATIONS.md) 先查關聯筆數、備份並使用 transaction；不可直接把正式帳號混在批次刪除條件中。

## 不可宣稱

- 綠界 Stage 不是正式收款。
- 模擬商品與分類圖片不是真實便利商店即時庫存或逐筆實拍照。
- 後端 `/api/recommendations` 尚未完成；推薦排序目前在 App 端執行。
- 現有測試證明規則與流程依設計運作，不等於已完成大量使用者研究、負載測試或滲透測試。
- APK 編譯成功不等於已完成所有 Android 裝置與 iOS 驗收。
