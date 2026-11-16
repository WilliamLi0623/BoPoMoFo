# Bopomofo

简体中文 | [繁體中文](README.zh-TW.md) | [English](README.en.md)

Bopomofo 是一款从已知知识出发学习注音的本机优先应用。应用支持 Android、iOS、Windows、macOS 和 Linux；访客模式会将学习进度保存在本机。

## 环境要求

- Dart SDK：`>=3.6.0 <4.0.0`
- Flutter SDK：`>=3.27.0`
- 应用界面支持简体中文（`zh-Hans`）、繁體中文（`zh-Hant`）和 English（`en`）。
- 原生构建需要对应平台的工具链。GitHub Actions 在每次推送和拉取请求时构建 Linux、Android、Windows、macOS 和 iOS 的调试版本，iOS 使用 `--no-codesign`。

## 安装

在仓库根目录运行：

```text
dart pub get
```

在 `app/bopomofo` 目录运行：

```text
flutter pub get
```

## 配置

访客模式和本机学习无需 Supabase 或 OAuth 凭据。连接在线服务需要外部 Supabase 项目、OAuth 提供方设置，以及平台回调、重定向和签名配置。环境变量模板见 `.env.example`：`SUPABASE_URL`、`SUPABASE_PUBLISHABLE_KEY`、`GOOGLE_OAUTH_CLIENT_ID`、`GOOGLE_OAUTH_REDIRECT_URI`、`APPLE_SERVICE_ID` 和 `APPLE_REDIRECT_URI`。模板不包含凭据。

## 快速开始

在 `app/bopomofo` 目录启动 Windows 桌面应用：

```text
flutter run -d windows
```

## 验证

在 `app/bopomofo` 目录生成本地化文件、运行分析和应用测试：

```text
flutter gen-l10n
flutter analyze
flutter test
```

Windows 离线集成测试：

```text
flutter test integration_test/offline_learning_test.dart -d windows
```

Linux CI 在 Xvfb 中运行同一集成测试：

```text
xvfb-run -a flutter test integration_test/offline_learning_test.dart -d linux
```

在仓库根目录运行工作区验证脚本：

```text
powershell -ExecutionPolicy Bypass -File tool/verify_workspace.ps1
```

本机基线测试不依赖在线 Supabase 或 OAuth 服务；连接在线服务以及真实账号删除需要相应的外部设置。
