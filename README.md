# 膳解人意 Flutter App

「膳解人意」以個人化餐飲推薦與即期食品減廢為目標，已具備 Flutter、Node.js API 與 MySQL 持久化。學校已有後端部署；最新版商家自行註冊、外部 App 連線及實機驗收仍待完成。

## 目前已完成

- 首頁推薦與即期優惠
- 餐點詳情頁
- 搜尋與篩選
- 食物轉盤
- 收藏與瀏覽紀錄
- 一般會員真實註冊、登入、登出、個人資料與偏好保存
- 雲端收藏、瀏覽及模擬訂單，依會員隔離
- 下單使用資料庫價格、交易、庫存鎖定與識別碼防重複送單
- 商家獨立註冊／登入、第一間門市、草稿新增／編輯／上架／下架
- 未登入功能導向登入頁
- 推薦、搜尋、轉盤、會員服務測試

## 測試 App：展示模式

在專案根目錄執行。先啟動 Android Studio Device Manager 的模擬器，或從 flutter emulators 列表選擇 ID，以 flutter emulators --launch <emulator-id> 啟動。

```powershell
flutter pub get
flutter emulators
flutter devices
flutter analyze
flutter test
flutter run -d <device-id>
```

將 <device-id> 換成 flutter devices 顯示的實際 ID。2026-09-15 檢查時未連接 Android 裝置，須先啟動模擬器或連接手機。
預設使用約 100 項展示餐點與本機活動；真實會員登入仍需可用 API。畫面有餐點不代表學校資料庫已匯入餐點，也不能以展示模式驗收雲端保存。
若 pub get 提示 Windows 插件需 symlink，先處理本機開發環境；這不是資料庫錯誤。

## 測試 App：本機真實資料

在同一筆電準備獨立測試 MySQL，依部署文件建立結構，再依 backend/.env.example 設定 backend/.env。不要提交密碼或在正式資料上隨意測試。逐步執行，成功才繼續：

```powershell
cd backend
npm.cmd ci
npm.cmd run db:check
npm.cmd run test:mysql
npm.cmd start
```

保持後端視窗開啟，另開 PowerShell 回專案根目錄，標準 Android 模擬器可使用：

```powershell
flutter run -d <device-id> --dart-define=CLOUD_CATALOG=true --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

10.0.2.2 是模擬器連回同一筆電的位址，**不是學校伺服器**，也不能套用到實體手機。HTTP 範例僅供本機開發。
亦可選 VS Code 的 Flutter Cloud Catalog (Debug)，輸入含 /api 的可達 API_BASE_URL。
測試順序：商家登入頁 → 註冊商家帳號 → 登入 → 建立草稿 → 上架 → 一般會員註冊／登入 → 收藏、瀏覽、模擬下單 → 重新登入確認紀錄。
商家自行註冊不需審核。會員與商家分別使用 users、merchants 及獨立 session，同一 Email 可分別註冊，但權限不共用。
雲端目錄空白表示沒有符合條件的上架餐點，不會自動匯入展示餐點；營業日、期限及庫存也會影響下單。

注意：`npm start` 才會讓 `http://localhost:3000` 持續可連線；`npm test` 只是執行測試，測完就會關閉。

## 學校伺服器現況與用途

以下是最後驗收紀錄，不是即時監控。本次自行註冊功能尚未部署學校。

| 項目 | 最後已知狀態 |
| --- | --- |
| 主機 | 120.125.83.17，Windows Server 2016 x64，遠端桌面管理 |
| 專案 | C:\School\my_app；最後驗收版本 529e0b1 |
| API | SchoolFoodAppApi，Running／Auto／LocalService，127.0.0.1:3000 |
| 專案 MySQL | 3307、shan_jie_ren_yi、food_app 應用帳號 |
| 原有服務 | AppServ MySQL 3306、Apache 80，與專案分開，勿任意變更 |
| 遷移 | 001、002、003 已驗收；自行註冊無新增遷移，勿重匯 schema |
| 遠端測試 | 一般測試 31 通過／3 跳過，真實 MySQL 整合 15 項通過 |

目前已提供集中保存會員、偏好、收藏、瀏覽、模擬訂單、商家與餐點的基礎，也已在真實 MySQL 驗證帳號隔離、交易及庫存處理。
API 以 Windows 服務執行，不必一直開著 npm start 視窗；服務 Auto 不代表整台主機重開後已驗證，更不表示會自動更新程式或手機安裝包。

### 使用學校資料測試的前提

先將本次版本提交、合併／推送至部署分支並更新學校後端，再完成學校核准的防火牆、HTTPS 憑證與反向代理，將 App API_BASE_URL 設為實際 HTTPS API（含 /api）。
目前 API 僅監聽 127.0.0.1；能開遠端桌面不表示手機能呼叫 API，不能直接填公開 IP 就視為連線完成。勿公開 MySQL 3307 或 Node 3000，也不要透過公開 HTTP 傳送密碼。
網路完成前，可以在學校遠端桌面驗證 API／資料庫，但不能宣稱跨裝置 App 同步已完成。工作目錄的 VPN 測試工具也不代表已開通，執行前仍須核對校方許可。

## 待完成與部署順序

1. 提交、審查並推送本次版本；本機 commit 不等於學校已更新。
2. 依部署文件備份、停止服務、更新程式／依賴，逐步執行 db:check、test、test:mysql；通過後啟動並檢查服務。不重跑既有遷移。
3. 完成外部 HTTPS 連線，建立第一個永久商家及餐點，實測 App 註冊、上架、下單與跨裝置同步。
4. 驗證整台主機重開、異機備份及實際還原。學校借用期限依提供資料為 2026-12-31，提前備份或申請續借。

金流、商家接單、Email 驗證、忘記密碼及圖片檔案上傳未完成；模擬訂單不代表已付款或已接單。購物車、搜尋紀錄及評分回饋仍為本機資料。後端 /api/recommendations 暫回應 501，不能宣稱完整雲端 AI 推薦引擎已完成。
部分模擬器啟動設定會先更新 Git，但遇到未提交修改會停止；雲端啟動設定沒有掛同一更新作業，不能保證每次重開就是最新版。

## 驗證與文件

2026-09-15 本機驗證：Flutter 完整測試 99 通過／2 跳過，雲端指定測試 26 通過，flutter analyze 無問題。後端工作目錄測試 37 通過／3 真實 MySQL 跳過，其中 3 項通過屬於未納入商家提交的 VPN 工作。新增自行註冊 SQL 仍待學校真實 MySQL 驗證。

- [部署進度與未解決事項](docs/deployment_status.md)
- [Windows 部署說明](backend/DEPLOY_WINDOWS.md)
- [商家註冊與商品管理](backend/MERCHANT_MANAGEMENT.md)
- [商品目錄](backend/CATALOG.md)
- [會員活動](backend/MEMBER_ACTIVITY.md)
- [雲端活動驗收](docs/cloud_activity_verification.md)

- API 規劃：[docs/backend_api_plan.md](docs/backend_api_plan.md)
- MySQL schema：[backend/database/schema.sql](backend/database/schema.sql)
- 本機 API 原型：[backend/README.md](backend/README.md)

開發完成、提交、推送、學校部署與 App 安裝是不同步驟，請以部署紀錄分別驗收。
