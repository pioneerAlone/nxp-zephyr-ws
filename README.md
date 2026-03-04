# FCM363X Zephyr Development Workspace

Quectel FCM363XABMD 模块的 Zephyr RTOS 开发工作区，基于 NXP RW612 芯片。

## 项目简介

本项目提供完整的 FCM363X Zephyr 开发环境：

- **nxp-zsdk**: NXP 官方 Zephyr SDK (v4.3.0)
- **fcm363x-board**: FCM363X 板级定义 (Out-of-Tree Board)
- **projects/**: 应用项目目录

### 目标硬件

| 参数 | 值 |
|------|-----|
| 模块 | Quectel FCM363XABMD |
| MCU | NXP RW612ETA2I (Cortex-M33 @ 260MHz) |
| Flash | 8MB (MX25L6433F) |
| SRAM | 1.2MB |
| 无线 | Wi-Fi 6 + BLE 5.3 |
| 调试 | JTAG |

## 目录结构

```
nxp-zephyr-ws/
├── .venv/              # Python 虚拟环境
├── .planning/          # GSD 规划文档
├── archives/           # 下载存档
├── fcm363x-board/      # Board 定义仓库
│   ├── boards/nxp/fcm363x/
│   └── west.yml
├── logs/               # 构建日志
├── nxp-zsdk/           # NXP Zephyr SDK
│   ├── zephyr/         # Zephyr 源码
│   └── modules/        # HAL 等模块
├── projects/           # 应用项目
│   └── hello/          # Hello World 示例
├── tools/              # 本地工具
├── setup_env.sh        # Unix/Linux/macOS 环境脚本
└── setup_env.bat       # Windows 启动脚本
```

## 快速开始

### 前置要求

| 工具 | 版本 | 安装方式 |
|------|------|---------|
| Git | 2.x | 系统包管理器 |
| Python | 3.10+ | 系统包管理器 |
| ARM GCC | 13.x | 可选 (SDK 内置) |
| JLink | 最新 | SEGGER 官网下载 |

### macOS / Linux

```bash
# 1. 克隆仓库
git clone <repo-url> nxp-zephyr-ws
cd nxp-zephyr-ws

# 2. 检查依赖
source setup_env.sh --check

# 3. 初始化 SDK (首次运行，约 15-30 分钟)
source setup_env.sh --init-sdk

# 4. 后续使用只需激活环境
source setup_env.sh

# 5. 构建项目
cd projects/hello
west build -b fcm363x
```

### Windows

**方法一：Git Bash (推荐)**

```cmd
# 双击运行 setup_env.bat
# 或在 Git Bash 中：
source setup_env.sh --init-sdk
```

**方法二：命令行**

```cmd
# 检查依赖
setup_env.bat --check

# 初始化 SDK
setup_env.bat --init-sdk
```

**激活环境 (Windows)**

```cmd
# CMD
call .venv\Scripts\activate.bat

# PowerShell
.venv\Scripts\Activate.ps1

# Git Bash
source .venv/Scripts/activate
```

## setup_env.sh 用法

| 命令 | 功能 |
|------|------|
| `source setup_env.sh` | 激活开发环境 |
| `source setup_env.sh --init-sdk` | 初始化 NXP Zephyr SDK |
| `source setup_env.sh --install` | 安装 JLink patch、blhost |
| `source setup_env.sh --list-versions` | 列出可用 SDK 版本 |
| `source setup_env.sh --check` | 仅检查依赖 |

### SDK 版本选择

```bash
# 使用默认版本 (nxp-v4.3.0)
source setup_env.sh --init-sdk

# 使用最新版本
SDK_VERSION=latest source setup_env.sh --init-sdk

# 指定版本
SDK_VERSION=nxp-v4.2.0 source setup_env.sh --init-sdk
```

## 构建示例

```bash
# 激活环境
source setup_env.sh

# 构建 Hello World
cd projects/hello
west build -b fcm363x

# 清理构建
west build -t clean

# 烧录 (需连接 JLink)
west flash
```

## 常见问题

### Q: Python 版本过低？

```bash
# macOS
brew install python@3.11

# Ubuntu
sudo apt install python3.11 python3.11-venv
```

### Q: west 命令找不到？

确保已激活虚拟环境：
```bash
source setup_env.sh
which west  # 应指向 .venv/bin/west
```

### Q: 构建找不到 board？

检查 `BOARD_ROOT` 是否设置：
```bash
echo $BOARD_ROOT
# 应输出: /path/to/nxp-zephyr-ws/fcm363x-board
```

## 许可证

Apache-2.0
