# App 雲端活動驗證

## 本機驗證紀錄

2026-09-10：flutter analyze 無問題；flutter test 87 項通過、1 項僅雲端模式測試跳過。
指定 CLOUD_CATALOG=true 執行 cloud_catalog_mode_test.dart 及 cloud_activity_test.dart，14 項全數通過。
後端 npm test 28 項通過、2 項真實 MySQL 測試跳過；其中 3 項屬工作目錄原有、未納入本次提交的 VPN 測試。
Android debug APK 可編譯；此編譯檢查未指定正式 API_BASE_URL，不是可直接交付使用者連到學校的正式安裝包。
以上不能取代學校 MySQL、重開機或真機網路驗收。

## 學校伺服器更新

注意：以下是已完成的 d7156d8 活動更新步驟。最新版新增商家管理，未套用 003 的主機須改依 [商家部署](../backend/MERCHANT_MANAGEMENT.md) 備份、遷移，再啟動。

防火牆與 HTTPS 尚未完成，但可先在學校遠端桌面內更新服務。不要在專研筆電誤操作同名路徑。
先確認已有專案外的資料庫備份，安排短暫維護。使用管理員 PowerShell，每一步成功才繼續。

先檢查工作目錄：

```powershell
cd C:\School\my_app
git status --short --branch
```

有修改時先保留並查核，不使用 reset 或覆寫。確認乾淨後：

```powershell
cd backend
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\api_service.ps1 -Action Stop
cd ..
git pull --ff-only
cd backend
npm.cmd ci
npm.cmd run db:check
npm.cmd test
npm.cmd run test:mysql
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\api_service.ps1 -Action Start
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\api_service.ps1 -Action Status
```

若任何一步失敗，停止後續步驟並保留錯誤。服務此時可能仍停止，不能宣告部署成功。
db:check 應確認 3307 與 food_app；test:mysql 不應跳過真實 MySQL 測試；Status 應顯示 Running、Auto、127.0.0.1:3000 及 API healthy。
本次無新遷移，不執行 schema.sql、001 或 002。不要更動 AppServ 的 3306 或 Apache。
整合測試會建立自己的臨時餐點再移除，因此 /api/foods 回傳空 items 仍可能正常。

## App 驗收前提

先完成學校核准的 HTTPS 入口，再以 Flutter Cloud Catalog (Debug) 指向該 API 網址。
API_BASE_URL 必須含 /api；不能把伺服器的 127.0.0.1 當作手機能用的網址。
需有授權建立的測試商品及兩個測試會員，不把 mock 商品或真實個資直接灌進資料庫。
商家帳號與正式上架流程仍待開發。此處是驗收清單，不代表已在手機執行。

## 手動驗收

1. A 登入後收藏、瀏覽餐點；重新啟動 App 並登入同帳號，重新同步後仍可讀取。
2. 在另一裝置登入 A，手動同步後比對紀錄；切換 B 不應看見 A 的收藏或訂單。
3. 下單期間按鈕停用；只有 API 建立訂單成功才進入綠界 Stage 付款。付款成功後清空購物車，購買紀錄顯示「模擬訂單，已付款」。
4. 模擬回應遺失後重開 App，使用「確認上次訂單」；檢查資料庫只產生一張訂單且只扣一次庫存。
5. 測試售完、過期、庫存不足，確認沒有部分訂單或錯誤的成功提示。
6. 修改商品售價後重新讀取舊訂單，仍顯示原快照價格；較早訂單可分頁讀取。
7. 撤銷 session 後操作，App 提示登入失效並清除本機登入；不能讀取其他會員資料。
8. 安排伺服器重開機後檢查 MySQLFoodApp 與 SchoolFoodAppApi 自動啟動。僅 Restart 服務不算此項通過。

完成以上項目才更新部署狀態。這些訂單沒有金流，不代表付款、商家接單或真實減廢成果。
