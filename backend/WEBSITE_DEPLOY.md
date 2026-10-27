# MealMind website deployment

The website and API are served by the same Node.js service. No database migration is required.

Required production environment variables:

```dotenv
PUBLIC_BASE_URL=https://api.mealmind-app.online
ADMIN_EMAIL=admin@mealmind-app.online
ADMIN_PASSWORD_HASH=scrypt-v1$generated-value
APP_APK_PATH=C:\School\my_app\MealMind-latest.apk
```

Generate a password hash on the school server and store only the hash in `.env`:

```powershell
cd C:\School\my_app\backend
npm.cmd run admin:hash-password -- --generate
```

Save the generated `ADMIN_PASSWORD` in a password manager, then discard it from the terminal. Put only
`ADMIN_PASSWORD_HASH` in `.env`. Never save the plain-text password in `.env`, source control, screenshots, or chat.

Cloudflare Tunnel public hostnames:

- `api.mealmind-app.online` -> `http://127.0.0.1:3000`
- `mealmind-app.online` -> `http://127.0.0.1:3000`
- `www.mealmind-app.online` -> redirect to `https://mealmind-app.online`

After pulling a release, run `npm.cmd ci`, test, restart `SchoolFoodAppApi`, and verify `/`, `/login.html`, and `/api/health`.
