# 現行後端 API 與資料流

更新日期：2026-10-15。

本文件原為早期 API 規劃稿，現已依實際程式更新。正式測試環境不是純前端 mock：Flutter App 透過 `https://api.mealmind-app.online/api` 呼叫部署在學校 Windows Server 的 Node.js REST API，會員、商家、商品與活動資料保存於 MySQL。展示模式及分類共用圖片仍保留給離線畫面測試。

## 系統邊界

```text
Flutter Android App
  -> HTTPS / JSON / Bearer token
Cloudflare DNS + TLS + Named Tunnel
  -> 127.0.0.1:3000
Node.js + Express API
  -> mysql2 prepared statements / transactions
MySQL 127.0.0.1:3307

Node.js API -> Resend SMTP：驗證信、歡迎信、重設密碼與訂單信
Node.js API -> 綠界 Stage：模擬付款頁、回傳與結果通知
```

Node.js 與 MySQL 不直接開放至 Internet。Cloudflare Tunnel 是唯一公開入口；舊 ngrok 與 Quick Tunnel 已停用。

## 實作狀態

### 已完成

- 會員待驗證註冊、Email 驗證、登入、登出及兩階段忘記密碼。
- 會員資料、偏好、自訂頭像、收藏、瀏覽、訂單與排行榜。
- 商家註冊、登入、資料與密碼修改、多門市、商品草稿、上下架及刪除。
- 會員與商家一對一綁定及雙向身分切換；切換時撤銷來源 session。
- 公開商品與門市目錄、庫存與期限檢查。
- 綠界 Stage App 內付款、訂單冪等、交易鎖定與付款後 Email。

### 尚未完成或僅供測試

- `GET /api/recommendations` 固定回應 HTTP 501；推薦篩選、五項加權評分與排序目前在 Flutter App 端執行。
- 綠界為 Stage 測試金流，沒有正式收款、退款與對帳流程。
- 商家與餐點以模擬資料為主；分類圖片不是每項商品的實拍照。
- 購物車、搜尋紀錄與推薦星級回饋目前仍保存在裝置端。
- 舊的無 MySQL 原型路由只供測試注入，不是正式伺服器執行路徑。

## 正式 API

所有路徑以下列 Base URL 為基準：

```text
https://api.mealmind-app.online/api
```

### 系統與公開目錄

| Method | Path | 用途 |
| --- | --- | --- |
| GET | `/health` | API 健康檢查 |
| GET | `/foods` | 取得可公開商品，支援搜尋與篩選 |
| GET | `/foods/:id` | 取得商品詳情 |
| GET | `/stores/:id` | 取得門市資料 |
| GET | `/recommendations` | 尚未完成，回應 501 |

### 會員驗證與資料

| Method | Path | 用途 |
| --- | --- | --- |
| POST | `/auth/register` | 建立 10 分鐘待驗證註冊，不建立正式會員 |
| POST | `/auth/verify-email` | 驗證成功後建立會員並簽發 session |
| POST | `/auth/resend-verification` | 重新寄送驗證碼 |
| POST | `/auth/forgot-password` | 寄送密碼重設碼 |
| POST | `/auth/verify-reset-code` | 驗證重設碼並簽發一次性 reset token |
| POST | `/auth/reset-password` | 修改密碼並撤銷既有 session |
| POST | `/auth/login` | 會員登入 |
| POST | `/auth/logout` | 撤銷目前會員 session |
| GET | `/me` | 取得目前會員、偏好及綁定狀態 |
| PUT | `/me` | 更新會員資料、偏好與頭像 |

### 會員活動與付款

| Method | Path | 用途 |
| --- | --- | --- |
| GET | `/me/leaderboard` | 全體惜食排行榜及本人排名 |
| GET | `/me/favorites` | 取得收藏清單 |
| PUT/DELETE | `/me/favorites/:foodId` | 新增或刪除收藏 |
| GET/POST/DELETE | `/me/history` | 查詢、新增或清除瀏覽紀錄 |
| GET | `/me/orders` | 分頁取得訂單 |
| GET | `/me/orders/:orderId` | 取得自己的訂單詳情 |
| POST | `/me/orders` | 以交易及冪等鍵建立待付款訂單 |
| GET | `/payments/ecpay/:token` | 開啟綠界 Stage 付款頁 |
| POST | `/payments/ecpay/return` | 接收付款頁回傳並導回 App |
| POST | `/payments/ecpay/result` | 驗證付款結果並更新訂單 |

### 會員與商家連結

| Method | Path | 用途 |
| --- | --- | --- |
| POST | `/me/merchant-link` | 驗證並綁定一個商家帳號 |
| DELETE | `/me/merchant-link` | 解除綁定 |
| POST | `/me/switch-to-merchant` | 撤銷會員 session，簽發商家 session |
| POST | `/merchant/me/member-link` | 從商家端綁定會員 |
| DELETE | `/merchant/me/member-link` | 從商家端解除綁定 |
| POST | `/merchant/me/switch-to-member` | 撤銷商家 session，簽發會員 session |

### 商家管理

| Method | Path | 用途 |
| --- | --- | --- |
| POST | `/merchant/auth/register` | 建立商家帳號 |
| POST | `/merchant/auth/login` | 商家登入 |
| POST | `/merchant/auth/logout` | 商家登出 |
| GET/PUT | `/merchant/me` | 取得商家、所屬門市與綁定狀態，或更新商家資料 |
| POST | `/merchant/me/change-password` | 修改商家密碼並撤銷其他 session |
| POST | `/merchant/stores` | 建立門市 |
| PUT/DELETE | `/merchant/stores/:id` | 更新或邏輯刪除自有門市 |
| GET | `/merchant/categories` | 取得商家自己的商品分類 |
| GET/POST | `/merchant/products` | 取得或建立商品草稿 |
| GET/PUT/DELETE | `/merchant/products/:id` | 取得、更新或刪除未上架商品 |
| PUT | `/merchant/products/:id/status` | 上架或下架商品 |

商家路由實際掛載在 `/api/merchant`，表格中的路徑已包含該前綴。

## 驗證、資料一致性與安全控制

- 會員與商家使用獨立 session 表及 Bearer token；資料庫只保存 token 雜湊。
- 密碼以隨機 salt 與 scrypt 雜湊，登入比對使用 constant-time comparison。
- SQL 使用 `mysql2` 參數化查詢；多表寫入使用 transaction，庫存結帳使用 row lock。
- 註冊、登入、驗證碼及密碼重設套用 rate limit、有效期限與錯誤次數限制。
- 所有會員活動依登入 session 的會員 ID 查詢，不接受前端指定其他會員 ID。
- 商家寫入依 session 所屬商家與門市驗證 ownership，並以 revision 防止過期編輯覆蓋。
- 建立訂單使用 `Idempotency-Key`，避免網路重送造成重複扣庫存或重複訂單。
- App token 使用 `flutter_secure_storage`；一般顯示與偏好狀態可使用 `shared_preferences`。

## Flutter 資料來源

- 雲端模式：`MemberApi`、`CatalogApi`、會員活動及商家服務呼叫正式 API。
- 展示模式：`MockFoodRepository` 提供離線展示商品，不代表學校資料庫內容。
- 推薦：商品與會員偏好由雲端取得，星級與標籤回饋目前保存在裝置端；`RecommendationService` 在 App 端完成候選排除、加權評分、排序與理由顯示。
- 網路請求使用 JSON、15 秒逾時及明確錯誤處理；401 會清除失效登入狀態。

部署與驗收請依 [Windows 部署說明](../backend/DEPLOY_WINDOWS.md)；資料表與操作請依 [資料庫操作手冊](../backend/DATABASE_OPERATIONS.md)。
