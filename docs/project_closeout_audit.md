# 專案收尾稽核與文件索引

更新日期：2026-10-15。

本文件是收尾階段的文件入口。現況判定依序以「原始碼與自動測試、學校伺服器實際驗收、部署狀態文件、功能手冊、歷史紀錄」為準；規劃稿與歷史紀錄不得覆蓋現行實作。

## 現行基準

| 項目 | 現況 |
| --- | --- |
| App | Flutter／Dart，版本 `1.0.0+34`，Android applicationId 仍為 `com.example.my_app` |
| 後端 | Node.js REST API，僅監聽學校主機 `127.0.0.1:3000` |
| 資料庫 | MySQL `shan_jie_ren_yi`，port 3307，migration `001` 至 `010` 已完成 |
| 公開入口 | Cloudflare Named Tunnel：`https://api.mealmind-app.online/api` |
| 郵件 | Resend；`MealMind <noreply@mealmind-app.online>` |
| 付款 | 綠界 Stage 模擬付款，不是正式收款 |
| 推薦 | App 端可解釋規則式內容推薦；後端 `/api/recommendations` 仍為 501 |
| 測試 | Node.js 60 passed／3 skipped；Flutter 125 passed／2 skipped |

2026-10-15 的 `flutter analyze` 因 Windows Developer Mode 未啟用、插件無法建立 symlink 而未完成。這是收尾前必補的環境驗證，不能引用舊版 0 issues 取代。

## 文件閱讀順序

1. [README](../README.md)：功能範圍、展示資料及整體入口。
2. [部署進度](deployment_status.md)：學校伺服器已完成、限制與待辦。
3. [雲端與實機驗收](cloud_activity_verification.md)：部署及手機逐項驗收清單。
4. [Windows 部署](../backend/DEPLOY_WINDOWS.md)與[資料庫操作](../backend/DATABASE_OPERATIONS.md)：伺服器操作唯一依據。
5. [後端 API](../backend/README.md)、[商品目錄](../backend/CATALOG.md)、[會員活動](../backend/MEMBER_ACTIVITY.md)、[商家管理](../backend/MERCHANT_MANAGEMENT.md)：實作細節。
6. [總審技術與答辯總整理](final_review_master_guide.md)及[AI 問答](final_review_qa.md)：口試準備。
7. [通道遷移歷史](tunnel_migration_history.md)：只供追溯，ngrok 與 Quick Tunnel 不可恢復為正式入口。

## 已完成與可展示

- 會員註冊、Email 驗證、歡迎信、登入、登出、兩頁式忘記密碼、個人資料與頭像。
- 偏好、搜尋、收藏、瀏覽、購物車、模擬付款、購買紀錄與惜食排行榜。
- 商家帳號、資料與密碼管理、多門市、商品草稿、上下架、刪除及分類。
- 會員與商家一對一綁定及雙向切換，切換時撤銷來源 session。
- 固定 HTTPS 網域、Windows 自動服務、MySQL 持久化及 Resend 網域交易郵件。

## 尚待收尾

1. 啟用開發電腦 Windows Developer Mode 後重跑 `flutter analyze`。
2. 建置 `1.0.0+34` APK，確認 release 簽章；目前 Android release 仍使用 debug signing，不適合正式上架。
3. 用實機依驗收清單跑完會員、商家、付款及三類郵件，保留截圖與版本號。
4. 重新核對總審 PDF 的封面換頁、目錄頁碼、系統架構圖、功能敘述與 `1.0.0+34` 實機畫面。
5. 建立異機定期備份並實際演練還原。

## 總審 PDF 最新檢查

2026-10-15 20:04 的 69 頁版本已修正摘要、技術架構、規則式推薦、固定校園距離、資安限制與部署結果。仍須修改以下項目：

- 封面第六位組員與日期落到目錄頁。
- 目錄頁碼未隨使用者手冊擴頁更新；目錄寫第八章 43 頁，但本文第八章已在印刷頁 60。
- 第 24 頁把瀏覽與收藏寫成推薦依據；目前排序採偏好、距離、預算、減廢及直接評分回饋。
- 第 25 頁仍以 Username 描述登入識別；實際使用 Email。
- 第 52、62 頁密碼規則寫成「6-18 個數字」；實作為 8-16 字元。
- 第 53 頁把會員資料編輯誤寫成商家註冊；第 60 頁把購物車誤寫成由註冊介面進入。
- 第 66 頁仍用預期完成、持續建置及初步試作描述已完成系統，且提到尚未實作的留言機制。
- 測試章應補最新 Node 60/3、Flutter 125/2，並註明本次 `flutter analyze` 尚待解除 symlink 環境阻擋後補跑。

## 不可過度宣稱

- 沒有訓練機器學習模型，也沒有完成後端雲端推薦引擎；AI 是可解釋的規則式多條件評分。
- 沒有 GPS 即時定位，距離基準固定為銘傳大學桃園校區。
- 模擬便利商店商品不是官方即時庫存，分類圖片也不是每項商品的實拍照片。
- 綠界 Stage 不是正式交易；尚無退款、對帳與真實商家接單流程。
- 尚未完成大量使用者研究、壓力測試或專業滲透測試。

## 學校伺服器與資料庫影響

本次文件稽核不含程式、migration 或資料庫變更。文件合併至 GitHub `main` 後，學校伺服器只需視需要執行 `git pull --ff-only origin main`；不需停止 API、不需執行 `npm ci`、不需重啟服務，也不得重跑任何 migration。
