# MealMind website deployment

The website and API are served by the same Node.js service. No database migration is required.

Required production environment variables:

```dotenv
PUBLIC_BASE_URL=https://api.mealmind-app.online
ADMIN_ACCESS_TOKEN=replace-with-at-least-32-random-characters
APP_APK_PATH=C:\School\my_app\MealMind-latest.apk
```

Generate the admin token once in PowerShell and store it in the backend `.env` file:

```powershell
$bytes = New-Object byte[] 32
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
try {
  $rng.GetBytes($bytes)
} finally {
  $rng.Dispose()
}
$adminToken = -join ($bytes | ForEach-Object { $_.ToString('x2') })
$adminToken
```

Cloudflare Tunnel public hostnames:

- `api.mealmind-app.online` -> `http://127.0.0.1:3000`
- `mealmind-app.online` -> `http://127.0.0.1:3000`
- `www.mealmind-app.online` -> redirect to `https://mealmind-app.online`

After pulling a release, run `npm.cmd ci`, test, restart `SchoolFoodAppApi`, and verify `/`, `/api/health`, and `/api/admin/dashboard`.
