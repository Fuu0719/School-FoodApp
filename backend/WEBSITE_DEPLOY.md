# MealMind 網站與管理後台部署

更新日期：2026-10-27。

網站、管理後台與 API 由同一個 `SchoolFoodAppApi` Node.js 服務提供，不需另裝 IIS、Apache 或前端建置工具。最新版後端同時需要 migration `011_order_reservations_and_linked_sessions.sql`；學校資料庫若仍停在 `010`，須先備份並依 [Windows 部署說明](DEPLOY_WINDOWS.md) 套用一次。

## 環境設定

在學校伺服器的 `C:\School\my_app\backend\.env` 設定：

```dotenv
PUBLIC_BASE_URL=https://api.mealmind-app.online
ADMIN_EMAIL=admin@mealmind-app.online
ADMIN_PASSWORD_HASH=scrypt-v1$產生的雜湊
APP_APK_PATH=C:\School\my_app\MealMind-latest.apk
```

產生管理員密碼與雜湊：

```powershell
cd C:\School\my_app\backend
npm.cmd run admin:hash-password -- --generate
```

將工具顯示的 `ADMIN_PASSWORD` 立即存入密碼管理器，只把 `ADMIN_PASSWORD_HASH` 寫入 `.env`。明文密碼不得寫入 `.env`、Git、文件、截圖或對話。

## Cloudflare 路由

- `api.mealmind-app.online` → `http://127.0.0.1:3000`
- `mealmind-app.online` → `http://127.0.0.1:3000`
- `www.mealmind-app.online` → 重新導向 `https://mealmind-app.online`

網站與 API 共用程序，但用途不同：主網域提供專題網站；`api` 子網域提供 App API 與付款回呼。MySQL 3307 與 Node 3000 都不得直接公開。

## 更新與驗收

完成資料庫備份與必要 migration 後，在管理員 PowerShell 執行：

```powershell
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

接著驗證：

```powershell
Invoke-WebRequest https://mealmind-app.online/ -UseBasicParsing
Invoke-WebRequest https://mealmind-app.online/login.html -UseBasicParsing
Invoke-WebRequest https://mealmind-app.online/privacy.html -UseBasicParsing
Invoke-WebRequest https://mealmind-app.online/terms.html -UseBasicParsing
Invoke-RestMethod https://api.mealmind-app.online/api/health
```

再以瀏覽器驗證管理員登入、期間統計、會員／商家／餐點／訂單查詢、CSV 匯出、商家狀態切換與登出。完整網站定位與安全邊界見 [網站架構與功能](../docs/website_architecture.md)。
