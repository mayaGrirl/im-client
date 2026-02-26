# IM Client - Flutter 跨平台客户端

## 概述

IM Client 是基于 Flutter 开发的跨平台即时通讯客户端，支持 iOS、Android、Web、Windows、macOS 和 Linux 平台。

---

## 目录

- [环境要求](#环境要求)
- [开发环境搭建](#开发环境搭建)
- [快速开始](#快速开始)
- [项目结构](#项目结构)
- [环境配置](#环境配置)
- [运行应用](#运行应用)
- [编译发布](#编译发布)
- [Nginx部署配置](#nginx部署配置)
- [国际化](#国际化)
- [状态管理](#状态管理)
- [网络请求](#网络请求)
- [常见问题](#常见问题)

---

## 环境要求

| 工具 | 版本要求 | 说明 |
|------|----------|------|
| Flutter SDK | >= 3.7.2 | 跨平台框架 |
| Dart SDK | >= 3.0.0 | 编程语言 |
| Android Studio | 最新版 | Android开发/模拟器 |
| Xcode | >= 14.0 | iOS开发 (仅macOS) |
| VS Code | 最新版 | 推荐的IDE |
| Git | 最新版 | 版本控制 |

---

## 开发环境搭建

### Windows 环境搭建

#### 1. 安装 Flutter SDK

```powershell
# 方式一：使用官方安装包
# 1. 下载 Flutter SDK: https://docs.flutter.dev/get-started/install/windows
# 2. 解压到 C:\flutter (不要放在需要管理员权限的目录)
# 3. 将 C:\flutter\bin 添加到系统 PATH 环境变量

# 方式二：使用 Chocolatey (推荐)
choco install flutter

# 方式三：使用 Scoop
scoop install flutter
```

#### 2. 配置环境变量

```powershell
# 打开系统属性 -> 高级 -> 环境变量
# 在用户变量中编辑 Path，添加：
C:\flutter\bin

# 或者在 PowerShell 中临时设置
$env:Path += ";C:\flutter\bin"
```

#### 3. 安装 Android Studio

```powershell
# 1. 下载安装 Android Studio: https://developer.android.com/studio
# 2. 打开 Android Studio
# 3. 选择 More Actions -> SDK Manager
# 4. 安装以下组件：
#    - Android SDK Platform-Tools
#    - Android SDK Build-Tools
#    - Android SDK Command-line Tools
#    - Android Emulator
#    - Android SDK Platform (最新版本)

# 5. 创建模拟器:
#    More Actions -> Virtual Device Manager -> Create Device
#    选择 Pixel 6 -> 下载并选择系统镜像 -> 完成

配置版本总结
  ┌────────────────────────┬─────────────────────────┐
  │          组件          │          版本           │
  ├────────────────────────┼─────────────────────────┤
  │ Flutter                │ 3.38.9                  │
  ├────────────────────────┼─────────────────────────┤
  │ Kotlin                 │ 2.1.0                   │
  ├────────────────────────┼─────────────────────────┤
  │ AGP                    │ 8.9.1                   │
  ├────────────────────────┼─────────────────────────┤
  │ Gradle                 │ 8.11.1                  │
  ├────────────────────────┼─────────────────────────┤
  │ Java                   │ 21 (Android Studio JBR) │
  ├────────────────────────┼─────────────────────────┤
  │ minSdk                 │ 24                      │
  ├────────────────────────┼─────────────────────────┤
  │ compileSdk / targetSdk │ Flutter 默认（36）      │
  └────────────────────────┴─────────────────────────┘
```

#### 4. 验证安装

```powershell
# 检查 Flutter 环境
flutter doctor

# 如果提示 Android licenses 问题，运行：
flutter doctor --android-licenses
# 输入 y 同意所有许可
```

### macOS 环境搭建

#### 1. 安装 Homebrew (如果没有)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

#### 2. 安装 Flutter SDK

```bash
# 使用 Homebrew 安装
brew install flutter

# 或者手动安装
cd ~/development
git clone https://github.com/flutter/flutter.git -b stable
echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

#### 3. 安装 Xcode

```bash
# 从 App Store 安装 Xcode
# 或使用命令行
xcode-select --install

# 安装完成后，同意许可协议
sudo xcodebuild -license accept

# 安装 CocoaPods (iOS依赖管理)
sudo gem install cocoapods
# 或
brew install cocoapods
```

#### 4. 安装 Android Studio

```bash
# 使用 Homebrew 安装
brew install --cask android-studio

# 打开 Android Studio，按照向导安装 SDK
```

#### 5. 验证安装

```bash
flutter doctor
# 确保所有项目都显示绿色勾号
```

### Linux (Ubuntu/Debian) 环境搭建

#### 1. 安装依赖

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装必要依赖
sudo apt install -y curl git unzip xz-utils zip libglu1-mesa

# 安装 Chrome (用于Web开发调试)
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo dpkg -i google-chrome-stable_current_amd64.deb
sudo apt --fix-broken install -y
```

#### 2. 安装 Flutter SDK

```bash
# 下载 Flutter
cd ~
git clone https://github.com/flutter/flutter.git -b stable

# 添加到 PATH
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# 预下载开发所需的二进制文件
flutter precache
```

#### 3. 安装 Android Studio

```bash
# 使用 snap 安装 (推荐)
sudo snap install android-studio --classic

# 或下载安装
# 从 https://developer.android.com/studio 下载
# 解压到 /opt/android-studio
# 运行 /opt/android-studio/bin/studio.sh
```

#### 4. 配置 Android 环境变量

```bash
# 添加到 ~/.bashrc
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools

source ~/.bashrc
```

#### 5. 安装 Linux 桌面开发依赖

```bash
# 如果需要编译 Linux 桌面应用
sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
```

### IDE 配置

#### VS Code (推荐)

```bash
# 安装扩展
# 1. 打开 VS Code
# 2. 按 Ctrl+Shift+X 打开扩展
# 3. 搜索并安装以下扩展：
#    - Flutter
#    - Dart
#    - Flutter Widget Snippets
#    - Awesome Flutter Snippets
```

#### Android Studio

```
1. 打开 Settings/Preferences
2. 选择 Plugins
3. 搜索并安装：
   - Flutter
   - Dart
4. 重启 Android Studio
```

---

## 快速开始

### 1. 克隆/进入项目

```bash
cd im/client
```

### 2. 安装依赖

```bash
flutter pub get
```

### 3. 运行应用

```bash
# 查看可用设备
flutter devices

# Web (推荐开发调试)
flutter run -d chrome

# Android 模拟器
flutter run -d android

# iOS 模拟器 (仅 macOS)
flutter run -d ios

# Windows 桌面
flutter run -d windows

# macOS 桌面
flutter run -d macos

# Linux 桌面
flutter run -d linux
```

---

## 项目结构

```
lib/
├── api/                    # API 接口层
│   ├── api_client.dart    # HTTP 客户端封装
│   ├── auth_api.dart      # 认证接口
│   ├── friend_api.dart    # 好友接口
│   ├── group_api.dart     # 群组接口
│   └── conversation_api.dart  # 会话接口
│
├── config/                 # 配置
│   └── env_config.dart    # 环境配置
│
├── constants/              # 常量
│   └── app_constants.dart # 应用常量
│
├── l10n/                   # 国际化
│   └── app_localizations.dart  # 多语言支持
│
├── models/                 # 数据模型
│   ├── user.dart          # 用户模型
│   ├── message.dart       # 消息模型
│   └── group.dart         # 群组模型
│
├── providers/              # 状态管理
│   ├── auth_provider.dart     # 认证状态
│   ├── chat_provider.dart     # 聊天状态
│   └── locale_provider.dart   # 语言状态
│
├── screens/                # 页面
│   ├── splash_screen.dart # 启动页
│   ├── login_screen.dart  # 登录页
│   ├── home_screen.dart   # 主页
│   ├── tabs/              # 底部Tab页
│   └── group/             # 群组相关页面
│
├── services/               # 服务层
│   ├── storage_service.dart   # 本地存储
│   ├── websocket_service.dart # WebSocket服务
│   └── local_database_service.dart  # 本地数据库
│
├── widgets/                # 通用组件
│   └── ...
│
└── main.dart              # 入口文件
```

---

## 环境配置

### 配置文件

`lib/config/env_config.dart`

### 三种环境

| 环境 | 标识 | API地址 | WebSocket地址 |
|------|------|---------|---------------|
| 开发 | dev | http://127.0.0.1:8080 | ws://127.0.0.1:8080/ws |
| 测试 | staging | https://staging-api.example.com | wss://staging-api.example.com/ws |
| 生产 | prod | https://api.example.com | wss://api.example.com/ws |

### 初始化环境

在 `main.dart` 中：

```dart
import 'package:im_client/config/env_config.dart';

void main() {
  // 方式一：使用枚举
  EnvConfig.init(Environment.dev);      // 开发环境
  // EnvConfig.init(Environment.staging); // 测试环境
  // EnvConfig.init(Environment.prod);    // 生产环境

  // 方式二：使用字符串
  // EnvConfig.initFromString('production');

  runApp(MyApp());
}
```

### 使用配置

```dart
import 'package:im_client/config/env_config.dart';

// 获取配置实例
final env = EnvConfig.instance;

// 常用属性
env.appName      // 应用名称
env.baseUrl      // API基础地址: http://127.0.0.1:8080
env.wsUrl        // WebSocket地址: ws://127.0.0.1:8080/ws
env.fullApiUrl   // 完整API地址: http://127.0.0.1:8080/api
env.timeout      // 请求超时时间 (毫秒)
env.enableLog    // 是否启用日志
env.enableDebug  // 是否启用调试

// 环境判断
if (env.isDev) {
  // 开发环境逻辑
}

// 获取文件完整URL
String avatarUrl = env.getFileUrl('/uploads/avatar.jpg');
// 返回: http://127.0.0.1:8080/uploads/avatar.jpg

// 打印配置 (仅调试模式)
env.printConfig();
```

### 修改生产环境配置

编辑 `lib/config/env_config.dart`:

```dart
static EnvConfig _prod() {
  return EnvConfig._(
    env: Environment.prod,
    appName: 'IM即时通讯',
    baseUrl: 'https://your-domain.com',      // 修改为实际域名
    wsUrl: 'wss://your-domain.com/ws',       // 修改为实际域名
    apiPrefix: '/api',
    timeout: 15000,
    enableLog: false,
    enableDebug: false,
  );
}
```

---

## 运行应用

### 开发环境运行

```bash
# 默认开发环境
flutter run

# 指定设备运行
flutter run -d chrome          # Web浏览器
flutter run -d android         # Android设备/模拟器
flutter run -d ios             # iOS设备/模拟器
flutter run -d windows         # Windows桌面
flutter run -d macos           # macOS桌面
flutter run -d linux           # Linux桌面

# 指定环境运行
flutter run --dart-define=ENV=dev       # 开发环境
flutter run --dart-define=ENV=staging   # 测试环境
flutter run --dart-define=ENV=prod      # 生产环境

# 热重载模式 (默认)
# 代码修改后按 r 键热重载
# 按 R 键热重启

# 详细日志输出
flutter run -v
```

### 连接真机调试

#### Android 真机

```bash
# 1. 手机开启开发者选项和USB调试
#    设置 -> 关于手机 -> 连续点击版本号7次
#    设置 -> 开发者选项 -> 开启USB调试

# 2. 连接手机，查看设备
flutter devices

# 3. 运行应用
flutter run -d <device_id>
```

#### iOS 真机 (仅 macOS)

```bash
# 1. 使用数据线连接 iPhone
# 2. 在 iPhone 上信任此电脑
# 3. 打开 Xcode -> Preferences -> Accounts
#    添加 Apple ID (需要开发者账号)

# 4. 配置签名
#    打开 ios/Runner.xcworkspace
#    选择 Runner -> Signing & Capabilities
#    选择 Team (你的开发者账号)

# 5. 运行
flutter run -d ios
```

### Android 模拟器 IP 访问

Android 模拟器访问本机服务需要使用特殊 IP：

```dart
// 在开发配置中
static EnvConfig _dev() {
  return EnvConfig._(
    // 对于 Android 模拟器，使用 10.0.2.2 访问本机
    // 对于真机和其他平台，使用 127.0.0.1 或本机局域网IP
    baseUrl: 'http://10.0.2.2:8080',  // Android模拟器
    // baseUrl: 'http://127.0.0.1:8080',  // Web/iOS模拟器
    // baseUrl: 'http://192.168.1.100:8080',  // 真机 (用本机局域网IP)
    wsUrl: 'ws://10.0.2.2:8080/ws',
    // ...
  );
}
```

---

## 编译发布

### Android APK 打包

#### 1. 配置签名

```bash
# 生成签名密钥 (首次)
keytool -genkey -v -keystore ~/im-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias im-key

# 按提示输入：
# - 密钥库密码
# - 您的姓名
# - 组织单位
# - 组织名称
# - 城市
# - 省份
# - 国家代码 (CN)
```

#### 2. 创建签名配置文件

创建 `android/key.properties`:

```properties
storePassword=你的密钥库密码
keyPassword=你的密钥密码
keyAlias=im-key
storeFile=/path/to/im-release-key.jks
```

**注意**：不要将 `key.properties` 和 `.jks` 文件提交到版本控制！

#### 3. 配置 Gradle

编辑 `android/app/build.gradle`:

```gradle
// 在 android { 之前添加
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    // ...

    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }
}
```

#### 4. 打包 APK

```bash
# Debug APK (用于测试)
flutter build apk --debug

# Release APK (正式版)
flutter build apk --release --dart-define=ENV=prod

# 分架构 APK (减小体积，推荐)
flutter build apk --split-per-abi --release --dart-define=ENV=prod

# 输出路径:
# build/app/outputs/flutter-apk/app-release.apk
# 或分架构:
# build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
# build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
# build/app/outputs/flutter-apk/app-x86_64-release.apk
```

#### 5. 打包 AAB (Google Play)

```bash
flutter build appbundle --release --dart-define=ENV=prod

# 输出路径:
# build/app/outputs/bundle/release/app-release.aab
```

### iOS IPA 打包 (仅 macOS)

#### 1. 配置证书和描述文件

```bash
# 1. 登录 Apple Developer 账号
#    https://developer.apple.com/

# 2. 创建 App ID
#    Certificates, Identifiers & Profiles -> Identifiers -> +
#    选择 App IDs -> 输入 Bundle ID (如: com.example.imclient)

# 3. 创建证书
#    Certificates -> + -> iOS Distribution (App Store and Ad Hoc)
#    下载并双击安装到钥匙串

# 4. 创建 Provisioning Profile
#    Profiles -> + -> App Store
#    选择 App ID 和证书
#    下载并双击安装
```

#### 2. Xcode 配置

```bash
# 打开 Xcode 项目
open ios/Runner.xcworkspace

# 在 Xcode 中:
# 1. 选择 Runner 项目
# 2. TARGETS -> Runner -> Signing & Capabilities
# 3. 取消 "Automatically manage signing"
# 4. 选择刚才创建的 Provisioning Profile
```

#### 3. 打包

```bash
# 构建 iOS 发布版
flutter build ios --release --dart-define=ENV=prod

# 在 Xcode 中归档:
# 1. Product -> Archive
# 2. 等待归档完成
# 3. 点击 Distribute App
# 4. 选择 App Store Connect (或 Ad Hoc/Enterprise)
# 5. 按提示完成上传
```

#### 4. 无 Xcode 导出 IPA

```bash
# 先 build
flutter build ios --release --dart-define=ENV=prod

# 使用 xcodebuild 归档
cd ios
xcodebuild -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -archivePath build/Runner.xcarchive \
  archive

# 导出 IPA
xcodebuild -exportArchive \
  -archivePath build/Runner.xcarchive \
  -exportPath build/ipa \
  -exportOptionsPlist ExportOptions.plist
```

### Web 打包

```bash
# 构建 Web 版本
flutter build web --release --dart-define=ENV=prod

# 使用 CanvasKit 渲染 (更好的兼容性)
flutter build web --release --web-renderer canvaskit --dart-define=ENV=prod

# 使用 HTML 渲染 (更小的体积)
flutter build web --release --web-renderer html --dart-define=ENV=prod

# 输出目录: build/web/
# 将 build/web/ 目录部署到 Web 服务器即可
```

### Windows 打包

```bash
# 构建 Windows 版本
flutter build windows --release --dart-define=ENV=prod

# 输出目录: build/windows/runner/Release/
# 整个 Release 目录就是可分发的应用
```

### macOS 打包

```bash
# 构建 macOS 版本
flutter build macos --release --dart-define=ENV=prod

# 输出路径: build/macos/Build/Products/Release/im_client.app
```

### Linux 打包

```bash
# 构建 Linux 版本
flutter build linux --release --dart-define=ENV=prod

# 输出目录: build/linux/x64/release/bundle/
```

---

## Nginx部署配置

### Web 版本部署

#### 基础配置

```nginx
# /etc/nginx/sites-available/im-client
server {
    listen 80;
    server_name im.example.com;

    # Web 应用根目录
    root /var/www/im-client;
    index index.html;

    # 启用 gzip 压缩
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/javascript application/javascript application/json application/wasm;

    # 静态资源缓存
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Flutter Web ServiceWorker
    location /flutter_service_worker.js {
        add_header Cache-Control "no-cache";
    }

    # 主页面不缓存 (确保更新及时)
    location = /index.html {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    # SPA 路由支持
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API 代理 (如果需要)
    location /api/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket 代理
    location /ws {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
}
```

#### HTTPS 配置

```nginx
# /etc/nginx/sites-available/im-client-ssl
server {
    listen 80;
    server_name im.example.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name im.example.com;

    # SSL 证书
    ssl_certificate /etc/letsencrypt/live/im.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/im.example.com/privkey.pem;

    # SSL 配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;

    # HSTS
    add_header Strict-Transport-Security "max-age=31536000" always;

    # Web 应用配置
    root /var/www/im-client;
    index index.html;

    # gzip 压缩
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/javascript application/javascript application/json application/wasm;

    # 静态资源缓存
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    location /flutter_service_worker.js {
        add_header Cache-Control "no-cache";
    }

    location = /index.html {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    location / {
        try_files $uri $uri/ /index.html;
    }

    # API 代理
    location /api/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket 代理 (使用 wss)
    location /ws {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
}
```

#### 部署步骤

```bash
# 1. 打包 Web 版本
flutter build web --release --dart-define=ENV=prod

# 2. 上传到服务器
scp -r build/web/* user@server:/var/www/im-client/

# 3. 配置 Nginx
sudo ln -s /etc/nginx/sites-available/im-client /etc/nginx/sites-enabled/

# 4. 测试配置
sudo nginx -t

# 5. 重载 Nginx
sudo systemctl reload nginx

# 6. 配置 SSL (使用 Certbot)
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d im.example.com
```

---

## 国际化

### 支持的语言

| 语言 | Locale | 标识 |
|------|--------|------|
| 简体中文 | zh_CN | `_zhCNStrings` |
| 繁体中文 | zh_TW | `_zhTWStrings` |
| English | en_US | `_enStrings` |
| Français | fr_FR | `_frStrings` |
| हिन्दी | hi_IN | `_hiStrings` |

### 使用翻译

```dart
import 'package:im_client/l10n/app_localizations.dart';

@override
Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;

  return Scaffold(
    appBar: AppBar(title: Text(l10n.messages)),
    body: Column(
      children: [
        Text(l10n.login),
        Text(l10n.contacts),
        ElevatedButton(
          onPressed: () {},
          child: Text(l10n.confirm),
        ),
      ],
    ),
  );
}
```

### 切换语言

```dart
import 'package:im_client/providers/locale_provider.dart';

// 切换到简体中文
context.read<LocaleProvider>().setSimplifiedChinese();

// 切换到繁体中文
context.read<LocaleProvider>().setTraditionalChinese();

// 切换到英语
context.read<LocaleProvider>().setEnglish();

// 切换到法语
context.read<LocaleProvider>().setFrench();

// 切换到印地语
context.read<LocaleProvider>().setHindi();

// 自定义 Locale
context.read<LocaleProvider>().setLocale(const Locale('ja', 'JP'));
```

### 添加新翻译

1. 在 `app_localizations.dart` 中添加 getter:

```dart
String get newKey => translate('new_key');
```

2. 在各语言 Map 中添加翻译:

```dart
const Map<String, String> _zhCNStrings = {
  // ...
  'new_key': '新文本',
};

const Map<String, String> _enStrings = {
  // ...
  'new_key': 'New Text',
};
```

---

## 状态管理

使用 Provider 进行状态管理：

```dart
// 监听认证状态
Consumer<AuthProvider>(
  builder: (context, auth, _) {
    if (auth.isAuthenticated) {
      return HomeScreen();
    }
    return LoginScreen();
  },
)

// 读取状态 (不监听变化)
final user = context.read<AuthProvider>().user;

// 监听变化
final isLoggedIn = context.watch<AuthProvider>().isAuthenticated;
```

---

## 网络请求

### API 调用

```dart
import 'package:im_client/api/api_client.dart';

final api = ApiClient();

// GET 请求
final response = await api.get('/users/profile');
if (response.success) {
  final data = response.data;
}

// POST 请求
final response = await api.post('/messages/send', data: {
  'to_user_id': 123,
  'content': 'Hello!',
});
```

### WebSocket

```dart
import 'package:im_client/services/websocket_service.dart';

final ws = WebSocketService();

// 连接
await ws.connect(token);

// 监听消息
ws.messageStream.listen((message) {
  print('收到消息: $message');
});

// 发送消息
ws.sendChatMessage(
  toUserId: 123,
  type: 1,
  content: 'Hello!',
);

// 断开连接
ws.disconnect();
```

---

## 常见问题

### 1. flutter doctor 报错

**问题**：Android toolchain 报错

```bash
# 解决方案
flutter doctor --android-licenses
# 按 y 同意所有许可
```

**问题**：cmdline-tools component is missing

```bash
# 打开 Android Studio
# SDK Manager -> SDK Tools -> 勾选 Android SDK Command-line Tools
# 点击 Apply 安装
```

### 2. 依赖安装失败

**问题**：pub get 失败

```bash
# 清除缓存重试
flutter clean
flutter pub cache repair
flutter pub get
```

**问题**：国内网络问题

```bash
# 设置国内镜像
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
flutter pub get
```

### 3. iOS 构建失败

**问题**：CocoaPods 相关错误

```bash
cd ios
pod deintegrate
pod cache clean --all
pod install
cd ..
flutter clean
flutter pub get
flutter run -d ios
```

**问题**：签名错误

```
1. 打开 Xcode
2. Runner -> Signing & Capabilities
3. 选择正确的 Team
4. 确保 Bundle Identifier 唯一
```

### 4. Android 构建失败

**问题**：Gradle 构建失败

```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run -d android
```

**问题**：SDK 版本不匹配

```gradle
// 修改 android/app/build.gradle
android {
    compileSdkVersion 34
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
}
```

### 5. Web 运行问题

**问题**：跨域 (CORS) 错误

```
开发时在服务端配置 CORS:
Access-Control-Allow-Origin: *
或使用 --web-browser-flag="--disable-web-security" 启动 Chrome
```

**问题**：WebSocket 连接失败

```
检查 wsUrl 配置是否正确
检查服务端 WebSocket 是否正常运行
检查是否需要使用 wss (HTTPS 环境)
```

### 6. 热重载不生效

```bash
# 尝试热重启
# 在运行的终端中按 R (大写)

# 或重新运行
flutter run
```

### 7. 模拟器无法访问本机服务

**Android 模拟器**:
```
使用 10.0.2.2 替代 127.0.0.1
```

**iOS 模拟器**:
```
可以直接使用 127.0.0.1
```

**真机**:
```
使用电脑的局域网 IP，如 192.168.1.100
确保手机和电脑在同一网络
```

---

## 依赖说明

主要依赖包：

| 包名 | 版本 | 用途 |
|------|------|------|
| provider | ^6.1.1 | 状态管理 |
| dio | ^5.4.0 | 网络请求 |
| web_socket_channel | ^2.4.0 | WebSocket |
| shared_preferences | ^2.2.2 | 本地存储 |
| cached_network_image | ^3.3.1 | 图片缓存 |
| flutter_webrtc | ^0.11.1 | 音视频通话 |

---

## 平台限制说明

### Web 平台

1. **sqflite 不支持 Web** - 使用 shared_preferences 替代
2. **文件选择** - 使用 file_picker 的 web 实现
3. **推送通知** - 使用 Firebase Cloud Messaging

### 性能优化建议

1. 使用 `const` 构造函数
2. 合理使用 `Consumer` 避免不必要的重建
3. 图片使用 `cached_network_image` 缓存
4. 列表使用 `ListView.builder` 懒加载
