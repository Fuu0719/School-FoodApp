# 膳解人意 Flutter App

## 手機測試更新（2026-09-26）

- 新會員身高／體重以 NULL 保存，不補展示值；首次登入後開啟會員資料編輯，填寫並儲存後才返回原流程。舊帳號已有數值不自動清除。
- 新版商家註冊只建立商家帳號；登入後從「新增門市」建立門市，可建立多間。既有門市保留，舊版註冊 API 仍相容隨註冊建立首間門市。
- 門市開始／結束時間使用 24 小時制滾輪，API 驗證 HH:mm；結束早於開始顯示翌日，相同時間拒絕。商家可從「門市管理」編輯名稱、地址、電話、營業日與營業時間。
- 商家後台「門市管理」可刪除門市及全部商品，包含草稿；刪除前需確認。已刪除門市不可新增商品、重新上架或接受新訂單，既有訂單與商品快照保留。不影響其他門市或商家帳號。
- 會員電話、商家聯絡電話與門市電話維持選填；有填時必須符合台灣手機、含區碼市話或 `+886` 格式，前後端會共同驗證並標準化後儲存。
- 商家新增／編輯商品時可用分類旁的加號建立自訂分類。分類儲存於商品，後續會從該商家所有未刪除門市的商品載入，不會顯示其他商家的分類。
- 本次需先以資料庫管理者執行 `backend/database/migrations/004_store_deletion.sql`，新增門市刪除標記；不要重新匯入 schema.sql。前後端須一起更新並重新啟動 API；學校尚未部署此更新。全新 schema 已包含此欄位。
- 刪除門市採邏輯刪除，以保留訂單的商品參照；不是清空資料庫。門市及其所有商品從商家管理、公開目錄、收藏與瀏覽清單排除，App 不提供復原。管理者清空測試資料是獨立操作，必須先備份及確認範圍。
- Android 打包須讓 flutter pub get 成功完成以產生原生外掛註冊類別，不要在初始化失敗後直接用 --no-pub 發布。手機實機啟動驗收不可只用編譯成功替代。
- 新註冊會員與商家密碼限制為 8–16 字元；既有較長密碼仍可登入，避免舊帳號被鎖住。商品必填數字欄預設為空白，不顯示 0，未輸入時不可儲存。
- 會員註冊成功後會直接登入並開啟首次資料編輯，必須填寫身高與體重；儲存後回首頁，之後一般編輯不會強制跳頁。
- 會員不索取手機定位權限，距離固定以「銘傳大學桃園校區，桃園市龜山區德明路 5 號」為起點。新增或編輯門市時會將地址轉為座標，存入與校園的直線距離。
- 首頁「今日推薦」會立即納入已上架且符合會員預算／距離的商品；完整推薦頁仍依當天營業日篩選。
- 即期商品的新建與編輯期限限制在未來 24 小時內。會員首頁顯示姓名、身高與體重；推薦頁移除重複偏好權重。
- 商品目錄會在 App 回到前景、商家上下架、結帳後立即更新，前景使用期間每 30 秒同步一次。這是近即時輪詢，不是 WebSocket；網路中斷時保留上次成功資料。
- 搜尋商家名稱會列出該商家所有門市商品，不再把門市名稱當商家名稱。收藏與瀏覽紀錄可搜尋，購物車支援向左滑動刪除。
- 結帳後售罄商品從公開首頁移除，但目前工作階段內的收藏與瀏覽快照仍保留並顯示庫存 0、禁止再次購買。排行榜改為資料庫全體會員前三名，另列登入者本人及級距排名。
- 餐點詳情的推薦原因由資料庫內容顯示；舊商品若未填寫，API 會依即期狀態、營養、熱量、距離及分類產生可讀理由，不再顯示空白。
- 結帳成功會先顯示約 1.8 秒的煙火過場、商品數量及總金額，再自動返回首頁。
- 預算及距離設為「不限」時不會套用數值上限；搜尋頁無條件搜尋會列出所有仍上架、有庫存且未過期的商品。推薦頁另外排除目前未營業門市；會員有設定偏好標籤時，餐點必須至少符合其中一項，標籤同時參與排序。首頁則是推薦預覽，優先讓每個商家各顯示一項，最多五項。

「膳解人意」以個人化餐飲推薦與即期食品減廢為目標，已具備 Flutter、Node.js API 與 MySQL 持久化。2026-10-07 已將目前版本、004 migration 與筆電測試資料搬至學校伺服器；手機透過 ngrok HTTPS 連到學校 API 與 MySQL，不再依賴開發筆電常駐。

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
- 商家可新增、編輯多間門市，刪除門市及其全部商品，並建立自訂食物分類
- 會員、商家與門市電話的選填格式驗證
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
測試順序：商家登入頁 → 註冊商家帳號 → 登入 → 新增門市 → 建立草稿 → 上架 → 一般會員註冊／登入 → 收藏、瀏覽、模擬下單 → 重新登入確認紀錄。
刪除驗收：使用專門的測試門市及商品，商家後台 → 門市管理 → 垃圾桶 → 確認刪除。重新載入會員目錄後該門市商品應消失；舊購物車不可送出新訂單，但先前成功訂單仍可讀取。
商家自行註冊不需審核。會員與商家分別使用 users、merchants 及獨立 session，同一 Email 可分別註冊，但權限不共用。
雲端目錄空白表示沒有符合條件的上架餐點，不會自動匯入展示餐點；營業日、期限及庫存也會影響下單。

### 最終測試資料（筆電 MySQL）

2026-09-28 已重建筆電測試資料：5 個會員、15 個一般商家及 2 個連鎖品牌帳號，共 42 間門市、630 項上架商品。一般商家各有 1–3 間門市，每間門市 15 項商品；便當、飯糰、麵食、沙拉、麵包甜點及飲品平均輪替。商品名稱包含門市與品項序號，資料庫查核為 630 個名稱全部唯一。低脂、蔬食、高蛋白、清爽、均衡及低熱量標籤採不同涵蓋比例，切換偏好時會改變推薦候選集合與數量。31 間一般測試門市使用桃園、龜山周邊的街路門牌格式，不再顯示虛構的「測試地址」。一般門市含 3 間跨夜營業測試門市，營業狀態會同時檢查星期、目前時間及跨夜延續規則；雲端模式在非營業時間不能加入或增加購物車商品，後端結帳也會再次拒絕。

7-ELEVEN 與全家門市座標取自 OpenStreetMap。種子程式會優先擷取桃園銘傳大學 5 公里圓形範圍；2026-09-28 重建時公開地圖 API 回覆流量限制，因此本次資料庫使用 11 間已核對的鄰近門市快照（7-ELEVEN 6 間、全家 5 間，距離 210–1,371 公尺），不能視為 5 公里內完整門市名錄。每間門市有 15 項模擬即期商品；真實的是門市名稱與座標，商品不是連鎖品牌官方資料。

會員密碼統一為 `Member123!`：

- `member01@foodapp.test`
- `member02@foodapp.test`
- `member03@foodapp.test`
- `member04@foodapp.test`
- `member05@foodapp.test`

商家密碼統一為 `Store123!`：

- `merchant01@foodapp.test` 至 `merchant15@foodapp.test`（15 個一般商家）
- `seven-eleven@foodapp.test`（7-ELEVEN）
- `familymart@foodapp.test`（全家便利商店）

`npm.cmd run db:seed:final` 會刪除資料庫內全部會員、商家、門市、商品及其關聯資料，只能在確認備份且確定要重建測試環境時執行。建立程序使用資料庫交易，任一寫入失敗會整批回復。

7-ELEVEN 與全家商品帶有 `每日即期測試` 標籤。筆電 `backend/.env` 設定 `TEST_DATA_AUTO_REFRESH=true` 後，API 啟動時及每小時檢查一次，只將「已過期且仍上架」的這批測試商品更新為未來 4–23 小時內，庫存為 0 時補回測試庫存。因此週一至週日都有固定便利商店即期品可測，不必每天進商家後台修改。此設定不得用於正式商家資料；正式環境及 `.env.example` 預設為 `false`，一般商品過期後仍會正常下架並禁止結帳。

注意：`npm start` 才會讓 `http://localhost:3000` 持續可連線；`npm test` 只是執行測試，測完就會關閉。

### 本機開發測試啟動

以下只供需要改用筆電資料庫進行本機開發時使用。正常手機驗收已改連學校伺服器，不需在筆電開啟 API 或 ngrok。

PowerShell 視窗 1（API）：

```powershell
cd C:\Users\kjzs5\.codex\worktrees\44cc\my_app\backend
npm.cmd run db:check
npm.cmd start
```

PowerShell 視窗 2（HTTPS 通道）：

```powershell
ngrok http 3000
```

啟動後依序檢查 `http://127.0.0.1:3000/api/health` 與 ngrok 顯示的 `https://.../api/health`。兩者都回應 `status: ok` 才開啟 App。目前 APK 內建的測試網址是 `https://estimator-flagman-fidgeting.ngrok-free.dev/api`；若 ngrok 免費網址改變，必須用新網址重新打包 APK。

一般重開機不需要重跑 `npm ci`、資料庫遷移或 Flutter 打包。只有更新程式或依賴時才需要 `npm ci`；只有新版明確新增遷移時才能在備份後套用。不可重匯 `schema.sql`，也不要對現有資料庫重跑 001–004。

本機測試時筆電需保持開機、聯網且不進入睡眠；關閉 API 或 ngrok 任一視窗，本機入口就會中斷。請勿讓筆電與學校伺服器同時占用相同 ngrok 固定網址。

## 學校伺服器現況與用途

以下是 2026-10-07 的部署驗收紀錄，不是即時監控。

| 項目 | 最後已知狀態 |
| --- | --- |
| 主機 | 120.125.83.17，Windows Server 2016 x64，遠端桌面管理 |
| 專案 | C:\School\my_app；已部署目前 GitHub `main` 版本 |
| API | SchoolFoodAppApi，Running／Auto／LocalService，127.0.0.1:3000 |
| 專案 MySQL | 3307、shan_jie_ren_yi、food_app 應用帳號 |
| 原有服務 | AppServ MySQL 3306、Apache 80，與專案分開，勿任意變更 |
| 遷移 | 001–004 已套用；`db:check` 通過 |
| 資料 | 筆電完整測試資料已匯入學校 MySQL；匯入前已建立學校端備份 |
| HTTPS | ngrok Windows 服務，固定網址 `https://estimator-flagman-fidgeting.ngrok-free.dev` |
| 開機驗收 | MySQLFoodApp、SchoolFoodAppApi、ngrok 均為 Running／Automatic；整台主機重開後公開健康檢查通過 |
| 測試 | 學校 MySQL 整合測試 24 項全數通過；公開 `/api/health` 回傳 `ok` |

目前已提供集中保存會員、偏好、收藏、瀏覽、模擬訂單、商家與餐點的基礎，也已在真實 MySQL 驗證帳號隔離、交易及庫存處理。
API 以 Windows 服務執行，不必一直開著 npm start 視窗；本次已完成整台主機重開驗證，但 Windows 服務不會自動更新程式或手機安裝包。

### 使用學校資料測試

APK `1.0.0+16` 已設定 `https://estimator-flagman-fidgeting.ngrok-free.dev/api`。ngrok 與 API 都在學校主機以 Windows 服務執行；Node 只監聽 127.0.0.1:3000，MySQL 只使用本機 3307，兩者都不直接公開。ngrok 免費入口的瀏覽器警告不影響 App，API client 會送出 `ngrok-skip-browser-warning` 標頭。

## 待完成與部署順序

1. 完成手機行動網路下的會員、商家、上下架與結帳最終驗收。
2. 建立定期異機備份並實際演練還原；目前僅確認匯出與跨主機匯入成功。
3. 後續更新依部署文件停止服務、備份、`git pull --ff-only`、`npm ci`、測試及重新啟動；不要重跑既有 migration。
4. 學校借用期限依提供資料為 2026-12-31，需提前備份或申請續借。

金流、商家接單、Email 驗證、忘記密碼及圖片檔案上傳未完成；模擬訂單不代表已付款或已接單。購物車、搜尋紀錄及評分回饋仍為本機資料。後端 /api/recommendations 暫回應 501，不能宣稱完整雲端 AI 推薦引擎已完成。
部分模擬器啟動設定會先更新 Git，但遇到未提交修改會停止；雲端啟動設定沒有掛同一更新作業，不能保證每次重開就是最新版。

## 驗證與文件

2026-09-29 最終驗收：Flutter 完整測試 117 通過／2 跳過，`flutter analyze` 無問題；後端單元測試 50 通過／3 整合測試跳過，真實 MySQL 測試 24 項全數通過，`npm audit --omit=dev` 為 0 個漏洞。資料庫已驗證 5 個會員、17 個商家、42 間門市、630 項商品及 3 間跨夜門市，沒有重複帳號、重複商品名稱、孤兒關聯、負數營養／庫存、無效座標或缺少營業日。Samsung Android 16 實機已驗證會員與商家登入、推薦收合、搜尋商家、詳情、收藏、瀏覽、購物車左滑刪除、結帳扣庫存、點餐紀錄與 Android 返回導覽；商家端已驗證門市清單／編輯、24 小時制營業時間、商品清單與新增表單。APK `1.0.0+16` 使用相同 ngrok 測試 API；推薦收合列會顯示目前偏好，商家商品真正過期時會明確顯示「已過期」。

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
