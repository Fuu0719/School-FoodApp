# 專案收尾稽核與文件索引

更新日期：2026-10-27。

本文件是收尾階段的單一入口。現況判定優先順序為：原始碼與當次測試、學校伺服器實際驗收、部署狀態、功能手冊、歷史紀錄。規劃稿與舊截圖不能覆蓋現行實作。

## 現行技術基準

| 層級 | 技術與狀態 |
| --- | --- |
| App | Flutter／Dart `1.0.0+36`；會員與商家正式操作介面 |
| Website | HTML／CSS／JavaScript；專題介紹、APK、法律文件及管理入口 |
| Backend | Node.js／Express REST API；網站與 API 共用程序 |
| Database | MySQL；最新結構需要 migration `001–011` |
| Infrastructure | Windows Server、Windows Service、Cloudflare Named Tunnel |
| External | Resend 交易郵件、綠界 Stage 測試付款 |
| Security | scrypt、雜湊 session、Secure Storage、HttpOnly Cookie、CSP、CORS、HSTS、交易與冪等 |
| Test | `flutter analyze` 0 issues；Flutter 128 passed／2 skipped；Node 77 passed／4 skipped |

一般 Node 測試略過 4 項真實 MySQL 整合案例是預期行為；學校部署時必須另跑 `npm.cmd run test:mysql`，且不可略過。上述測試為 2026-10-27 本機結果。

## 文件地圖

1. [README](../README.md)：專案介紹、系統組成、功能與文件入口。
2. [網站架構](website_architecture.md)：網站定位、路由、管理後台與安全邊界。
3. [部署狀態](deployment_status.md)：GitHub 與學校端差異、待辦與限制。
4. [Windows 部署](../backend/DEPLOY_WINDOWS.md)、[網站部署](../backend/WEBSITE_DEPLOY.md)、[資料庫操作](../backend/DATABASE_OPERATIONS.md)：實際操作。
5. [後端 API](../backend/README.md)、[商品目錄](../backend/CATALOG.md)、[會員活動](../backend/MEMBER_ACTIVITY.md)、[商家管理](../backend/MERCHANT_MANAGEMENT.md)：技術細節。
6. [總審技術整理](final_review_master_guide.md)與[答辯問答](final_review_qa.md)：報告及口試依據。
7. [郵件](email_delivery.md)與[通道歷史](tunnel_migration_history.md)：專項設定及歷史追溯。

## 收尾優先順序

1. 在學校伺服器備份資料庫並部署 migration `011`，確認 session 全部失效後可重新登入。
2. 部署網站與管理後台，驗證主網域、API 子網域、APK 下載及管理功能。
3. 安裝 `1.0.0+36`，完成會員、商家、身分切換、訂單保留、付款、郵件與跨網路回歸。
4. 將學校端實際 commit、migration、測試數字與驗收日期回填部署紀錄。
5. 修正總審 PDF 的封面、目錄、密碼規則、頁面敘述、網站架構與新版實機畫面。
6. 正式上架前更換 applicationId、release signing，完成備份還原、隱私程序與安全測試。

## 不可過度宣稱

- AI 是 App 端可解釋規則式內容推薦，沒有訓練機器學習模型，後端推薦端點仍是 501。
- 網站目前是專題介紹、APK 與管理後台；會員／商家完整工作流程在 App。
- 管理後台是單一專題管理帳號，不是完整 RBAC、多管理員稽核平台。
- 便利商店資料不是官方即時庫存，分類圖片不是逐項實拍。
- 綠界 Stage 不是正式交易；尚無退款、對帳或真實商家接單。
- 自動測試通過不等於已完成大量使用者研究、壓力測試或專業滲透測試。

## 工作目錄注意事項

根目錄內舊 APK、畫面 XML、未追蹤影片及 IDE／Flutter 產生檔不是本次文件整理的一部分。發布前應另行決定哪些是成果證據、哪些移至封存區、哪些加入 `.gitignore`；不可直接批次刪除或提交。
