# 部署進度與未解決事項

更新日期：2026-10-27。

## 版本與環境

| 項目 | GitHub 最新版 | 學校端最後已驗證狀態 |
| --- | --- | --- |
| App | `1.0.0+36`、`MealMind-latest.apk` | 網站已提供最新版 APK；App 連接正式 API |
| Database | schema 與 migration `001–011` | `001–011` 已套用 |
| API | Node.js／Express、`127.0.0.1:3000` | `SchoolFoodAppApi` Windows 服務 |
| MySQL | `shan_jie_ren_yi`、`127.0.0.1:3307` | `MySQLFoodApp` Windows 服務 |
| 網域 | `mealmind-app.online` 與 `api.mealmind-app.online` | Cloudflare Named Tunnel、網站與 API 已部署 |
| 郵件 | Resend、`MealMind <noreply@mealmind-app.online>` | 網域與寄件金鑰已設定 |
| 付款 | 綠界 Stage、付款金額與 MerchantID 驗證 | 僅測試付款，不是正式收款 |

以上為 2026-10-27 完成的部署紀錄，不是即時監控。GitHub 更新、伺服器拉取、migration、服務重啟、APK 發布與實機驗收仍是不同步驟；後續更新不得只依版本庫推定已部署。

## GitHub 最新版已完成

- App `1.0.0+36`，修正登入、購物車導向、帳號切換 session 與付款後同步。
- 訂單建立後保留庫存；未付款逾期訂單會取消並只恢復一次庫存。
- migration `011` 記錄付款到期與釋放時間，並保存會員／商家切換 session 的來源。
- 專題網站、APK 下載、隱私權政策、服務條款與管理員入口。
- 管理後台的會員、商家、餐點、訂單、期間報表、搜尋、分頁與 CSV 匯出。
- 管理員 scrypt 密碼雜湊、短效 HttpOnly Cookie、登入限流、CSP、限制 CORS 與安全標頭。
- 綠界回呼檢查 MerchantID、簽章、訂單金額與嚴格數值格式。

## 本次已完成的部署驗收

1. 學校伺服器已更新專案、安裝後端依賴並啟動 API。
2. MySQL 已套用 migration `001–011`；既有 migration 不得重跑。
3. `MySQLFoodApp`、`SchoolFoodAppApi` 與 `cloudflared` 均以 Windows 服務自動啟動。
4. 公開網站、固定 API、APK 下載與 `/api/health` 已完成部署驗證。
5. App `1.0.0+36` 已設定使用 `https://api.mealmind-app.online/api`。

App 是安裝在 Android 裝置並連線到學校 API；伺服器部署的是網站、API、MySQL 與 APK 下載檔。部署完成不等同即時監控，展示前仍要重新檢查服務、網站與健康端點。

## 仍屬限制或未完成

- 後端 `/api/recommendations` 仍回應 501，推薦排序在 Flutter App 執行。
- 便利商店商品、價格、庫存與即期時間是展示資料，不是官方即時資料。
- 綠界仍為 Stage；尚無正式收款、退款、對帳與真實商家接單流程。
- App 購物車、搜尋紀錄與推薦星級回饋仍保存在裝置端。
- Android applicationId 仍為 `com.example.my_app`，release 仍使用 debug signing，不能直接上架商店。
- 管理員 session 保存在單一 Node.js 程序記憶體，API 重啟後需重新登入。
- 尚未完成定期異機備份與還原演練、正式負載測試及第三方滲透測試。
- 學校主機借用期限依現有資料為 2026-12-31，需提前續借或完成搬移。

完整操作見 [Windows 部署](../backend/DEPLOY_WINDOWS.md)、[網站部署](../backend/WEBSITE_DEPLOY.md)、[資料庫操作](../backend/DATABASE_OPERATIONS.md)與[雲端驗收](cloud_activity_verification.md)。
