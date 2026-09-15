# 膳解人意 Backend

會員、商品目錄、會員活動與商家管理 API 使用 MySQL；推薦 API 尚未完成。商家可自行註冊，不需審核，註冊時建立第一間門市。
初始化或升級請依部署文件核對結構；學校已套用 001、002、003，勿重匯 schema 或重跑遷移。本次自行註冊沒有新增遷移。

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
| POST | /api/auth/register | name、email、password；成功後請登入 |
| POST | /api/auth/login | email、password；回傳 token、expiresAt、user |
| POST | /api/auth/logout | 撤銷目前登入憑證 |
| GET | /api/me | 取得自己的會員資料 |
| PUT | /api/me | 儲存自己的資料與偏好 |

除註冊登入外，會員端點需 Authorization: Bearer <token>。
Email 會轉為小寫；註冊密碼至少 12、最多 128 字元。
PUT /api/me 接受完整的 name、phone、heightCm、weightKg、healthGoal、dietaryTags、budgetMax、distanceLimitMeters。
healthGoal 為 maintain、muscleGain 或 fatLoss；預算和距離可為 null（不限）。
不接受透過 body 的 id 指定其他會員，Email 修改尚未開放。

401 表示未登入或憑證失效；409 表示 Email 重複；400 為表單驗證失敗；429 為登入/註冊嘗試過多。
憑證七天到期，登出後即失效。會員資料和偏好一起提交或一起回復。
健康數值在註冊時暫用 170 公分、65 公斤，會員可在個人資料編輯；並非健康評估結果。

## 原型端點

GET /api/health 回應 API 運作狀態，不代表其他資料功能已完成。
GET /api/foods、/api/foods/:foodId、/api/stores/:storeId 已讀 MySQL，GET /api/recommendations 暫回應 501；詳見 [商品目錄](CATALOG.md)。
MySQL 收藏、瀏覽與模擬訂單端點已提供，詳見 [會員活動 API 與遷移](MEMBER_ACTIVITY.md)。
商家帳號與商品管理已新增獨立驗證及 MySQL 寫入，需先套用 003，見 [商家管理與部署](MERCHANT_MANAGEMENT.md)。
其他尚未實作正式驗證的原型寫入與回饋端點仍回應 501；僅舊原型測試顯式開啟。
App 預設保留展示商品；Flutter Cloud Catalog (Debug) 可改讀 MySQL 目錄。會員及偏好已串 API；收藏、瀏覽與購物車仍在本機，雲端模式暫不接受下單。
學校防火牆與 HTTPS 尚未完成，外部 App 連線未驗證，狀態追蹤見 [部署進度](../docs/deployment_status.md)。

## 實作參考

- [Node.js crypto](https://nodejs.org/api/crypto.html)：scrypt 密碼雜湊及隨機憑證。
- [Flutter Secure Storage](https://pub.dev/packages/flutter_secure_storage)：裝置端安全儲存。
