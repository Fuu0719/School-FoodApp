# MySQL 商品目錄

## 後端行為

服務環境的 GET /api/foods、GET /api/foods/:id、GET /api/stores/:id 已改讀 MySQL。
不自動匯入原本 100 項模擬餐點。資料庫沒有商品時，回傳空 items，這不是連線失敗。
餐點 ID 與門市 ID 以十進位字串回傳，直接對應會員收藏、瀏覽及訂單 API。

商品目錄只顯示 active 商家的 active 餐點，且庫存大於零、尚未過期。
不回傳草稿、暫停、售完商品，也不回傳商家密碼、登入資料等內部欄位。
單一門市查詢會回傳已啟用商家的門市資訊，即使目前沒有可售商品。

GET /api/foods 支援以下查詢條件：

| 參數 | 用途 |
| --- | --- |
| after | 上一頁 nextCursor；依餐點 ID 遞增，每頁最多 50 項 |
| keyword | 餐點或店家名稱關鍵字；% 與 _ 按文字搜尋，不當萬用字元 |
| category | 完全符合的分類 |
| tags | 逗號分隔，最多 20 個標籤，符合任一個即可 |
| storeId | 指定資料庫門市 ID |
| brand | 指定 stores.brand；超商頁目前辨識 7-11 與全家 |
| maxPrice | 價格上限，非負整數，最高 1000000 |
| maxDistanceMeters | 距離上限，非負整數，最高 1000000；未知距離不納入 |
| expiringOnly | true / false，只看即期品 |
| openToday | true / false，依台灣當日星期篩選營業門市 |

回傳 {items: [...], nextCursor: "50"}；最後一頁 nextCursor 為 null。不提供不設上限的單次全量回應。
數值營養欄位與圖片網址均來自資料庫；food_tags 對應 tags，nutritionTags 暫為空陣列，不憑空產生營養宣稱。
距離仍使用 stores.distance_meters 的模擬校園基準，沒有新增 GPS 定位或實際步行路線計算。
未知距離回傳 null；App 顯示「距離未提供」，不將它誤當 0 公尺。
商家尚未有照片時保留現有圖片替代圖示，不使用其他商品照片冒充。

GET /api/recommendations 現在回傳 501，避免混入模擬商品 ID；App 的推薦與轉盤仍用既有前端規則，但資料來源改為同一份雲端目錄。
沒有加入雲端推薦模型或新評分權重。

## App 啟動模式

原有啟動模式預設保留展示商品，以便在網路尚未開通時維持展示。
新增 VS Code 的 Flutter Cloud Catalog (Debug)，輸入可連線的 API_BASE_URL（含 /api）。
等價指令：

```powershell
flutter run --dart-define=CLOUD_CATALOG=true --dart-define=API_BASE_URL=https://YOUR_API_HOST/api
```

YOUR_API_HOST 是待配置的主機名，不是已存在的學校網址。
10.0.2.2 只代表 Android 模擬器所在電腦的本機，不會自動連到學校伺服器。
學校防火牆與 HTTPS 尚未完成，不能因為新增啟動模式就宣稱手機已能連線。

雲端模式啟動時以分頁載入完整目錄，最多 1000 項；超過上限會顯示錯誤，不以截斷資料冒充完整目錄。
載入後首頁、搜尋、推薦、轉盤、會員偏好標籤與超商即期頁共用該目錄。餐點價格、營養、標籤與照片皆由同一資料來源提供。
首頁右上方可重新載入商品；更新失敗時保留舊快照並顯示提示，不會換回模擬商品。這不是即時庫存推播。
初次載入失敗顯示重試，空資料顯示「目前沒有上架餐點」。

雲端模式登入後，收藏、瀏覽與模擬訂單改讀寫會員 API；收到伺服器確認後才更新成功狀態。
購物車、搜尋紀錄與評分回饋仍為本機資料，不會自動上傳原展示模式的紀錄。
下單識別碼會先保存至本機；斷線或重開後使用相同識別碼確認原訂單，不重新建立。詳見 [會員活動](MEMBER_ACTIVITY.md)。
展示模式原本的模擬結帳不變。雲端模式已有獨立商家註冊、登入與 MySQL 上架流程，商家註冊不需審核；見 [商家管理](MERCHANT_MANAGEMENT.md)。

## 伺服器更新及驗證

商品目錄本身不需新遷移，但目前最新版另包含商家管理，尚未套用 003 的主機應先依 [商家部署步驟](MERCHANT_MANAGEMENT.md) 備份及遷移，不可直接沿用下列更新命令。
已具備 001、002、003 結構的主機才可直接更新：
在學校遠端桌面的管理員 PowerShell，依序執行，每一步成功才繼續：

```powershell
cd C:\School\my_app\backend
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\api_service.ps1 -Action Stop
cd ..
git status --short --branch
git pull --ff-only
cd backend
npm.cmd ci
npm.cmd run db:check
npm.cmd test
npm.cmd run test:mysql
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\api_service.ps1 -Action Start
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\api_service.ps1 -Action Status
```

若遇 Git 衝突或測試失敗，先停止後續步驟，不覆寫本機修改。
於伺服器瀏覽器開啟 http://127.0.0.1:3000/api/foods，應看到 items 與 nextCursor。
整合測試會暫時建立並刪除自己的測試商品，所以測試通過後看到空目錄仍可能是正常結果。
已擴充 test:mysql 驗證資料庫目錄、營養及星期欄位、草稿／過期／停用商家不可見，並沿用會員活動的真實 ID 測試。
不要因為空目錄而重複匯入 schema.sql 或 002 遷移。

## 待完成

學校真實 MySQL 目錄已由使用者截圖驗收；外部 HTTPS 連線與真機畫面驗收仍待執行。
App 會員活動已實作並以本機測試驗證，學校伺服器更新及真機同步仍待驗收。
商家管理已實作，仍待學校部署與實測上架。詳見 [部署狀態](../docs/deployment_status.md)。
