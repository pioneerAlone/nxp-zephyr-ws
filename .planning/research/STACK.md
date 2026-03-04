# Technology Stack

**Project:** FCM363X Zephyr 移植
**Researched:** 2026-03-03

## Recommended Stack

### Core Framework
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **nxp-zsdk** | v4.3.0 | NXP Zephyr SDK | NXP 官方维护，针对 RW612 优化，提供完整 HAL 支持 |
| **Zephyr RTOS** | v4.3.0 | 实时操作系统内核 | 现代化 RTOS，设备树驱动模型，丰富的外设支持 |

### Build System
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **CMake** | 3.20+ | 构建配置管理 | Zephyr 官方构建系统，跨平台支持 |
| **west** | Latest | Zephyr 元工具 | 多仓库管理，依赖获取，构建命令封装 |
| **ninja** | Latest | 构建后端 | 快速增量构建，优于 Make |

### Toolchain
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **ARM GNU Toolchain** | 13.2.Rel1 | ARM Cortex-M33 交叉编译 | 官方推荐工具链，Zephyr 测试验证 |
| **Python** | 3.8+ | 构建脚本和依赖 | west 和构建系统依赖 |
| **Device Tree Compiler** | Latest | 设备树编译 | Zephyr 设备树驱动模型必需 |

### Development Environment (新增)
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **VSCode** | Latest | 集成开发环境 | 轻量级、跨平台、插件丰富 |
| **MCUXpresso for VS Code** | Latest | NXP 官方扩展 | 支持 Zephyr 项目构建、调试、SDK 管理 |
| **MCUXpresso Installer** | Latest | 自动安装工具 | 一键安装 Zephyr 开发环境 |
| **JLink** | Latest | 调试探针 | RW612 官方支持，JTAG 接口 |

### Hardware
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **NXP RW612** | RW612ETA2I | 无线 MCU 芯片 | ARM Cortex-M33 @ 260MHz，Wi-Fi 6 + BLE 5.3 |
| **Quectel FCM363X** | FCM363XABMD | Wi-Fi + BLE 模块 | 基于 RW612，1.2MB SRAM, 8MB Flash |

### Debugging
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **JLink** | Latest | 调试探针 | RW612 官方支持，JTAG 接口 |
| **VSCode** | Latest + MCUXpresso 扩展 | 开发环境 | 集成开发，调试，代码补全 |

### Supporting Libraries
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **lwIP** | 内置 | TCP/IP 协议栈 | 网络应用开发 |
| **mbedTLS** | 内置 | 加密库 | SSL/TLS，加密通信 |
| **PSA Crypto** | 内置 | PSA Crypto API | 安全应用，硬件加密加速 |
| **LVGL** | 内置 | 图形库 | 显示和 UI 开发 |
| **LittleFS** | 内置 | 文件系统 | Flash 文件存储 |

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| **SDK** | nxp-zsdk | 上游 Zephyr | nxp-zsdk 针对 NXP 芯片优化，提供完整 HAL 支持 |
| **构建工具** | ninja | Make | ninja 更快，是 Zephyr 默认推荐 |
| **工具链** | ARM GNU Toolchain | LLVM/Clang | ARM GNU 工具链更成熟，文档更完善 |
| **调试器** | JLink | OpenOCD | JLink 对 RW612 支持更好，NXP 官方推荐 |
| **IDE** | VSCode + MCUXpresso | Eclipse + MCUXPRESSO | VSCode 更轻量，MCUXpresso 扩展支持 Zephyr |
| **IDE 扩展** | MCUXpresso for VS Code | Zephyr IDE | MCUXpresso 提供 NXP 官方支持，集成 SDK 管理 |

## Development Environment Options (新增)

### Option A: MCUXpresso Installer + VSCode (推荐)

**一键安装方式：**
```bash
# 1. 下载并运行 MCUXpresso Installer
# https://www.nxp.com/mcuxpresso-installer

# 2. 选择 "Zephyr Developer" 安装选项
# 自动安装: Python, Git, West, ARM GCC, CMake, JLink

# 3. 安装 VS Code 和 MCUXpresso 扩展
code --install-extension NXPSemiconductors.mcuxpresso
```

**优点：**
- 自动配置环境
- NXP 官方支持
- 集成 SDK 下载和管理

### Option B: 手动安装 (高级用户)

```bash
# macOS
brew install cmake ninja python3 git

# 创建虚拟环境
python3 -m venv ~/zephyr_venv
source ~/zephyr_venv/bin/activate

# 安装 west
pip install west

# 初始化 nxp-zsdk
west init -m https://github.com/nxp-zephyr/nxp-zsdk.git --mr nxp-v4.3.0
west update

# 安装依赖
pip install -r zephyr/scripts/requirements.txt
```

## Installation

### 推荐方式：MCUXpresso Installer (新手友好)

```bash
# 1. 下载 MCUXpresso Installer
# https://www.nxp.com/design/design-center/software/development-software/mcuxpresso-software-and-tools-/mcuxpresso-installer:MCUXPRESSO-INSTALLER

# 2. 运行安装器，选择 "Zephyr Developer"
# 自动安装以下工具:
# - Python 3.x
# - Git
# - West (Zephyr 元工具)
# - ARM GNU Toolchain
# - CMake
# - Ninja
# - JLink (可选)

# 3. 安装 VS Code
# https://code.visualstudio.com/

# 4. 安装 MCUXpresso for VS Code 扩展
code --install-extension NXPSemiconductors.mcuxpresso

# 5. 使用 Quick Start Panel 获取 SDK
# VS Code → MCUXpresso → Quick Start → Get SDKs → nxp-zsdk
```

### macOS 手动安装

```bash
# 安装 ARM 工具链
# 从 https://developer.arm.com/downloads/-/gnu-rm 下载并安装

# 安装构建工具
brew install cmake ninja device-tree-compiler wget git python3

# 创建 Python 虚拟环境
python3 -m venv ~/zephyr_venv
source ~/zephyr_venv/bin/activate

# 安装 Python 依赖
pip install --upgrade pip
pip install west cmake ninja pyelftools pyyaml

# 安装 zephyr-ide 插件 (可选)
code --install-extension mylonics.zephyr-ide
```

### Linux (Ubuntu/Debian)

```bash
# 安装构建工具
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
    git cmake ninja-build gperf \
    ccache dfu-util device-tree-compiler wget \
    xz-utils file make gcc gcc-multilib g++-multilib libsdl2-dev \
    python3-dev python3-pip python3-setuptools python3-tk python3-wheel

# 创建 Python 虚拟环境
python3 -m venv ~/zephyr_venv
source ~/zephyr_venv/bin/activate

# 安装 Python 依赖
pip install --upgrade pip
pip install west cmake ninja pyelftools pyyaml
```

### 初始化工作区

```bash
# 创建工作区
mkdir -p ~/zephyr_ws
cd ~/zephyr_ws

# 初始化 nxp-zsdk
west init -m https://github.com/nxp-zephyr/nxp-zsdk.git --mr nxp-v4.3.0 nxp-zsdk
cd nxp-zsdk
west update
west zephyr-export

# 验证安装
west build -b frdm_rw612 -p always -- -DCONF_FILE=prj.conf
```

## Sources

### 官方文档 (HIGH confidence)
- nxp-zsdk GitHub: https://github.com/nxp-zephyr/nxp-zsdk
- Zephyr 官方文档: https://docs.zephyrproject.org
- FRDM-RW612 Zephyr 文档: https://docs.zephyrproject.org/latest/boards/nxp/frdm_rw612/doc/index.html
- Board Support Status: https://github.com/nxp-zephyr/nxp-zsdk/blob/main/doc/releases/Board-Support-Status.md
- NXP Zephyr 入门指南: https://www.nxp.com/document/guide/getting-started-with-zephyr:GS-ZEPHYR

### 开发工具 (HIGH confidence)
- MCUXpresso for VS Code: https://www.nxp.com/design/design-center/software/embedded-software/mcuxpresso-for-visual-studio-code:MCUXPRESSO-VSC
- MCUXpresso Installer: https://www.nxp.com/design/design-center/software/development-software/mcuxpresso-software-and-tools-/mcuxpresso-installer:MCUXPRESSO-INSTALLER
- Zephyr IDE 插件: https://marketplace.visualstudio.com/items?itemName=mylonics.zephyr-ide

### 社区资源 (MEDIUM confidence)
- NXP Zephyr 博客: https://www.nxp.com/company/about-nxp/smarter-world-blog/BL-ZEPHYR-ENABLEMENT
- NXP Community Zephyr KB: https://community.nxp.com/t5/Zephyr-Project-Knowledge-Base/tkb-p/Zephyr-Project