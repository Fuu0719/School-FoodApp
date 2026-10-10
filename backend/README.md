# 膳解人意 Backend

會員、商品目錄、會員活動與商家管理 API 使用 MySQL；推薦 API 尚未完成。商家可自行註冊並直接啟用，登入後再新增一間或多間門市。舊版客戶端在註冊時附帶首間門市的格式仍相容。
初始化或升級請依部署文件核對結構，勿重匯 schema。既有環境依序套用 migration；本版另需套用 `008_member_custom_avatar.sql`，將預設圖示改為會員自訂圖片。通過 db:check 才啟動新版 API。

部署、驗收與 App 連線步驟見 [Windows 部署說明](DEPLOY_WINDOWS.md)。

## 啟動

設定 .env（範本 .env.example），在 backend 目錄執行：

```powershell
npm.cmd ci
npm.cmd run db:check
npm.cmd test
npm.cmd run test:mysql
npm.cmd start
```

db:check 及 test:mysql 使用真實資料庫；一般測試不依賴資料庫。
test:mysql 會建立並清除隨機測試會員。API 啟動前檢查資料庫及登入紀錄表。
預設只監聽 127.0.0.1。npm start 需保持執行，npm test 結束後不會啟動服務。

## 會員 API

| Method | 路徑 | 用途 |
| --- | --- | --- |
| POST | /api/auth/register | name、email、password；寄出 Email 驗證碼 |
| POST | /api/auth/verify-email | 驗證 Email 並簽發登入憑證 |
| POST | /api/auth/resend-verification | 重新寄送 Email 驗證碼 |
| POST | /api/auth/forgot-password | 寄送重設密碼驗證碼 |
| POST | /api/auth/reset-password | 驗證後更新密碼並撤銷舊憑證 |
| POST | /api/auth/login | email、password；回傳 token、expiresAt、user |
| POST | /api/auth/logout | 撤銷目前登入憑證 |
| GET | /api/me | 取得自己的會員資料 |
| PUT | /api/me | 儲存自己的資料與偏好 |

除註冊登入外，會員端點需 Authorization: Bearer <token>。
Email 會轉為小寫；新註冊密碼為 8–16 字元，既有較長密碼仍可登入。新會員完成 6 位數 Email 驗證後才簽發 session，接著立即完成首次個人資料。驗證碼 10 分鐘失效，最多嘗試 5 次。
PUT /api/me 接受完整的 name、phone、avatarKey、heightCm、weightKg、healthGoal、dietaryTags、budgetMax、distanceLimitMeters。phone 可留空；有值時接受台灣手機、含區碼市話或 `+886`，儲存前移除空白、括號與連字號。
healthGoal 為 maintain、muscleGain 或 fatLoss；預算和距離可為 null（不限）。
不接受透過 body 的 id 指定其他會員，Email 修改尚未開放。

SMTP 由 `.env` 的 `SMTP_HOST`、`SMTP_PORT`、`SMTP_SECURE`、`SMTP_USER`、`SMTP_PASSWORD`、`SMTP_FROM` 設定；Gmail 必須使用應用程式密碼，禁止提交實際密碼。Email 驗證完成後會寄歡迎信；綠界確認付款成功後才寄會員與商家訂單通知。

綠界由 `PUBLIC_BASE_URL`、`ECPAY_MERCHANT_ID`、`ECPAY_HASH_KEY`、`ECPAY_HASH_IV`、`ECPAY_GATEWAY_URL` 設定。測試環境使用綠界 Stage URL；正式上線必須換成正式商店資料及正式 Gateway。HashKey、HashIV 只存後端 `.env`。`PUBLIC_BASE_URL` 必須是綠界可連入的 HTTPS 網址，付款成立只採信 `/api/payments/ecpay/return` 的 CheckMacValue 驗證結果。

401 表示未登入或憑證失效；403 表示 Email 尚未驗證；409 表示 Email 重複；400 為表單驗證失敗；429 為登入/註冊嘗試過多。
憑證七天到期，登出後即失效。會員資料和偏好一起提交或一起回復。
新會員的身高與體重儲存為 NULL；首次登入 App 會導向會員資料編輯，不使用預設健康數值。

## 原型端點

GET /api/health 回應 API 運作狀態，不代表其他資料功能已完成。
GET /api/foods、/api/foods/:foodId、/api/stores/:storeId 已讀 MySQL，GET /api/recommendations 暫回應 501；詳見 [商品目錄](CATALOG.md)。
MySQL 收藏、瀏覽與訂單端點已提供，詳見 [會員活動 API 與遷移](MEMBER_ACTIVITY.md)。
商家帳號與商品管理使用獨立驗證及 MySQL 寫入，需套用 003；刪除門市功能另需 004，見 [商家管理與部署](MERCHANT_MANAGEMENT.md) 與 [門市刪除](STORE_DELETION.md)。商品分類是不跨商家的自訂文字，會從該商家現有商品彙整選項。
其他尚未實作正式驗證的原型寫入與回饋端點仍回應 501；僅舊原型測試顯式開啟。
App 預設保留展示商品；Cloud Catalog 版改讀 MySQL 目錄、雲端收藏、瀏覽及模擬訂單。購物車、搜尋紀錄與評分回饋仍有本機狀態；模擬訂單不代表已付款或商家已接單。
學校防火牆與 HTTPS 尚未完成；手機測試暫時使用筆電 API 及 ngrok HTTPS，狀態追蹤見 [部署進度](../docs/deployment_status.md)。

## Windows 唯讀資料庫檢視器

學校伺服器不需安裝 Workbench。更新專案後，直接雙擊 `backend\開啟資料庫檢視器.cmd`，即可用圖形介面選擇資料表、搜尋、排序、翻頁與複製欄位。檢視器會讀取 `backend\.env` 的 MySQL 連線設定，每頁顯示 300 筆，且不提供新增、修改或刪除功能。

## 實作參考

- [Node.js crypto](https://nodejs.org/api/crypto.html)：scrypt 密碼雜湊及隨機憑證。
- [Flutter Secure Storage](https://pub.dev/packages/flutter_secure_storage)：裝置端安全儲存。
