# 膳解人意總審技術與答辯總整理

更新日期：2026-10-15。

本文件依目前原始碼、測試、部署紀錄與總審 PDF 整理。用途包括：修正總審文件、製作簡報、分配組員答辯範圍，以及統一「已完成、模擬、尚未完成」的說法。

## 一、專題一句話定位

「膳解人意」是以 Flutter App、Node.js REST API 與 MySQL 建置的個人化餐點推薦及減廢平台，使用可解釋的規則式推薦，依會員偏好、預算、距離、即期程度及直接回饋篩選並排序餐點。

## 二、目前成果與界線

### 已完成

- Android Flutter App 與品牌識別，原始碼版本 `1.0.0+32`。
- 會員註冊、Email 驗證、登入、登出、忘記密碼及個人資料與偏好。
- 預設頭像、自訂 JPG/PNG 頭像上傳與移除。
- MySQL 商品目錄、搜尋、篩選、收藏、瀏覽及訂單；搜尋紀錄目前保存在裝置端。
- 可解釋的規則式推薦與食物轉盤。
- 購物車、庫存驗證、訂單交易與綠界 Stage 測試付款。
- 惜食點數、成就、已付款訂單紀錄與全體排行榜。
- 商家註冊、登入、資料與密碼修改、多門市及商品管理。
- 商品草稿、上架、下架、軟刪除、自訂分類及即期期限。
- 會員與商家帳號一對一綁定及雙向切換。
- 固定網域、Cloudflare Named Tunnel 及 Windows 自動啟動服務。
- Email 驗證信、歡迎信及付款成功訂單信。

### 模擬或測試性質

- 綠界使用 Stage 測試環境，不是正式收款。
- 便利商店門市名稱與座標有公開資料快照，但商品與庫存是模擬資料。
- 六類餐點使用分類共用圖片，不是真實商品逐筆照片。
- 惜食點數與省下金額是專題計算，不等同經第三方驗證的環境效益。
- 商家資料以展示及測試用途為主，尚未建立正式接單營運流程。

### 尚未完成或不可宣稱

- 後端 `/api/recommendations` 尚未完成，回應 HTTP 501；推薦目前在 App 端運算。
- 沒有協同過濾、深度學習、神經網路、生成式 AI 或模型自主訓練。
- 收藏、瀏覽與購買紀錄不會自動重新訓練推薦模型。
- 沒有串接 7-ELEVEN 或全家官方即時庫存。
- 沒有正式金流、退款、對帳及完整商家接單狀態。
- 沒有完成定期異機備份及實際還原演練。
- 尚未完成正式負載測試、滲透測試及大量使用者推薦成效研究。
- iOS 僅具 Flutter 跨平台基礎，未完成 iOS 實機發布驗收。
- Android 仍使用 `com.example.my_app` 與 debug signing，不是正式上架設定。

## 三、整體系統架構

```text
Android 手機
  Flutter / Dart / Material UI
  ├─ HTTP JSON API Client
  ├─ Flutter Secure Storage：會員與商家 Token
  ├─ SharedPreferences：購物車、搜尋紀錄、推薦回饋及部分暫存狀態
  └─ Android WebView：綠界 Stage 付款頁
            │
            │ HTTPS / JSON / Bearer Token
            ▼
Cloudflare DNS + TLS + Named Tunnel
api.mealmind-app.online
            │
            ▼
Windows Server 2016
  cloudflared Windows Service
            │ 轉送至 127.0.0.1:3000
            ▼
  SchoolFoodAppApi Windows Service
  Node.js + Express
  ├─ Auth：會員驗證與 Session
  ├─ Catalog：商店與餐點目錄
  ├─ Activity：收藏、瀏覽、訂單、排行榜
  ├─ Merchant：商家、門市與商品管理
  ├─ ECPay：Stage 測試付款與 CheckMacValue
  └─ SMTP：Resend 交易郵件
            │
            │ mysql2 / SQL / Transaction
            ▼
  MySQLFoodApp 127.0.0.1:3307
  Database: shan_jie_ren_yi
```

### 為何採前後端分離

- Flutter 專注畫面、互動、裝置儲存與推薦呈現。
- Node.js API 統一處理驗證、權限、交易及外部服務。
- MySQL 集中保存多會員與多商家資料，避免只存在單一手機。
- 手機不直接連 MySQL，資料庫帳密及 SQL 不會暴露在 App。

## 四、各層技術與用途

### 1. Flutter 與 Dart

Flutter 是 UI 框架，Dart 是主要程式語言。專案使用 Material 元件、Navigator、表單驗證、非同步 `Future`、狀態更新及響應式版面建立 App。

主要套件：

| 技術 | 用途 |
| --- | --- |
| `http` | 發送 REST API 請求及接收 JSON |
| `flutter_secure_storage` | 保存會員及商家 Token |
| `shared_preferences` | 購物車、待送出請求及部分本機狀態 |
| `flutter_test` | Widget、流程及服務單元測試 |
| `flutter_lints` | 靜態程式碼規範檢查 |

### 2. Android 原生層

- Kotlin `PaymentActivity` 內嵌 WebView 顯示綠界付款頁。
- WebView 攔截 `mealmind://payment?status=...` 回呼並通知 Flutter 結果。
- Manifest 只宣告 Internet 權限，沒有要求 GPS 定位。
- `android:allowBackup="false"`，降低 App 私有資料透過 Android 備份外流的風險。
- Java/Kotlin 編譯目標使用 Java 17。

### 3. HTTP、REST 與 JSON

- App 使用 HTTPS 呼叫 `/api/...` 路徑。
- Request 與 Response 以 JSON 表示結構化資料。
- 受保護端點使用 `Authorization: Bearer <token>`。
- API 依語意使用 GET、POST、PUT、DELETE。
- App 設定 15 秒逾時，並區分連線失敗、逾時、非 JSON 及 HTTP 錯誤。
- 訂單及商家商品建立使用 Idempotency-Key，避免重複送出造成重複寫入。

### 4. Node.js 與 Express

Node.js 是後端 JavaScript 執行環境，Express 負責路由與 middleware。

| 套件 | 用途 |
| --- | --- |
| `express` | REST API、middleware、靜態圖片服務及錯誤處理 |
| `mysql2` | Prepared statement、Connection Pool 及資料庫交易 |
| `nodemailer` | 透過 Resend SMTP 寄送交易郵件 |
| `express-rate-limit` | 限制登入、註冊及敏感操作嘗試次數 |
| `dotenv` | 從 `.env` 載入密鑰與環境設定 |
| `cors` | 處理跨來源請求；目前設定較寬鬆，正式營運前應縮限 |
| Node `crypto` | scrypt、隨機碼、Token Hash 與綠界雜湊 |

### 5. MySQL 與資料模型

主要資料表：

| 類別 | 資料表 |
| --- | --- |
| 會員與驗證 | `users`、`user_preferences`、`user_sessions`、`member_email_codes`、`pending_member_registrations`、`member_password_reset_tokens` |
| 商家 | `merchants`、`merchant_sessions`、`member_merchant_links` |
| 門市與商品 | `stores`、`store_business_weekdays`、`foods`、`food_tags`、`food_ingredients`、`merchant_product_requests` |
| 會員活動 | `favorites`、`browsing_histories`、`search_logs`、`recommendation_feedback` |
| 訂單 | `purchase_orders`、`purchase_order_items` |

底層資料庫機制：

- Primary Key 唯一識別資料。
- Foreign Key 維持資料關聯。
- Unique Key 避免 Email、Token 或請求識別重複。
- `ON DELETE CASCADE` 清除會員關聯資料。
- Prepared statement 防止 SQL Injection。
- Transaction 確保多筆寫入一起成功或一起回復。
- `SELECT ... FOR UPDATE` 鎖定庫存、訂單或帳號，避免競爭條件。
- 商品與門市使用邏輯刪除，保留歷史訂單參照與快照。
- 訂單明細保存名稱、價格等快照，避免商品日後變更影響舊訂單。

### 6. 規則式人工智慧與推薦

技術名稱建議使用「可解釋的規則式推薦系統」（Explainable Rule-based Recommendation System）。

第一階段排除：

- 不符合營業日或供應狀態。
- 超出預算或距離。
- 不符合偏好標籤。
- 包含忌口食材。
- 已過期、下架、售罄或門市已刪除。

第二階段評分：

```text
總分 = 偏好 35% + 距離 18% + 預算 18% + 減廢 19% + 回饋 10%
```

第三階段解釋：App 顯示總分、五項分數及推薦理由。這是內生式可解釋性，不是對黑箱模型使用 SHAP 或 LIME。

### 7. 身分驗證與密碼

- 新註冊資料先放在 `pending_member_registrations`，驗證成功才建立正式會員。
- Email 驗證碼為六位數、10 分鐘有效並限制錯誤次數。
- 忘記密碼先驗證 Email，再核發短效一次性 reset token。
- 密碼以 Node.js scrypt 加隨機 salt 雜湊，不儲存明文或可解密密碼。
- 驗證比較使用 `timingSafeEqual`，降低時間差攻擊。
- Session token 使用密碼學安全亂數產生，資料庫只保存 SHA-256 Hash。
- 登出及密碼重設會撤銷 Session。
- 會員與商家擁有不同 Session 表及權限範圍。

### 8. 帳號綁定與切換

- `member_merchant_links` 以唯一限制維持一個會員對一個商家。
- 切換身分時，在同一個資料庫交易中建立目的端 Session 並撤銷來源端 Session。
- App 同步移除來源 Token，避免兩種身分同時保持有效。
- 登出會清除裝置上的兩種 Token，但不會解除資料庫綁定。

### 9. 訂單、庫存與冪等

- 後端重新讀取並鎖定商品，不採信 App 傳來的價格或庫存。
- 依商品 ID 排序後鎖定，降低交易死鎖風險。
- 驗證門市、上下架、期限、營業狀態與庫存。
- 訂單表頭、明細及扣庫存在同一交易內完成。
- App 產生 request ID，後端以 Idempotency-Key 與 request hash 防止重複下單。
- 同一 Key 搭配不同內容會被拒絕；相同內容重送會回傳既有訂單。

### 10. 綠界 Stage 測試付款

- 後端建立付款參數及 MerchantTradeNo。
- App 以 Android WebView 留在 App 內顯示付款頁。
- 綠界 Server-to-Server ReturnURL 回呼由後端驗證 CheckMacValue。
- 只有驗證成功才把訂單從 `pending` 改成 `paid`。
- 瀏覽器導回畫面只用來通知 UI，不單獨作為付款成功依據。
- 目前是 Stage，不能宣稱正式收款、退款或對帳完成。

### 11. Email 與 Resend

- SMTP Host 使用 Resend，寄件網域為 `mealmind-app.online`。
- 寄件地址為 `noreply@mealmind-app.online`，顯示名稱改為純英文 `MealMind`。
- DNS 透過 SPF、DKIM 等紀錄證明寄件網域授權。
- API Key 只放在伺服器 `.env`，不得提交 Git。
- Email 失敗不回滾已成立的付款訂單。
- `.test` 模擬商家地址不寄送，避免產生退信。

### 12. Cloudflare、DNS、TLS 與 Tunnel

- DNS 將 `api.mealmind-app.online` 導向 Cloudflare。
- TLS 提供手機至 Cloudflare 的 HTTPS 加密與憑證驗證。
- Named Tunnel 由伺服器主動連出 Cloudflare，不需公開 3000 或 3307。
- `cloudflared` 以 Windows 服務自動啟動，固定網址不會像 Quick Tunnel 每次改變。
- Node API 只監聽 `127.0.0.1:3000`；MySQL 只監聽 `127.0.0.1:3307`。
- ngrok 與 Cloudflare Quick Tunnel 已退出正式測試架構。

### 13. Windows 服務與部署

- `MySQLFoodApp`：專案 MySQL 服務。
- `SchoolFoodAppApi`：Node.js API 服務，以 LocalService 執行。
- `cloudflared`：Cloudflare Tunnel 服務。
- 三項服務皆設定 Automatic，但 Git 程式碼不會自動更新。
- 更新流程仍需人工備份、停止 API、`git pull`、安裝依賴、檢查資料庫、測試及重啟。
- Migration `001` 至 `010` 已套用，不可重跑；新增 migration 才能在備份後執行。

### 14. Git、GitHub 與版本控制

- Git 記錄程式與文件變更；GitHub 作為遠端儲存庫。
- `.env`、資料庫密碼、SMTP Key、綠界 HashKey/HashIV 不得提交。
- Git commit、GitHub push、學校伺服器 pull、API restart 與 APK 安裝是五個不同步驟。

### 15. 測試技術

- `flutter analyze`：Dart 靜態分析，目前 0 問題。
- `flutter test`：目前 123 項通過、2 項依雲端條件跳過。
- Node `node:test`：本機 59 項通過、3 項真實 MySQL 測試跳過。
- 學校伺服器歷史驗收：27 項 MySQL 整合測試通過。
- 測試涵蓋表單、畫面導向、推薦分數、權限、交易回滾、帳號隔離、冪等、庫存鎖及商家所有權。
- 尚未完成正式負載測試、滲透測試、完整裝置矩陣及推薦準確率研究。

## 五、重要資料流程

### 會員註冊

```text
輸入姓名、Email、密碼
→ App POST /api/auth/register
→ 後端驗證格式、限制頻率、雜湊密碼
→ 暫存待驗證資料並寄六位數驗證碼
→ App POST /api/auth/verify-email
→ MySQL 交易建立 users、preferences、session
→ 寄歡迎信
→ App 保存 Token 並進入首次資料設定
```

### 推薦

```text
App 讀取 MySQL 商品目錄與會員偏好
→ 排除不符合條件餐點
→ 計算五項分數
→ 依總分排序
→ 顯示推薦分數與原因
```

### 結帳

```text
App 購物車 + Idempotency-Key
→ API 鎖定商品與庫存
→ 驗證價格、期限、營業狀態與庫存
→ Transaction 建立訂單、明細、扣庫存
→ 建立綠界 Stage 付款頁
→ WebView 付款
→ 綠界後端回呼 + CheckMacValue
→ 訂單標記 paid
→ 寄送訂單 Email
```

## 六、資安措施與剩餘風險

### 已有措施

- scrypt + salt 密碼雜湊。
- Session token 與付款 token 只保存 Hash。
- Flutter Secure Storage 保存登入憑證。
- HTTPS 固定網域。
- API 與 MySQL 不直接公開外網 Port。
- Prepared statement 防 SQL Injection。
- 輸入長度、型態、電話、圖片 URL 與日期驗證。
- 登入及註冊 rate limit。
- 帳號及商家所有權由 Session 決定，不採信前端傳入身分 ID。
- 資料庫交易、鎖定、回滾與冪等處理。
- Android 停用系統備份。

### 尚待改善

- Express CORS 目前較寬鬆，正式營運應限制允許來源。
- Android applicationId 仍為範例值，release 仍使用 debug signing。
- 尚無自動異機備份、還原演練及金鑰輪替制度。
- 尚無正式隱私政策、資料保存期限及帳號自助刪除流程。
- WebView 啟用 JavaScript，正式營運應限制可載入網域與導向。
- 沒有完成第三方滲透測試或正式弱點掃描。
- 一般偏好及活動資料未做欄位層級加密，報告不可宣稱全部加密儲存。

## 七、總審文件逐章檢查

| PDF 位置 | 目前問題 | 必須修改方向 |
| --- | --- | --- |
| 第 1-2 頁 | 第六位組員與日期被擠到目錄頁 | 封面全部放回第 1 頁 |
| 第 6 頁摘要 | 寫 Visual Studio、SQL Server、AI 自主學習 | 改為 Flutter/Dart、Node.js API、MySQL、規則式推薦 |
| 第 7 頁研究背景 | 再次宣稱 SQL Server 與自主學習 | 改成真實技術與人工設定權重 |
| 第 12 頁文獻探討 | 宣稱混合式推薦、協同過濾與 AI 學習習慣 | 只在文獻介紹，實作明確寫規則式內容推薦 |
| 第 16 頁研究貢獻 | 宣稱整合超商當天庫存 | 改成模擬便利商店餐點及庫存 |
| 第 18 頁研究步驟 | 寫已採協同過濾 | 改成排除規則、五項加權與人工調整 |
| 第 19-23 頁架構 | 漏掉 Node.js、Express、Cloudflare、SMTP、金流 | 重畫前後端與部署架構圖 |
| 第 23-25 頁功能架構 | 只列五大功能 | 補會員驗證、購物車、訂單、排行榜、商家與帳號切換 |
| 第 27-34 頁規格 | 寫用戶名、生日、簡訊、快速登入、自主學習 | 改成 Email、實際欄位及目前回饋方式 |
| 第 28、41 頁搜尋 | 宣稱熱門搜尋與自動補完 | 改成固定建議字、同義詞與多欄位比對 |
| 第 29 頁距離 | 宣稱讀取手機目前位置 | 改為固定銘傳桃園校區基準 |
| 第 34 頁轉盤 | 宣稱限制重轉次數 | 刪除未實作限制 |
| 第 36-37 頁 | 宣稱意見表單、自動回信、完整條款頁 | 移至未來方向 |
| 第 39 頁類別圖 | 圖太小且模型與目前資料表不符 | 依目前 API domain/schema 重畫並獨立橫向一頁 |
| 第 40-42 頁功能表 | 混合式 AI、自動學習、碳排與重量等過度宣稱 | 改成實際規則推薦、惜食份數及省下金額 |
| 第 43 頁法律 | 宣稱偏好與活動全部加密 | 改述密碼/Token/HTTPS，說明一般欄位未加密 |
| 第 44 頁測試 | 把資料一致性稱作演算法成效 | 改名並補實際測試數量與限制 |
| 第 50-51 頁結果 | 大致符合目前狀態 | 補 App 端推薦、501 限制、實機尚待最終驗收 |
| 第 52-65 頁手冊 | 密碼、部分欄位及頁面敘述仍可能過期 | 逐張以 1.0.0+32 實機畫面核對 |
| 第 66 頁結語 | 可能暗示自主學習與已證明準確 | 改成規則正確性，機器學習列未來方向 |
| 目錄與圖表目錄 | 頁碼只到 45，但實際共 69 個 PDF 頁面 | 更新整個目錄、圖目錄及表目錄 |

### 報告名詞統一

- 「Visual Studio」改為「Visual Studio Code」。
- 「SQL Server」改為「MySQL」。
- 「AI 自主學習」改為「可解釋的規則式推薦」。
- 「混合式推薦」只放文獻或未來方向。
- 「精準推薦」改為「個人化排序」或「依規則推薦」。
- 「即時超商庫存」改為「模擬即期商品資料」。
- 「使用者目前位置」改為「銘傳大學桃園校區基準距離」。
- 「減少碳排量」改為「惜食點數、份數及省下金額」。
- `ios` 改為 `iOS`；`Pet information` 改為 `Food information`。

## 八、總審常見提問與標準回答

### A. 題目與創新性

**Q1：你們解決什麼問題？**
日常用餐選項過多造成的決策負擔，以及仍可食用即期餐點曝光不足造成的浪費。

**Q2：創新點是什麼？**
把個人化選餐、可解釋推薦、即期餐點加權、食物轉盤、商家管理與惜食成果放在同一個可操作系統，而不是只有折扣列表或隨機抽選。

**Q3：和一般外送或惜食 App 有何不同？**
本系統重點是降低選擇成本並解釋推薦原因；目前不是正式配送平台，也不宣稱已有大量合作商家。

### B. AI 與推薦

**Q4：AI 用在哪裡？**
用於候選排除、五項加權評分、排序與推薦理由，是可解釋的規則式推薦。

**Q5：規則式系統算 AI 嗎？**
算，AI 包含專家系統、規則推理及決策；但必須清楚說明它不是機器學習。

**Q6：為何不用機器學習？**
目前真實互動資料不足，規則式方法可避免冷啟動並提供可驗證的解釋。

**Q7：會自主學習嗎？**
不會自動訓練或改權重；直接評分回饋會參與後續分數。

**Q8：權重從哪裡來？**
依專題目標人工設定，目前是設計參數，未宣稱是模型訓練出的最佳值。

**Q9：如何證明準確？**
目前證明規則、分數與排序依設計正確運作，尚未證明大量使用者情境下的預測準確率。

**Q10：為何可解釋？**
結果可拆成偏好、距離、預算、減廢、回饋五項分數，使用者可直接看到原因。

完整 AI 題庫見 `docs/final_review_qa.md`。

### C. 架構與技術

**Q11：為何選 Flutter？**
可用單一 Dart 程式碼建立跨平台介面，適合專題人力及快速迭代；目前主要驗收平台仍是 Android。

**Q12：為何選 Node.js？**
適合 JSON REST API、非同步 I/O 與快速整合 MySQL、SMTP 及付款服務。

**Q13：為何選 MySQL？**
會員、商家、商品及訂單具有明確關聯，且結帳需要交易、鎖定與一致性，關聯式資料庫較合適。

**Q14：手機為何不能直接連資料庫？**
否則會暴露資料庫帳密及商業邏輯，也難以統一驗證與權限；手機只能經 API 存取。

**Q15：Cloudflare Tunnel 做什麼？**
把固定 HTTPS 網址安全轉送到只監聽本機的 Node API，避免直接公開 API 與 MySQL Port。

**Q16：為何不用 ngrok？**
先前遇到流量限制；Cloudflare Named Tunnel 搭配自有網域可提供固定網址及 Windows 服務常駐。

### D. 資料庫與交易

**Q17：如何避免超賣？**
後端交易內以 `FOR UPDATE` 鎖定商品，重新檢查庫存後才建立訂單並扣庫存。

**Q18：建立訂單到一半失敗怎麼辦？**
表頭、明細與扣庫存位於同一交易，任一失敗會 rollback。

**Q19：重複點擊付款會不會產生多筆訂單？**
使用 Idempotency-Key 及 request hash；相同請求重送回傳既有結果，不同內容共用 Key 會被拒絕。

**Q20：商品刪除後舊訂單怎麼辦？**
商品採軟刪除，訂單明細另存商品名稱與價格快照，所以歷史訂單仍可讀取。

**Q21：刪除會員會留下資料嗎？**
會員關聯資料以外鍵連鎖刪除；正式操作仍應先查核、備份並在刪除後驗證。

### E. 登入與資安

**Q22：密碼怎麼保存？**
使用 scrypt 與每筆隨機 salt 的不可逆雜湊，資料庫不保存明文。

**Q23：Token 被偷怎麼辦？**
裝置端放 Secure Storage，資料庫只存 Hash；Token 有期限且登出、改密碼或切換身分時會撤銷。

**Q24：如何避免 SQL Injection？**
mysql2 prepared statements 綁定參數，不把使用者輸入直接拼進 SQL。

**Q25：有防暴力登入嗎？**
敏感端點使用 rate limit；未知帳號登入也執行模擬密碼雜湊，降低帳號探測差異。

**Q26：資料都加密嗎？**
傳輸使用 HTTPS，密碼與 Token 使用 Hash；一般偏好與活動資料目前沒有欄位層級加密，不能說全部加密。

### F. 付款與郵件

**Q27：付款真的有收款嗎？**
沒有，目前是綠界 Stage 測試交易，畫面與回呼流程可驗證，但不能代表正式金流。

**Q28：如何判斷付款成功？**
以綠界後端 ReturnURL 的 CheckMacValue 驗證為準，不只相信手機畫面導回結果。

**Q29：為何付款頁能留在 App？**
Android 原生 WebView 顯示付款頁，再以自訂 URL Scheme 回到 App。

**Q30：Resend 與 Gmail 有何不同？**
Resend 是交易郵件服務，使用已驗證自有網域、SPF/DKIM 與 API Key；不再用個人 Gmail 當品牌寄件者。

### G. 資料與減廢

**Q31：餐點資料是真實的嗎？**
門市名稱與座標部分來自公開地圖快照；商品、價格、庫存與即期時間主要是測試模擬資料。

**Q32：減碳量怎麼算？**
目前沒有科學驗證的碳排換算，只呈現惜食點數、即期餐點份數及省下金額；報告不可宣稱精確碳排量。

**Q33：距離怎麼取得？**
不使用手機 GPS，以銘傳大學桃園校區為固定基準，將門市地址轉為座標後計算直線距離。

**Q34：如何確保不推薦過期食品？**
公開目錄、推薦及結帳都檢查期限；後端結帳會再次驗證，不只依賴前端畫面。

### H. 測試、限制與未來

**Q35：你們做了哪些測試？**
包含 Flutter Widget/Service 測試、Node API 單元測試、MySQL 整合測試、交易回滾、帳號隔離及部署健康檢查。

**Q36：最大限制是什麼？**
真實使用者與商家資料不足、推薦仍在 App 端、付款為 Stage、備份與正式營運流程尚未完整。

**Q37：若正式上線，第一步做什麼？**
改正式 applicationId 與簽章、完成隱私政策、備份與還原、正式金流、商家接單流程、安全檢測及推薦成效研究。

**Q38：系統能承受多少人？**
目前未做正式負載測試，不能提供可信同時人數；只能說架構使用 connection pool 與 Windows 服務，仍需壓力測試量測。

**Q39：為何後端推薦 API 是 501？**
目前商品與會員資料由雲端提供，但排序保留在 App；501 是刻意避免把未完成端點誤認成正式雲端推薦服務。

**Q40：未來 AI 如何升級？**
取得足夠且經同意的互動資料後，可研究學習排序、協同過濾或混合式推薦，並用 Precision、Recall、NDCG、採納率及滿意度評估。

## 九、答辯時的統一說法

### 30 秒技術版

> 我們以 Flutter 建置 Android App，透過 HTTPS 呼叫部署在學校 Windows Server 的 Node.js REST API，資料集中存放於 MySQL。外部連線由 Cloudflare Named Tunnel 提供固定網域，會員密碼使用 scrypt 雜湊，Token 放在手機安全儲存區。推薦採可解釋的規則式內容推薦，先篩選再依五項權重排序；付款使用綠界 Stage，郵件使用 Resend 自有網域。

### 不能說錯的五件事

1. 推薦是規則式，不是自主學習模型。
2. 商品與庫存是模擬資料，不是超商官方即時資料。
3. 綠界是 Stage，不是正式收款。
4. 距離以銘傳桃園校區為基準，不是手機 GPS。
5. 後端推薦 API 尚未完成，排序目前在 App 端。

## 十、總審前檢查清單

- [ ] 摘要、研究背景、研究方法及結語移除自主學習與 SQL Server。
- [ ] 架構圖補上 Node.js、Express、MySQL、Cloudflare、Resend 及綠界。
- [ ] 類別圖依目前資料表或 domain model 重畫。
- [ ] 功能規格刪除 SMS、第三方登入、自動補完、碳排量及 GPS。
- [ ] 測試章節補上實際命令、通過數量、日期與跳過原因。
- [ ] 使用者手冊以 `1.0.0+32` APK 重新逐張核對。
- [ ] 更新 Word 全部目錄、圖目錄及表目錄。
- [ ] 六位組員各自熟悉 AI、前端、後端、資料庫、資安及部署至少一類問題。
- [ ] 展示前驗證三個 Windows 服務、公開 health、Email、會員、商家及付款流程。
- [ ] 準備一組不含個資的會員及商家展示帳號。
