# Bopomofo

[简体中文](README.md) | 繁體中文 | [English](README.en.md)

Bopomofo 是一款從已知知識出發學習注音的本機優先應用程式。應用程式支援 Android、iOS、Windows、macOS 和 Linux；訪客模式會將學習進度儲存在本機。

## 系統需求

- Dart SDK：`>=3.6.0 <4.0.0`
- Flutter SDK：`>=3.50.0`
- 應用程式介面支援簡體中文（`zh-Hans`）、繁體中文（`zh-Hant`）和 English（`en`）。
- 原生建置需要對應平台的工具鏈。GitHub Actions 在每次推送和提取要求時建置 Linux、Android、Windows、macOS 和 iOS 的偵錯版本，iOS 使用 `--no-codesign`。

## 安裝

在儲存庫根目錄執行：

```text
dart pub get
```

在 `app/bopomofo` 目錄執行：

```text
flutter pub get
```

## 設定

訪客模式和本機學習不需要 Supabase 或 OAuth 憑證。連線線上服務需要外部 Supabase 專案、OAuth 提供者設定，以及平台回呼、重新導向和簽署設定。環境變數範本見 `.env.example`：`SUPABASE_URL`、`SUPABASE_PUBLISHABLE_KEY`、`GOOGLE_OAUTH_CLIENT_ID`、`GOOGLE_OAUTH_REDIRECT_URI`、`APPLE_SERVICE_ID` 和 `APPLE_REDIRECT_URI`。範本不包含憑證。

## 快速開始

在 `app/bopomofo` 目錄啟動 Windows 桌面應用程式：

```text
flutter run -d windows
```

## 驗證

在 `app/bopomofo` 目錄產生本地化檔案、執行分析和應用程式測試：

```text
flutter gen-l10n
flutter analyze
flutter test
```

Windows 離線整合測試：

```text
flutter test integration_test/offline_learning_test.dart -d windows
```

Linux CI 在 Xvfb 中執行相同的整合測試：

```text
xvfb-run -a flutter test integration_test/offline_learning_test.dart -d linux
```

在儲存庫根目錄執行工作區驗證指令碼：

```text
powershell -ExecutionPolicy Bypass -File tool/verify_workspace.ps1
```

本機基線測試不依賴線上 Supabase 或 OAuth 服務；連線線上服務及真實帳戶刪除需要相應的外部設定。
