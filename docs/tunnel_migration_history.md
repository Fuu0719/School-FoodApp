# HTTPS 通道遷移紀錄

更新日期：2026-10-15。

這份文件只保留歷史與停用依據；其中網址不得再用於 App 建置、付款回呼或現行部署。

| 階段 | 入口 | 結果 | 狀態 |
| --- | --- | --- | --- |
| ngrok | `https://estimator-flagman-fidgeting.ngrok-free.dev` | 曾作為測試入口，後因帳戶月流量上限停止服務 | 已停用 |
| Cloudflare Quick Tunnel | `https://nation-rebates-eye-campus.trycloudflare.com` | 臨時驗證 Cloudflare 連線；程序重啟會更換網址 | 已停用 |
| Cloudflare Named Tunnel | `https://api.mealmind-app.online` | 自有網域、Windows 服務自動啟動、固定公開入口 | 現行唯一入口 |

現行 App API 位址為 `https://api.mealmind-app.online/api`；綠界 `PUBLIC_BASE_URL` 為 `https://api.mealmind-app.online`。Node API 仍只監聽 `127.0.0.1:3000`，MySQL 仍只使用 `127.0.0.1:3307`。

## 學校伺服器停用確認

先確認 Named Tunnel 正常，再停用舊服務與程序：

```powershell
Invoke-RestMethod "https://api.mealmind-app.online/api/health"
Get-Service cloudflared, SchoolFoodAppApi

Get-Service *ngrok* -ErrorAction SilentlyContinue |
  Stop-Service -Force
Get-Service *ngrok* -ErrorAction SilentlyContinue |
  Set-Service -StartupType Disabled

$quickTunnels = Get-CimInstance Win32_Process -Filter "Name='cloudflared.exe'" |
  Where-Object { $_.CommandLine -match 'tunnel\s+--url' }
$quickTunnels | Select-Object ProcessId, CommandLine
$quickTunnels | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
```

不可停止命令列包含 `tunnel run --token-file` 的 `cloudflared`，那是現行 Named Tunnel Windows 服務。最後確認只剩正式服務：

```powershell
Get-CimInstance Win32_Process -Filter "Name='cloudflared.exe'" |
  Select-Object ProcessId, CommandLine
Get-Service cloudflared
Invoke-RestMethod "https://api.mealmind-app.online/api/health"
```
