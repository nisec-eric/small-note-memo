# Check In Memo - 打卡记录

简洁美观的跨平台打卡记录 App，支持 Android / Web。

## 功能

- **任务配置** — 自定义打卡任务，支持选择图标、重复日期（周几）、时间窗口
- **统计周期** — 支持「N天内打卡M次」的周期模式（如 7天打卡3次），也可设置每日打卡
- **单次打卡** — 非周期性事件快速记录，输入主题即可，支持历史主题选择和备注
- **一键打卡** — 今日任务卡片列表，点击即完成，带弹性动画反馈
- **撤销打卡** — 长按已打卡卡片可撤销
- **统计图表**
  - 本月打卡率进度条
  - 各任务连续打卡天数/周期数（Streak）
  - 月度热力图日历（可切换月份，点击查看当日详情）
  - 打卡历史（每日任务显示打卡日期，周期任务显示每个周期完成情况）
  - 单次记录（按主题聚合统计）
- **数据管理** — 导出/导入任务配置和打卡记录，支持选择是否包含打卡日志
- **深色模式** — 跟随系统自动切换
- **离线优先** — 数据全部本地存储（Hive），无需网络

## 技术栈

| 层面 | 技术 |
|---|---|
| 框架 | Flutter 3.38 |
| 语言 | Dart 3.10 |
| 状态管理 | Riverpod |
| 本地存储 | Hive |
| 图表 | fl_chart |
| 日期格式化 | intl |

## 项目结构

```
lib/
├── main.dart                    # 入口：Hive + intl 初始化
├── app.dart                     # MaterialApp3 主题 + 底部导航
├── models/
│   ├── task.dart                # CheckInTask 打卡任务模型
│   └── record.dart              # CheckInRecord 打卡记录模型
├── services/
│   └── storage_service.dart     # Hive 存储层（CRUD + 统计计算）
├── providers/
│   └── app_providers.dart       # Riverpod providers
├── pages/
│   ├── home_page.dart           # 今天 Tab
│   ├── stats_page.dart          # 统计 Tab
│   └── settings_page.dart       # 设置 Tab
└── widgets/
    ├── task_card.dart           # 任务卡片 + 打卡按钮
    └── heatmap_calendar.dart    # 月度热力图（含每日打卡计数）
```

## 环境搭建

### 前置条件

- macOS / Linux / Windows
- Flutter SDK >= 3.38（包含 Dart >= 3.10）
- JDK 17
- Android SDK（仅 Android 构建需要）

### 安装 Flutter SDK

```bash
# macOS (Homebrew)
brew install flutter

# 验证
flutter doctor
```

### 安装 Android SDK（仅 Android 构建需要）

如需构建 Android APK，需安装 Android SDK 命令行工具：

```bash
# 1. 创建 SDK 目录
mkdir -p ~/Library/Android/sdk/cmdline-tools

# 2. 下载 command-line tools (macOS)
cd /tmp
curl -O https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip
unzip commandlinetools-mac-*.zip
mv cmdline-tools ~/Library/Android/sdk/cmdline-tools/latest
rm -f commandlinetools-mac-*.zip

# 3. 安装编译组件
export ANDROID_HOME=~/Library/Android/sdk
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
yes | sdkmanager --licenses
sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0"

# 4. 写入环境变量（永久生效）
cat >> ~/.zshrc << 'EOF'
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH
EOF
source ~/.zshrc

# 5. 告知 Flutter SDK 位置
flutter config --android-sdk ~/Library/Android/sdk
```

> **注意**：Gradle 需要通过代理下载依赖。如果你的网络需要代理，在 `~/.gradle/gradle.properties` 中配置：
> ```
> systemProp.http.proxyHost=127.0.0.1
> systemProp.http.proxyPort=7897
> systemProp.https.proxyHost=127.0.0.1
> systemProp.https.proxyPort=7897
> ```

## 快速开始

### 安装依赖

```bash
git clone <repo-url>
cd small-note-memo
flutter pub get
```

### Web 运行（最快验证，无需 Android SDK）

**Chrome 调试模式：**

```bash
flutter run -d chrome
```

**构建后静态服务（无需 Chrome，任何浏览器可测）：**

```bash
flutter build web --release
npx serve build/web -l 8080
# 浏览器打开 http://localhost:8080
```

### Android 构建

```bash
# 编译 ARM64 APK（真机安装）
flutter build apk --release --target-platform android-arm64

# 编译产物
ls -lh build/app/outputs/flutter-apk/app-release.apk
```

### 安装到手机

**方式 A：USB 数据线**

```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

**方式 B：局域网下载**

```bash
cd build/app/outputs/flutter-apk
python3 -m http.server 9999
# 手机浏览器访问 http://<电脑局域网IP>:9999/app-release.apk
```

> 手机需开启「允许安装未知来源应用」。

## 界面说明

### 今天（首页）

展示今日需要打卡的任务列表，卡片包含：
- Emoji 图标 + 任务名称
- 时间窗口 + 重复规则
- 打卡按钮（点击完成，带弹性缩放动画）

### 统计

- 本月打卡率（进度条）
- 各任务连续天数/周期数 + 🔥 火焰标识
- 月度热力图（日历网格，颜色深浅表示打卡次数）
- 打卡历史（每日任务显示打卡日期列表，周期任务显示每个周期完成情况）

### 设置

- 打卡任务管理（增删改）
- 底部弹窗表单：名称、Emoji 图标选择、星期勾选、时间窗口、周期天数/目标配置
- 导出/导入数据（支持选择是否包含打卡记录）

## 配色

- 主色：`#FF6B6B`（珊瑚红）
- 辅助色：`#4ECDC4`（青绿）
- 任务卡片自动分配 8 色调色盘
- 支持 Material 3 深色/浅色模式自动切换

## License

MIT
