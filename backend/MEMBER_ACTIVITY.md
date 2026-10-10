# 會員活動 API

## 範圍

此階段完成後端的收藏、瀏覽及模擬訂單 MySQL 儲存。App 的展示模式仍使用本機商品 ID；雲端目錄模式登入後使用資料庫 ID 讀寫會員活動 API。
正式端點只接受資料庫 foods.id 的十進位字串，不接受 food-001 等模擬 ID，也不接受客戶端自行建立餐點或指定會員。
公開 /api/foods 已改讀 MySQL，可用其 ID 呼叫這些端點，見 [商品目錄](CATALOG.md)。

所有以下端點皆需 Authorization: Bearer <token>。過期或撤銷的 token 回傳 401。

| Method | 路徑 | 資料與行為 |
| --- | --- | --- |
| GET | /api/me/favorites | 回傳 items；每頁 50 筆，依 foodId 降冪，可用 before=nextCursor 翻頁 |
| PUT | /api/me/favorites/:foodId | 加入收藏；重複呼叫不會增加筆數 |
| DELETE | /api/me/favorites/:foodId | 移除自己的收藏；重複呼叫仍成功 |
| GET | /api/me/history | 最近 20 個餐點，最新瀏覽在前 |
| POST | /api/me/history | body: {"foodId":"1"}；同餐點移到最前，超過 20 筆移除最舊紀錄 |
| DELETE | /api/me/history | 清除自己的瀏覽紀錄 |
| GET | /api/me/orders | 每頁 20 筆，依訂單 id 降冪；可用 before=nextCursor 翻頁 |
| GET | /api/me/orders/:orderId | 訂單與餐點快照；他人的訂單與不存在訂單都回傳 404 |
| POST | /api/me/orders | 建立訂單，需 Idempotency-Key 標頭；啟用綠界時回傳付款網址 |

下單 body 範例：

```json
{"items":[{"foodId":"1","quantity":2}]}
```

每張訂單最多 50 種不同餐點，每種 1 至 99 份。同一餐點不可拆成重複項目。
Idempotency-Key 為小寫 UUID；同一次下單及其網路重試必須使用相同值。
同一會員、相同識別碼與品項回傳原訂單（200），首次成功為 201；同碼不同品項為 409。
會員間識別碼各自獨立。客戶端傳來的價格、總額、會員 ID 不作為計算或權限依據。

伺服器檢查店家與餐點啟用狀態、台灣當日營業星期、保存期限和庫存。
business_hours 目前為顯示文字，尚未解析成店家的分時營業規則。
價格、數量、節省金額與積分由後端計算，並於同一交易寫入訂單、明細與扣庫存。
庫存為零時標記 sold_out。失敗不留下部分訂單，也不扣除部分庫存。
既有訂單的餐點名稱、營養與價格快照不隨未來商品修改而變動；遷移前舊訂單快照為 null。
訂單建立後初始 `paymentStatus` 為 `pending`。綠界 Stage 驗證成功後更新為 `paid` 並寄出會員訂單確認信；未啟用綠界的測試環境會直接完成為 `paid`。目前仍未串接商家接單狀態，App 會明確標示為模擬訂單。

## App 雲端活動

以 CLOUD_CATALOG=true 及已核准、可連線的 API_BASE_URL 啟動。登入憑證放在安全儲存區，會員活動使用 Bearer token；401 會清除失效登入。
收藏與瀏覽寫入成功才更新畫面，失敗顯示訊息；讀取失敗保留目前已載入資料。切換帳號後，舊請求結果不會寫入新帳號畫面。
收藏與紀錄頁提供重新同步及清除瀏覽；訂單初次載入 20 筆，可載入較早訂單。這是主動重新載入，不是背景即時同步。
收藏與瀏覽目前僅顯示仍存在於已載入可售目錄的餐點；下架餐點紀錄仍保留在資料庫，但不以展示餐點替代。
訂單使用下單當時的價格、營養與名稱快照，不依目前目錄重算。舊訂單沒有快照時標示「無舊版快照」，缺少的營養資料以零值相容舊模型，不代表實測為零。
會員惜食統計僅彙整已載入的模擬訂單，不代表全部歷史訂單或真實交易。

送單前以安全亂數 UUID 建立 Idempotency-Key，連同 foodId／quantity 保存於該 API 與帳號的本機範圍。沒有保存成功就不送出。
等待確認期間鎖住購物車；逾時、5xx 或回應異常保留相同識別碼與品項。重開 App 後按「確認上次訂單」，即使餐點已不在目錄，也能重送原請求以取得原訂單。
明確的庫存或欄位驗證拒絕可解除鎖定；同碼不同品項的衝突仍保留待確認狀態。收到成功訂單後才清除購物車與識別碼。
待確認紀錄損壞時停止下單，需管理者查核；不要刪除 App 資料或手動清掉識別碼來重試，否則會失去防重送依據。
購物車、搜尋紀錄、評分回饋仍在本機；展示模式的收藏與訂單不會自動上傳。
App 會在內部付款頁開啟綠界 Stage，成功後重新同步訂單並顯示「模擬訂單，已付款」。此功能沒有正式收款、退款、對帳或商家接單流程。

## 本次更新

已完成 001、002 且 db:check 通過的學校伺服器，本次只更新程式與測試，不需新遷移，也不要重跑以下初次安裝 SQL。
後端訂單明細額外回傳既有 original_unit_price 與 eco_points 欄位，沒有修改資料庫結構。
操作步驟及待驗收項目見 [雲端活動驗證](../docs/cloud_activity_verification.md)。

## 初次安裝會員活動後端

此步驟可在防火牆及 HTTPS 尚未完成時，於遠端桌面內進行。
先安排短暫維護並備份 shan_jie_ren_yi；資料庫備份須保存在專案外，不提交 Git。

以系統管理員 PowerShell 執行：

```powershell
cd C:\School\my_app\backend
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\api_service.ps1 -Action Stop
cd ..
git status --short --branch
git pull --ff-only
cd backend
npm.cmd ci
```

若 git 有衝突、備份或安裝失敗，先停止後續步驟，不強制清除本機修改。
在連到 **3307、獨立 MySQLFoodApp** 的管理員 MySQL 視窗執行一次：

```sql
SOURCE C:/School/my_app/backend/database/migrations/002_member_activity.sql;
```

此遷移只新增欄位及索引，不清除舊資料；不能重複執行。若部分失敗，先查核已套用欄位，勿直接重跑。
既有伺服器不要重新匯入 schema.sql，也不需要重新執行已完成的 001 遷移。
新資料庫直接使用更新後的 schema.sql，再套用 001；不要額外套用 002。

返回 PowerShell：

```powershell
npm.cmd run db:check
npm.cmd test
npm.cmd run test:mysql
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\api_service.ps1 -Action Start
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\api_service.ps1 -Action Status
```

上述每一步成功後才進下一步。新版本啟動會檢查 002 的必要欄位與索引，未完成時拒絕啟動。
若遷移失敗，不要持續重啟服務，請先查看錯誤並保留備份。

test:mysql 會新增隨機測試會員、店家和餐點，測試兩個會員隔離、服務重建後讀取、交易回滾、同碼重試及搶最後一份庫存。
正常結束會刪除該次測試資料，不會清空既有資料；若測試程序被強制終止，可能留下標示為測試用途的資料。
測試時不會呼叫付款服務。測試需 SELECT、INSERT、UPDATE、DELETE 權限，不需給 App 資料庫帳號 ALTER 權限。

## 未完成事項

學校伺服器已透過 ngrok HTTPS 提供手機測試。綠界目前僅為 Stage 測試付款；正式商店資料、正式網域、退款、對帳與商家接單狀態仍未完成，見 [部署狀態](../docs/deployment_status.md)。
