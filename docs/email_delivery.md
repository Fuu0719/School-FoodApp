# 網域交易郵件設定

更新日期：2026-10-15。

正式寄件者為 `MealMind 膳解人意 <noreply@mealmind-app.online>`。網址不能直接當 Email 寄件者；`From` 必須是信箱格式。`https://mealmind-app.online` 會顯示在信件內容，API 與付款回呼使用 `https://api.mealmind-app.online`。

## 1. 驗證寄件網域

1. 建立 Resend 帳號並啟用多因素驗證。
2. 在 Resend Domains 新增 `mealmind-app.online`。
3. 將 Resend 畫面提供的 SPF、DKIM 等紀錄逐筆加入 Cloudflare 的 `mealmind-app.online` DNS。
4. DNS 的名稱、類型與內容必須完全照 Resend 顯示；郵件驗證紀錄使用 DNS only。
5. 等 Resend 顯示網域可寄信後，建立只允許寄信的 API Key。金鑰只保存一次，不放入 Git 或截圖。

Cloudflare Tunnel 的 `api` CNAME 與郵件 DNS 紀錄用途不同，不可刪除或互相覆蓋。

## 2. 更新學校伺服器

先在專案外備份 `.env`：

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
Copy-Item C:\School\my_app\backend\.env `
  "C:\School\FoodAppBackups\backend-env-$stamp.txt"
```

使用記事本修改，避免在 PowerShell 歷史直接留下 API Key：

```powershell
notepad C:\School\my_app\backend\.env
```

設定：

```dotenv
SMTP_HOST=smtp.resend.com
SMTP_PORT=465
SMTP_SECURE=true
SMTP_USER=resend
SMTP_PASSWORD=Resend寄信API金鑰
SMTP_FROM="MealMind 膳解人意 <noreply@mealmind-app.online>"
SMTP_ALLOWED_FROM_DOMAIN=mealmind-app.online
APP_PUBLIC_URL=https://mealmind-app.online
PUBLIC_BASE_URL=https://api.mealmind-app.online
```

不得保留舊 Gmail SMTP Host、Gmail 帳號或 Google 應用程式密碼。備份檔包含秘密，只能保存在受控的伺服器管理目錄，不可提交 Git。

## 3. 部署與驗收

```powershell
cd C:\School\my_app
git pull --ff-only origin main

cd C:\School\my_app\backend
npm.cmd ci
npm.cmd test
npm.cmd run db:check
npm.cmd run test:mysql

powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\api_service.ps1 -Action Restart

powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\api_service.ps1 -Action Status

Invoke-RestMethod "https://api.mealmind-app.online/api/health"
```

最後以專用測試信箱完成一次註冊驗證、重設密碼與模擬付款，確認 Gmail 收件畫面的寄件者是 `noreply@mealmind-app.online`，並在 Resend Logs 確認 Delivered。測試完成後依資料庫操作手冊刪除測試會員。

若寄信失敗，不要把 `SMTP_FROM` 改回 Gmail。先檢查 Resend 網域驗證、API Key 權限、Cloudflare DNS 與學校防火牆的外連 465/TCP。
