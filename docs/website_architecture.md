# 網站架構與功能

更新日期：2026-10-27。

## 定位

MealMind 網站與 REST API 由同一個 Node.js／Express 程序提供。公開網站是專題介紹、功能摘要、法律文件與 Android APK 下載入口；會員註冊、餐點瀏覽、購物車及商家工作台目前以 Flutter App 為正式操作介面，不應把版本庫中保留的舊網頁原型描述成已開放功能。

## 目前公開路由

| 路徑 | 用途 | 存取方式 |
| --- | --- | --- |
| `/` | 專題首頁、核心功能、流程、專題介紹與 App 下載 | 公開 |
| `/download/android` | 下載 `MealMind-latest.apk` 或 `APP_APK_PATH` 指定檔案 | 公開 |
| `/privacy.html` | 隱私權政策 | 公開 |
| `/terms.html` | 服務條款 | 公開 |
| `/login.html` | 管理員登入 | 公開頁面；登入受限流保護 |
| `/admin.html` | 營運主控板 | 頁面可載入，資料 API 需要有效管理員 session |
| `/api/*` | App、網站管理後台與外部付款回呼共用 API | 依端點驗證 |

`/cart.html` 與舊 `/index.html` 目前會轉回首頁。舊 `app.js`、`cart.js` 及相關原型檔仍在版本庫，但不是現行公開會員／商家網站，不可列入完成成果。

## 管理後台

管理員帳密由伺服器 `.env` 的 `ADMIN_EMAIL` 與 `ADMIN_PASSWORD_HASH` 設定。密碼以 scrypt 雜湊保存，不在 Git、網頁或資料庫保留明文。登入成功後使用 2 小時有效的隨機 session，瀏覽器只取得 `HttpOnly`、`Secure`、`SameSite=Strict` Cookie。

後台提供：

- 日、週、月營運摘要。
- 會員、商家、餐點與訂單分頁查詢。
- 關鍵字、日期範圍及頁數篩選。
- 商家啟用／暫停；暫停時撤銷該商家所有 session。
- CSV 匯出；儲存格會處理公式注入風險。

管理員 session 目前保存在 Node.js 程序記憶體，API 重啟後必須重新登入；這是安全且可接受的專題設計，但不適合多台後端水平擴充。

## 安全與資料流

- 網站與 API 同源，瀏覽器 CORS 只允許 `mealmind-app.online` 與 `www.mealmind-app.online`；Android 原生請求沒有瀏覽器 Origin。
- 全站設定 CSP、HSTS、禁止 iframe、`nosniff`、Referrer Policy 及關閉相機／麥克風／定位權限。
- 管理頁與登入頁使用 `Cache-Control: no-store`。
- Node.js 與 MySQL 僅監聽伺服器本機；Cloudflare Named Tunnel 對外提供 HTTPS。
- 公開網站沒有直接資料庫連線，所有資料均經過 Express API 與 repository 的參數化查詢。

## 原始碼位置

- 頁面與樣式：`backend/public/site/`
- 路由與安全標頭：`backend/src/app.js`
- 管理 API：`backend/src/admin/routes.js`
- 管理查詢：`backend/src/admin/repository.js`
- 部署說明：`backend/WEBSITE_DEPLOY.md`

## 驗收

部署後至少檢查首頁、APK 下載、隱私權、條款、管理員錯誤登入限流、正確登入、四類資料查詢、期間切換、CSV 匯出、登出及 API 重啟後 session 失效。網站可用不代表 App、付款、郵件或 MySQL migration 已完成驗收，必須分項記錄。
