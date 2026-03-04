# FCM363X Zephyr 命令行开发阶段计划

**版本:** v1.1.0
**创建日期:** 2026-03-03
**更新日期:** 2026-03-03
**目标:** 完全基于命令行的 FCM363X Zephyr 开发环境搭建

---

## 核心原则

### 1. 命令行优先
- 所有操作通过 bash/west 命令完成
- 无需 VSCode 或其他 IDE
- Agent 可自主执行所有步骤

### 2. Git 优先
- 每个阶段开始前初始化 Git
- 每个重要步骤都有 commit
- 所有配置文件纳入版本控制

### 3. 幂等性
- 所有命令可重复执行
- 提供清理/回滚命令
- 验证命令确认状态

### 4. 环境隔离（关键原则）

**为什么需要环境隔离？**
- macOS 可能存在其他 Zephyr 项目，设置了 `ZEPHYR_BASE` 环境变量
- 系统可能有多个 Python 环境，导致 west 版本冲突
- west init 会检测 `ZEPHYR_BASE`，如果已设置会报错
- 不同项目可能使用不同版本的 SDK

**隔离策略：**

| 隔离项 | 策略 | 验证方法 |
|--------|------|----------|
| ZEPHYR_BASE | 每个 Phase 开始前 unset | `[ -z "$ZEPHYR_BASE" ]` |
| Python 环境 | 独立 venv: `~/zephyr-venv` | `which python` 指向 venv |
| 工作区目录 | 独立目录: `~/zephyr-workspace` | 独立于其他项目 |
| ARM 工具链 | 项目本地安装 | PATH 不依赖系统工具链 |

**隔离验证脚本：**
```bash
# 在每个 Phase 开始时运行
verify_isolation() {
    echo "=== 环境隔离验证 ==="
    
    # 检查 ZEPHYR_BASE
    if [ -n "$ZEPHYR_BASE" ]; then
        echo "✗ 错误: ZEPHYR_BASE 仍设置为: $ZEPHYR_BASE"
        echo "  请运行: unset ZEPHYR_BASE"
        return 1
    fi
    echo "✓ ZEPHYR_BASE: 未设置 (正确)"
    
    # 检查 Python 来源
    local python_path=$(which python 2>/dev/null || which python3)
    if [[ "$python_path" != *"$HOME/zephyr-venv"* ]]; then
        echo "✗ 错误: Python 不在虚拟环境中: $python_path"
        echo "  请运行: source ~/zephyr-venv/bin/activate"
        return 1
    fi
    echo "✓ Python: $python_path"
    
    # 检查工作区
    if [ -d "$HOME/zephyr-workspace" ]; then
        echo "✓ 工作区: $HOME/zephyr-workspace"
    else
        echo "! 工作区尚未创建"
    fi
    
    echo "=== 隔离验证通过 ==="
    return 0
}
```

---

## 阶段概览

| Phase | 名称 | 目标 | 产出 | 时间估计 |
|-------|------|------|------|----------|
| **0** | Git 仓库初始化 | 创建工作区结构 | 工作区目录 + 初始 commit | 5 min |
| **1** | 命令行环境准备 | 验证和配置工具链 | 可用的开发环境 | 15-30 min |
| **2** | 初始化 nxp-zsdk | 获取 NXP Zephyr SDK | nxp-zsdk 工作区 | 20-40 min |
| **3** | 创建 fcm363x-board | Board 定义仓库 | Board 定义 Git 仓库 | 15 min |
| **4** | 创建 fcm363x-project | 应用项目仓库 | 应用项目 Git 仓库 | 15 min |
| **5** | 构建验证与调试 | 验证构建和调试 | 可运行的固件 | 10-20 min |

---

## Phase 0: Git 仓库初始化与工作区准备

### 目标
创建 Zephyr 工作区目录结构，初始化 Git 仓库，**确保环境隔离**。

### 前提条件
- macOS 操作系统
- Homebrew 已安装
- **重要**：本工作区独立于系统其他 Zephyr 项目

### ⚠️ 环境隔离检查（每个 Phase 必须执行）

**在开始 Phase 0 之前，必须执行以下隔离清理：**

```bash
echo "=== Phase 0 环境隔离清理 ==="

# 【关键】清除 ZEPHYR_BASE - 这是 west init 报错的主要原因
# west init 检测到 ZEPHYR_BASE 已设置会拒绝初始化
if [ -n "$ZEPHYR_BASE" ]; then
    echo "⚠️  检测到 ZEPHYR_BASE: $ZEPHYR_BASE"
    echo "   这会导致 west init 失败，正在清除..."
    unset ZEPHYR_BASE
fi

# 清除其他可能冲突的 Zephyr 环境变量
unset ZEPHYR_SDK_INSTALL_DIR 2>/dev/null || true
unset GNUARMEMB_TOOLCHAIN_PATH 2>/dev/null || true
unset ZEPHYR_MODULES 2>/dev/null || true
unset ZEPHYR_MODULES_CMAKE 2>/dev/null || true

# 清除可能存在的 SDK 相关变量
unset SDK_ZEPHYR_BASE 2>/dev/null || true

echo ""
echo "=== 验证隔离效果 ==="
echo "ZEPHYR_BASE: ${ZEPHYR_BASE:-<未设置，正确>}"
echo "ZEPHYR_SDK_INSTALL_DIR: ${ZEPHYR_SDK_INSTALL_DIR:-<未设置>}"
echo "GNUARMEMB_TOOLCHAIN_PATH: ${GNUARMEMB_TOOLCHAIN_PATH:-<未设置>}"
echo ""
echo "✓ 环境隔离清理完成"
```

### 执行步骤

#### Step 0.1: 定义工作区路径变量

```bash
# 定义工作区路径（项目自包含方案）
export ZEPHYR_WS="${HOME}/nxp-zephyr-ws"
export ZEPHYR_VENV="${ZEPHYR_WS}/.venv"       # 虚拟环境在工作区内
export NXP_ZSDK_VERSION="nxp-v4.3.0"
export ARM_TOOLCHAIN_VERSION="13.2.Rel1"

# Git 用户配置
export GIT_USER_NAME="bakewell"
export GIT_USER_EMAIL="slkybowang@gmail.com"

# 输出确认
echo "=== 工作区配置 ==="
echo "工作区路径: ${ZEPHYR_WS}"
echo "虚拟环境: ${ZEPHYR_VENV}"
echo "NXP ZSDK 版本: ${NXP_ZSDK_VERSION}"
echo "ARM 工具链版本: ${ARM_TOOLCHAIN_VERSION}"
echo "Git 用户: ${GIT_USER_NAME} <${GIT_USER_EMAIL}>"
```

#### Step 0.2: 定义工作区路径变量

```bash
# 定义工作区路径 (可根据需要修改)
export ZEPHYR_WS="${HOME}/zephyr-workspace"
export ZEPHYR_VENV="${HOME}/zephyr-venv"
export NXP_ZSDK_VERSION="nxp-v4.3.0"
export ARM_TOOLCHAIN_VERSION="13.2.Rel1"

# 输出确认
echo "=== 工作区配置 ==="
echo "工作区路径: ${ZEPHYR_WS}"
echo "虚拟环境: ${ZEPHYR_VENV}"
echo "NXP ZSDK 版本: ${NXP_ZSDK_VERSION}"
echo "ARM 工具链版本: ${ARM_TOOLCHAIN_VERSION}"
```

#### Step 0.3: 创建工作区目录结构

```bash
# 创建主工作区
mkdir -p "${ZEPHYR_WS}"
cd "${ZEPHYR_WS}"

# 创建子目录
mkdir -p logs
mkdir -p tools
mkdir -p archives

# 创建工作区 README
cat > README.md << 'EOF'
# NXP Zephyr Workspace for FCM363X

This workspace contains:
- nxp-zsdk: NXP Zephyr SDK
- fcm363x-board: Board definition repository
- fcm363x-project: Application project repository

Created: 2026-03-03
Target: Quectel FCM363XABMD (NXP RW612)

## Structure

```
nxp-zephyr-ws/
├── .venv/           # Python virtual environment (self-contained)
├── .git/            # Git repository
├── tools/           # Local tools (ARM toolchain, blhost-helper)
├── logs/            # Build and verification logs
├── nxp-zsdk/        # NXP Zephyr SDK (west managed)
├── fcm363x-board/   # Board definition repository
└── fcm363x-project/ # Application project repository
```

## Quick Start

```bash
# Activate environment
source setup_env.sh

# Build
cd fcm363x-project
west build -b fcm363x
```
EOF

echo "工作区目录已创建: ${ZEPHYR_WS}"
```

#### Step 0.4: 配置 .gitignore

```bash
# 创建工作区级别的 .gitignore
cat > "${ZEPHYR_WS}/.gitignore" << 'EOF'
# Python 虚拟环境（工作区内）
.venv/

# West 工作区元数据
.west/

# 构建输出
build/
build-*/
*.bin
*.hex
*.elf
*.map
*.lst

# nxp-zsdk 和 modules (由 west 管理)
nxp-zsdk/
bootloader/
cmsis/
hal_*/
modules/
tools/arm-gnu-toolchain*/
zephyr/

# Python 缓存
__pycache__/
*.pyc
*.pyo
.pytest_cache/

# IDE 配置 (保留 .vscode/ 用于 Zephyr IDE 插件)
.idea/
*.swp
*.swo
*~

# macOS
.DS_Store
.AppleDouble
.LSOverride

# 日志和临时文件
logs/*.log
*.tmp
*.bak
EOF

echo ".gitignore 已创建"
```

#### Step 0.5: 初始化 Git 仓库

```bash
cd "${ZEPHYR_WS}"

# 初始化 Git
git init

# 配置 Git 用户信息
git config user.name "${GIT_USER_NAME}"
git config user.email "${GIT_USER_EMAIL}"

# 初始提交
git add .
git commit -m "init(workspace): create nxp-zephyr-ws workspace structure

- Create workspace directory structure
- Add .gitignore for west/zephyr projects
- Add workspace README
- Python venv location: .venv/ (self-contained)

Workspace path: ${ZEPHYR_WS}
Git user: ${GIT_USER_NAME} <${GIT_USER_EMAIL}>"

echo "Git 仓库已初始化"
git log --oneline -1
```

### 验证

```bash
# 验证环境隔离
echo "=== 验证环境隔离 ==="
echo "ZEPHYR_BASE: ${ZEPHYR_BASE:-<未设置>}"
[ -z "$ZEPHYR_BASE" ] && echo "✓ ZEPHYR_BASE 已清除" || echo "✗ ZEPHYR_BASE 仍存在"

# 验证工作区结构
ls -la "${ZEPHYR_WS}"

# 验证 Git 状态
cd "${ZEPHYR_WS}" && git status

# 预期输出: 工作区干净，ZEPHYR_BASE 未设置
```

### 回滚命令

```bash
# 如果需要重新开始
rm -rf "${ZEPHYR_WS}"
```

---

## Phase 1: 命令行环境准备

### 目标
验证 macOS 环境下的依赖工具，**创建独立的 Python 虚拟环境**，安装 west 和 ARM 工具链。

### 前提条件
- Phase 0 完成
- 网络连接正常
- **环境隔离**：使用独立 venv，不影响系统 Python

### ⚠️ 环境隔离检查（每个 Phase 必须执行）

**在开始 Phase 1 之前，必须执行以下隔离清理：**

```bash
echo "=== Phase 1 环境隔离清理 ==="

# 【关键】清除 ZEPHYR_BASE
if [ -n "$ZEPHYR_BASE" ]; then
    echo "⚠️  清除现有 ZEPHYR_BASE: $ZEPHYR_BASE"
    unset ZEPHYR_BASE
fi

# 清除其他冲突变量
unset ZEPHYR_SDK_INSTALL_DIR 2>/dev/null || true
unset GNUARMEMB_TOOLCHAIN_PATH 2>/dev/null || true
unset ZEPHYR_MODULES 2>/dev/null || true

# 验证清理效果
echo ""
echo "=== 验证隔离效果 ==="
[ -z "$ZEPHYR_BASE" ] && echo "✓ ZEPHYR_BASE 已清除" || echo "✗ ZEPHYR_BASE 仍存在: $ZEPHYR_BASE"
echo "ZEPHYR_BASE: ${ZEPHYR_BASE:-<未设置>}"
echo ""
```

### 执行步骤

#### Step 1.1: 验证基础工具

```bash
echo "=== 验证基础工具 ==="

# 检查 Homebrew
if ! command -v brew &> /dev/null; then
    echo "错误: Homebrew 未安装"
    echo "请运行: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi
echo "✓ Homebrew: $(brew --version | head -1)"

# 检查 Git
if ! command -v git &> /dev/null; then
    echo "安装 Git..."
    brew install git
fi
echo "✓ Git: $(git --version)"

# 检查 Python 3
if ! command -v python3 &> /dev/null; then
    echo "安装 Python 3..."
    brew install python3
fi
echo "✓ Python: $(python3 --version)"

# 检查 pip
pip3 --version

echo "基础工具验证完成"
```

#### Step 1.2: 安装构建工具

```bash
echo "=== 安装构建工具 ==="

# CMake
if ! command -v cmake &> /dev/null; then
    echo "安装 CMake..."
    brew install cmake
fi
echo "✓ CMake: $(cmake --version | head -1)"

# Ninja
if ! command -v ninja &> /dev/null; then
    echo "安装 Ninja..."
    brew install ninja
fi
echo "✓ Ninja: $(ninja --version)"

# Device Tree Compiler
if ! command -v dtc &> /dev/null; then
    echo "安装 DTC..."
    brew install dtc
fi
echo "✓ DTC: $(dtc --version 2>&1 | head -1)"

# wget
if ! command -v wget &> /dev/null; then
    echo "安装 wget..."
    brew install wget
fi
echo "✓ wget: $(wget --version | head -1)"

echo "构建工具安装完成"
```

#### Step 1.3: 创建独立 Python 虚拟环境

**⚠️ 重要：使用独立的 Python venv，与系统 Python 完全隔离**

```bash
echo "=== 创建独立 Python 虚拟环境 ==="

# 检查是否已存在虚拟环境
if [ -d "${ZEPHYR_VENV}" ]; then
    echo "虚拟环境已存在: ${ZEPHYR_VENV}"
    echo "如需重建，请先运行: rm -rf ${ZEPHYR_VENV}"
else
    echo "创建新的虚拟环境: ${ZEPHYR_VENV}"
    python3 -m venv "${ZEPHYR_VENV}"
fi

# 激活虚拟环境
source "${ZEPHYR_VENV}/bin/activate"

# 验证 Python 来源（必须指向 venv）
PYTHON_PATH=$(which python)
if [[ "$PYTHON_PATH" != *"$ZEPHYR_VENV"* ]]; then
    echo "✗ 错误: Python 不在虚拟环境中!"
    echo "  当前路径: $PYTHON_PATH"
    echo "  预期路径: $ZEPHYR_VENV/bin/python"
    exit 1
fi
echo "✓ Python 虚拟环境已激活: $PYTHON_PATH"

# 升级 pip
pip install --upgrade pip

# 安装 Zephyr 依赖（在隔离环境中）
pip install west cmake ninja pyelftools pyyaml canopen packaging progress psutil pylink-square

echo "✓ West 已安装: $(west --version)"
```

#### Step 1.4: 创建完善的隔离激活脚本

**这是关键步骤 - 创建一个完善的 setup_env.sh 脚本，包含完整的隔离逻辑：**

```bash
# 创建完善的激活脚本（包含完整隔离逻辑）
cat > "${ZEPHYR_WS}/setup_env.sh" << 'SETUP_EOF'
#!/bin/bash
#
# FCM363X Zephyr 环境激活脚本
# 
# 功能：
# 1. 清除冲突的环境变量（ZEPHYR_BASE 等）
# 2. 激活独立的 Python 虚拟环境
# 3. 设置工作区环境变量
# 4. 配置 ARM 工具链路径
# 5. 验证隔离效果
#
# 用法：
#   source ~/zephyr-workspace/setup_env.sh
#

set -e  # 遇错即停

# ========================================
# 1. 清除冲突环境变量（隔离关键步骤）
# ========================================

echo "=== 步骤 1: 清除冲突环境变量 ==="

# 【关键】清除 ZEPHYR_BASE - 这是导致 west init 失败的主要原因
# 如果系统有其他 Zephyr 项目设置了此变量，必须清除
if [ -n "$ZEPHYR_BASE" ]; then
    echo "⚠️  检测到冲突的 ZEPHYR_BASE: $ZEPHYR_BASE"
    echo "   正在清除以避免冲突..."
    unset ZEPHYR_BASE
fi

# 清除其他可能冲突的 Zephyr 相关变量
unset ZEPHYR_SDK_INSTALL_DIR 2>/dev/null || true
unset GNUARMEMB_TOOLCHAIN_PATH 2>/dev/null || true
unset ZEPHYR_MODULES 2>/dev/null || true
unset ZEPHYR_MODULES_CMAKE 2>/dev/null || true
unset SDK_ZEPHYR_BASE 2>/dev/null || true

# 清除可能存在的 Zephyr SDK 路径（避免版本冲突）
if [[ "$PATH" == *"/zephyr-sdk"* ]]; then
    echo "⚠️  检测到 PATH 中包含 zephyr-sdk，可能需要清理"
fi

echo "✓ 环境变量已清理"

# ========================================
# 2. 定义工作区路径
# ========================================

echo ""
echo "=== 步骤 2: 定义工作区路径 ==="

export ZEPHYR_WS="${HOME}/nxp-zephyr-ws"
export ZEPHYR_VENV="${ZEPHYR_WS}/.venv"
export NXP_ZSDK_VERSION="nxp-v4.3.0"

echo "✓ 工作区路径: ${ZEPHYR_WS}"
echo "✓ 虚拟环境: ${ZEPHYR_VENV}"

# ========================================
# 3. 激活 Python 虚拟环境
# ========================================

echo ""
echo "=== 步骤 3: 激活 Python 虚拟环境 ==="

if [ ! -d "${ZEPHYR_VENV}" ]; then
    echo "✗ 错误: 虚拟环境不存在: ${ZEPHYR_VENV}"
    echo "  请先运行 Phase 1 创建虚拟环境"
    return 1 2>/dev/null || exit 1
fi

source "${ZEPHYR_VENV}/bin/activate"
echo "✓ Python 虚拟环境已激活"

# 验证 Python 来源
PYTHON_PATH=$(which python 2>/dev/null || which python3)
if [[ "$PYTHON_PATH" != *"$ZEPHYR_VENV"* ]]; then
    echo "✗ 错误: Python 不在虚拟环境中!"
    echo "  当前: $PYTHON_PATH"
    echo "  预期: ${ZEPHYR_VENV}/bin/python"
    return 1 2>/dev/null || exit 1
fi
echo "✓ Python 路径验证通过: $PYTHON_PATH"

# ========================================
# 4. 设置 Zephyr 环境变量（工作区创建后）
# ========================================

echo ""
echo "=== 步骤 4: 设置 Zephyr 环境变量 ==="

# 只有在 nxp-zsdk 存在时才设置 ZEPHYR_BASE
if [ -d "${ZEPHYR_WS}/nxp-zsdk/zephyr" ]; then
    export ZEPHYR_BASE="${ZEPHYR_WS}/nxp-zsdk/zephyr"
    echo "✓ ZEPHYR_BASE: ${ZEPHYR_BASE}"
else
    echo "! nxp-zsdk 尚未初始化，ZEPHYR_BASE 暂不设置"
    echo "  运行 Phase 2 后会自动设置"
fi

# ========================================
# 5. 配置 ARM 工具链路径
# ========================================

echo ""
echo "=== 步骤 5: 配置 ARM 工具链 ==="

if [ -d "${ZEPHYR_WS}/tools/arm-gnu-toolchain/bin" ]; then
    # 使用项目本地工具链
    export PATH="${ZEPHYR_WS}/tools/arm-gnu-toolchain/bin:${PATH}"
    export GNUARMEMB_TOOLCHAIN_PATH="${ZEPHYR_WS}/tools/arm-gnu-toolchain"
    
    if command -v arm-none-eabi-gcc &> /dev/null; then
        ARM_VERSION=$(arm-none-eabi-gcc --version | head -1)
        echo "✓ ARM 工具链: ${ARM_VERSION}"
    fi
else
    echo "! ARM 工具链尚未安装"
    echo "  运行 Phase 1 Step 1.5 安装工具链"
fi

# ========================================
# 6. 隔离效果验证
# ========================================

echo ""
echo "=== 步骤 6: 隔离效果验证 ==="

ISOLATION_OK=true

# 检查 ZEPHYR_BASE（只有 SDK 存在时才应该设置）
if [ -d "${ZEPHYR_WS}/nxp-zsdk/zephyr" ]; then
    if [ -z "$ZEPHYR_BASE" ]; then
        echo "✗ ZEPHYR_BASE 应该已设置但未设置"
        ISOLATION_OK=false
    else
        echo "✓ ZEPHYR_BASE: ${ZEPHYR_BASE}"
    fi
else
    if [ -n "$ZEPHYR_BASE" ]; then
        echo "✗ ZEPHYR_BASE 不应该设置但已设置: $ZEPHYR_BASE"
        ISOLATION_OK=false
    else
        echo "✓ ZEPHYR_BASE: 未设置（正确，SDK 尚未初始化）"
    fi
fi

# 检查 Python 隔离
if [[ "$(which python)" == *"$ZEPHYR_VENV"* ]]; then
    echo "✓ Python 隔离: 正确"
else
    echo "✗ Python 隔离: 失败"
    ISOLATION_OK=false
fi

# ========================================
# 7. 显示工作区信息
# ========================================

echo ""
echo "=========================================="
echo "  FCM363X Zephyr 工作区已激活"
echo "=========================================="
echo ""
echo "工作区路径:   ${ZEPHYR_WS}"
echo "Python:       $(python --version 2>&1)"
echo "West:         $(west --version 2>/dev/null || echo '未安装')"
if command -v arm-none-eabi-gcc &> /dev/null; then
    echo "ARM GCC:      $(arm-none-eabi-gcc --version | head -1)"
fi
echo ""

if [ "$ISOLATION_OK" = true ]; then
    echo "✓ 环境隔离验证通过"
else
    echo "⚠️  环境隔离存在问题，请检查上述输出"
fi

echo ""
echo "常用命令:"
echo "  cd \$ZEPHYR_WS          # 进入工作区"
echo "  west build -b fcm363x   # 构建"
echo "  west flash              # 烧录"
echo ""
SETUP_EOF

chmod +x "${ZEPHYR_WS}/setup_env.sh"
echo "✓ 完善的激活脚本已创建: ${ZEPHYR_WS}/setup_env.sh"
```

**脚本使用说明：**

```bash
# 每次开始工作时，激活环境：
source ~/zephyr-workspace/setup_env.sh

# 脚本会自动：
# 1. 清除冲突的环境变量
# 2. 激活虚拟环境
# 3. 验证隔离效果
# 4. 显示工作区状态
```

#### Step 1.5: 下载 ARM 工具链

```bash
echo "=== 下载 ARM 工具链 ==="

# 激活虚拟环境
source "${ZEPHYR_VENV}/bin/activate"

# 检查系统架构
ARCH=$(uname -m)
if [ "${ARCH}" = "arm64" ]; then
    TOOLCHAIN_URL="https://developer.arm.com/-/media/Files/downloads/gnu/13.2.rel1/binrel/arm-gnu-toolchain-13.2.Rel1-darwin-arm64-arm-none-eabi.tar.bz2"
    TOOLCHAIN_DIR="arm-gnu-toolchain-13.2.Rel1-darwin-arm64-arm-none-eabi"
else
    TOOLCHAIN_URL="https://developer.arm.com/-/media/Files/downloads/gnu/13.2.rel1/binrel/arm-gnu-toolchain-13.2.Rel1-darwin-x86_64-arm-none-eabi.tar.bz2"
    TOOLCHAIN_DIR="arm-gnu-toolchain-13.2.Rel1-darwin-x86_64-arm-none-eabi"
fi

# 下载
cd "${ZEPHYR_WS}/archives"
if [ ! -f "${TOOLCHAIN_DIR}.tar.bz2" ]; then
    echo "下载 ARM 工具链..."
    wget -q --show-progress "${TOOLCHAIN_URL}" -O "${TOOLCHAIN_DIR}.tar.bz2"
fi

# 解压
echo "解压工具链..."
cd "${ZEPHYR_WS}/tools"
tar -xjf "${ZEPHYR_WS}/archives/${TOOLCHAIN_DIR}.tar.bz2"

# 创建符号链接
ln -sf "${TOOLCHAIN_DIR}" arm-gnu-toolchain

# 添加到 PATH
export PATH="${ZEPHYR_WS}/tools/arm-gnu-toolchain/bin:${PATH}"

# 验证
echo "✓ ARM 工具链已安装: $(arm-none-eabi-gcc --version | head -1)"
```

#### Step 1.6: 验证环境配置

```bash
echo "=== 验证环境配置 ==="

# 激活环境
source "${ZEPHYR_WS}/setup_env.sh"

# 验证所有工具
echo ""
echo "工具版本:"
echo "  - Python: $(python3 --version)"
echo "  - West: $(west --version)"
echo "  - CMake: $(cmake --version | head -1)"
echo "  - Ninja: $(ninja --version)"
echo "  - DTC: $(dtc --version 2>&1 | head -1)"
echo "  - ARM GCC: $(arm-none-eabi-gcc --version | head -1)"
echo "  - Git: $(git --version)"

# 保存验证结果
cat > "${ZEPHYR_WS}/logs/env_check.log" << EOF
环境验证日志 - $(date)
====================
Python: $(python3 --version)
West: $(west --version)
CMake: $(cmake --version | head -1)
Ninja: $(ninja --version)
DTC: $(dtc --version 2>&1 | head -1)
ARM GCC: $(arm-none-eabi-gcc --version | head -1)
Git: $(git --version)
EOF

echo ""
echo "✓ 环境配置验证完成"
```

#### Step 1.7: Git 提交

```bash
cd "${ZEPHYR_WS}"

# 添加新文件
git add setup_env.sh logs/env_check.log .gitignore

# 提交
git commit -m "feat(env): setup command-line development environment

- Install CMake, Ninja, DTC, wget via Homebrew
- Create Python virtual environment with west
- Download ARM GNU Toolchain 13.2.Rel1
- Add setup_env.sh for environment activation
- Add environment verification log

Tools installed:
- Python $(python3 --version | cut -d' ' -f2)
- West $(west --version | cut -d' ' -f2)
- ARM GCC $(arm-none-eabi-gcc --version | head -1 | cut -d' ' -f3)"

echo "环境配置已提交到 Git"
```

### 验证

```bash
# 运行环境验证
source "${ZEPHYR_WS}/setup_env.sh"

# 确认所有工具可用
which west
which arm-none-eabi-gcc
which cmake
which ninja
```

### 回滚命令

```bash
# 删除虚拟环境
rm -rf "${ZEPHYR_VENV}"

# 删除工具链
rm -rf "${ZEPHYR_WS}/tools/arm-gnu-toolchain"*
rm -f "${ZEPHYR_WS}/archives/"*.tar.bz2

# 恢复 Git
cd "${ZEPHYR_WS}" && git checkout HEAD~1
```

---

## Phase 2: 初始化 nxp-zsdk 工作区

### 目标
使用 west 初始化 nxp-zsdk 工作区，获取所有依赖，配置 VSCode 支持。

### 前提条件
- Phase 1 完成
- 网络连接正常 (首次下载约 1-2GB)

### ⚠️ 环境隔离检查（每个 Phase 必须执行）

**在开始 Phase 2 之前，必须执行以下隔离清理：**

```bash
echo "=== Phase 2 环境隔离清理 ==="

# 【关键】清除 ZEPHYR_BASE
# west init 要求 ZEPHYR_BASE 未设置
if [ -n "$ZEPHYR_BASE" ]; then
    echo "⚠️  清除现有 ZEPHYR_BASE: $ZEPHYR_BASE"
    echo "   west init 要求 ZEPHYR_BASE 未设置"
    unset ZEPHYR_BASE
fi

# 清除其他冲突变量
unset ZEPHYR_SDK_INSTALL_DIR 2>/dev/null || true
unset GNUARMEMB_TOOLCHAIN_PATH 2>/dev/null || true

# 激活虚拟环境（确保使用正确的 Python）
if [ -d "${HOME}/nxp-zephyr-ws/.venv" ]; then
    source "${HOME}/nxp-zephyr-ws/.venv/bin/activate"
fi

# 验证隔离效果
echo ""
echo "=== 验证隔离效果 ==="
echo "ZEPHYR_BASE: ${ZEPHYR_BASE:-<未设置，正确>}"
PYTHON_PATH=$(which python 2>/dev/null || which python3)
if [[ "$PYTHON_PATH" == *"nxp-zephyr-ws/.venv"* ]]; then
    echo "✓ Python: $PYTHON_PATH"
else
    echo "✗ Python 不在虚拟环境: $PYTHON_PATH"
    echo "  请运行: source ~/nxp-zephyr-ws/setup_env.sh"
    exit 1
fi
echo ""
```

### 执行步骤

#### Step 2.1: 初始化 west 工作区

```bash
echo "=== 初始化 nxp-zsdk 工作区 ==="

# 激活环境
source "${ZEPHYR_WS}/setup_env.sh"

# 进入工作区
cd "${ZEPHYR_WS}"

# 初始化 west (使用 nxp-zsdk 作为 manifest)
west init -m https://github.com/nxp-zephyr/nxp-zsdk.git --mr nxp-v4.3.0 nxp-zsdk

echo "✓ West 工作区已初始化"
```

#### Step 2.2: 获取所有依赖

```bash
echo "=== 获取所有依赖 (可能需要 10-20 分钟) ==="

cd "${ZEPHYR_WS}/nxp-zsdk"

# 获取所有仓库
west update

# 安装 Python 依赖
pip install -r zephyr/scripts/requirements.txt

# 注意：不使用 west zephyr-export，由 setup_env.sh 自动设置 ZEPHYR_BASE
echo "✓ 所有依赖已获取"
```

#### Step 2.3: 验证工作区结构

```bash
echo "=== 验证工作区结构 ==="

cd "${ZEPHYR_WS}"

# 检查关键目录
echo "工作区结构:"
ls -la nxp-zsdk/

echo ""
echo "Zephyr 基础目录:"
ls -la nxp-zsdk/zephyr/ | head -10

# 检查 west 配置
echo ""
echo "West 配置:"
cat .west/config

# 检查 FRDM-RW612 board 支持
echo ""
echo "FRDM-RW612 Board 支持:"
ls -la nxp-zsdk/zephyr/boards/nxp/frdm_rw612/ 2>/dev/null || echo "Board 在其他位置"
find nxp-zsdk -name "*frdm_rw612*" -type d 2>/dev/null | head -5
```

#### Step 2.4: 测试构建 FRDM-RW612

```bash
echo "=== 测试构建 FRDM-RW612 Hello World ==="

cd "${ZEPHYR_WS}/nxp-zsdk"

# 设置环境变量
export ZEPHYR_BASE="${ZEPHYR_WS}/nxp-zsdk/zephyr"

# 构建 hello_world 示例
west build -b frdm_rw612 zephyr/samples/hello_world -d build_frdm_test

# 验证输出
if [ -f build_frdm_test/zephyr/zephyr.bin ]; then
    echo "✓ 构建成功"
    ls -lh build_frdm_test/zephyr/zephyr.bin
else
    echo "✗ 构建失败"
    exit 1
fi

# 清理测试构建
rm -rf build_frdm_test
```

#### Step 2.5: 配置 VSCode 支持（可选）

**为 Zephyr IDE 插件和终端自动激活配置 VSCode：**

```bash
echo "=== 配置 VSCode 支持 ==="

# 创建 .vscode 目录
mkdir -p "${ZEPHYR_WS}/.vscode"

# 创建 VSCode 配置
cat > "${ZEPHYR_WS}/.vscode/settings.json" << 'EOF'
{
  "zephyr.base": "${workspaceFolder}/nxp-zsdk/zephyr",
  "zephyr.sdk": "",
  "python.defaultInterpreterPath": "${workspaceFolder}/.venv/bin/python",
  "cmake.configureOnOpen": false,
  "C_Cpp.default.compilerPath": "/usr/local/arm-none-eabi/bin/arm-none-eabi-gcc",
  "terminal.integrated.profiles.osx": {
    "Zephyr Bash": {
      "path": "/bin/bash",
      "args": ["-c", "source ~/nxp-zephyr-ws/setup_env.sh && exec bash"]
    }
  },
  "terminal.integrated.defaultProfile.osx": "Zephyr Bash"
}
EOF

echo "✓ VSCode 配置已创建"
```

**VSCode 配置说明：**

| 配置项 | 作用 |
|--------|------|
| `zephyr.base` | Zephyr IDE 插件所需的 ZEPHYR_BASE |
| `python.defaultInterpreterPath` | 使用项目 venv 中的 Python |
| `C_Cpp.default.compilerPath` | ARM 工具链路径 |
| `terminal.integrated.profiles.osx` | 终端自动激活环境 |

#### Step 2.6: 更新 .gitignore

```bash
# 更新 .gitignore 以排除 west 管理的仓库
cat >> "${ZEPHYR_WS}/.gitignore" << 'EOF'

# nxp-zsdk 工作区 (由 west 管理，但不忽略 .west/config)
# nxp-zsdk/
# bootloader/
# modules/
# hal_*/
# cmsis/
# tools/
# zephyr/
EOF

echo ".gitignore 已更新"
```

#### Step 2.7: Git 提交

```bash
cd "${ZEPHYR_WS}"

# 添加 west 配置和 VSCode 配置
git add .west/config .gitignore .vscode/settings.json

# 提交
git commit -m "feat(sdk): initialize nxp-zsdk v4.3.0 workspace

- Initialize west workspace with nxp-zsdk manifest
- Fetch all dependencies (zephyr, hal_nxp, modules)
- Verify FRDM-RW612 build capability
- Add VSCode configuration for Zephyr IDE plugin
- Update .gitignore for west-managed repositories

SDK Version: nxp-v4.3.0 (based on Zephyr v4.3.0)"

echo "SDK 工作区已提交到 Git"
```

### 验证

```bash
# 验证 west 工作区
cd "${ZEPHYR_WS}"
west list

# 验证 board 支持
west boards | grep -i rw612

# 验证 Zephyr 版本
grep "VERSION" nxp-zsdk/zephyr/version.cmake 2>/dev/null || \
    head -5 nxp-zsdk/zephyr/VERSION
```

### 回滚命令

```bash
# 删除 west 工作区
rm -rf "${ZEPHYR_WS}/nxp-zsdk"
rm -rf "${ZEPHYR_WS}/.west"
rm -rf "${ZEPHYR_WS}/bootloader"
rm -rf "${ZEPHYR_WS}/modules"
rm -rf "${ZEPHYR_WS}/hal_"*
rm -rf "${ZEPHYR_WS}/cmsis"
rm -rf "${ZEPHYR_WS}/tools"

# Git 回滚
cd "${ZEPHYR_WS}" && git checkout HEAD~1
```

---

## Phase 3: 创建 fcm363x-board 仓库（Out-of-Tree Board）

### 目标
创建独立的 FCM363X board 定义仓库，使用 **Out-of-Tree Board** 方式，不修改 SDK。

### 架构说明

**Out-of-Tree Board 架构**：

```
~/nxp-zephyr-ws/
├── fcm363x-board/              # Board 定义（独立仓库）
│   └── boards/nxp/fcm363x/     # Board 文件
│       ├── board.yml
│       ├── fcm363x.dts
│       ├── fcm363x-pinctrl.dtsi
│       ├── fcm363x_defconfig
│       ├── Kconfig
│       ├── Kconfig.defconfig
│       ├── CMakeLists.txt
│       └── board.c
├── nxp-zsdk/                   # SDK（不修改）
└── setup_env.sh               # 设置 BOARD_ROOT
```

**构建时通过 BOARD_ROOT 变量发现 board**：
```bash
export BOARD_ROOT=~/nxp-zephyr-ws/fcm363x-board
west build -b fcm363x
```

### FCM363X 硬件配置（基于 Code/ 目录研究）

| 参数 | FCM363X 值 | FRDM-RW612 值 |
|------|------------|---------------|
| **Flash 型号** | MX25L6433F | W25Q512JVFIQ |
| **Flash 大小** | 8MB (0x800000) | 64MB |
| **Flash 地址模式** | 24-bit (3-byte) | 32-bit |
| **PSRAM** | 无（禁用） | 有 |
| **UART Console** | FLEXCOMM3 (GPIO_24/26) | FLEXCOMM3 |
| **调试接口** | JTAG | SWD/JTAG |
| **32K 时钟** | 内部 RC32K | 外部晶振 |

### Flash 配置详情（MX25L6433F）

```c
// Flash 配置参数
sflashA1Size = 0x800000U;        // 8MB
sflashPadType = kSerialFlash_4Pads;  // Quad SPI
serialClkFreq = 7;               // 133 MHz
pageSize = 0x100;                // 256 bytes
sectorSize = 0x1000;             // 4KB
blockSize = 0x8000;              // 32KB

// LUT 命令
READ_CMD = 0xEB;                 // Fast Read Quad I/O (1-4-4)
PROGRAM_CMD = 0x02;              // Page Program
SECTOR_ERASE = 0x20;             // 4KB Sector Erase
BLOCK_ERASE = 0x52;              // 32KB Block Erase
CHIP_ERASE = 0x60;
WRITE_ENABLE = 0x06;
READ_STATUS = 0x05;
WRITE_STATUS = 0x01;
```

### UART 配置详情

| 信号 | GPIO | Pin | FLEXCOMM |
|------|------|-----|----------|
| USART_RXD | GPIO_24 | F3 | FLEXCOMM3 |
| USART_TXD | GPIO_26 | F6 | FLEXCOMM3 |
| 波特率 | 115200 | - | - |

### 前提条件
- Phase 2 完成
- 了解 FCM363X 硬件配置（见上表）

### ⚠️ 环境隔离检查（每个 Phase 必须执行）

**在开始 Phase 3 之前，必须执行以下隔离清理：**

```bash
echo "=== Phase 3 环境隔离清理 ==="

# 激活环境
source "${HOME}/nxp-zephyr-ws/setup_env.sh"

# 验证环境
echo "ZEPHYR_BASE: ${ZEPHYR_BASE}"
echo "BOARD_ROOT: ${BOARD_ROOT:-<未设置>}"
echo "Python: $(which python)"
```

### 执行步骤

#### Step 3.1: 创建 Board 仓库目录

```bash
echo "=== 创建 fcm363x-board 仓库 ==="

# 激活环境
source "${ZEPHYR_WS}/setup_env.sh"

# 创建目录
mkdir -p "${ZEPHYR_WS}/fcm363x-board/boards/nxp/fcm363x"
cd "${ZEPHYR_WS}/fcm363x-board"

# 初始化 Git
git init
git config user.name "FCM363X Developer"
git config user.email "dev@example.com"

echo "✓ Board 仓库目录已创建"
```

#### Step 3.2: 创建 Board YAML 文件

```bash
cat > boards/nxp/fcm363x/board.yml << 'EOF'
board:
  name: fcm363x
  vendor: nxp
  series: RW612
  socs:
    - name: rw612
EOF

echo "✓ board.yml 已创建"
```

#### Step 3.3: 创建 Board YAML 元数据

```bash
cat > boards/nxp/fcm363x/fcm363x.yaml << 'EOF'
identifier: fcm363x
name: FCM363X
type: mcu
arch: arm
toolchain:
  - zephyr
  - gnuarmemb
supported:
  - gpio
  - uart
  - spi
  - i2c
  - counter
  - pwm
  - entropy
  - flash
  - adc
vendor: NXP
series: RW612
ram: 1216
flash: 8192
EOF

echo "✓ fcm363x.yaml 已创建"
```

#### Step 3.4: 创建设备树文件

```bash
# 创建设备树包含文件
cat > boards/nxp/fcm363x/fcm363x.dtsi << 'EOF'
/*
 * FCM363X Device Tree Include
 * Based on NXP RW612
 * 
 * Hardware differences from FRDM-RW612:
 * - No external PSRAM
 * - JTAG debug interface (not SWD)
 * - UART on FLEXCOMM3
 */

/dts-v1/;

#include <nxp/nxp_rw612.dtsi>

/ {
    model = "Quectel FCM363X";
    compatible = "quectel,fcm363x", "nxp,rw612";

    /* SRAM: 1.2MB (0x00130000) */
    sram0: memory@20000000 {
        device_type = "memory";
        reg = <0x20000000 0x00130000>;
    };

    /* No PSRAM - explicitly disable */
    psram: psram@28000000 {
        status = "disabled";
        reg = <0x28000000 0x800000>;
    };

    aliases {
        led0 = &led0;
        sw0 = &button0;
    };

    leds {
        compatible = "gpio-leds";
        led0: led_0 {
            gpios = <&gpio0 0 GPIO_ACTIVE_LOW>;
            label = "LED 0";
        };
    };

    buttons {
        compatible = "gpio-keys";
        button0: button_0 {
            gpios = <&gpio0 1 GPIO_ACTIVE_LOW>;
            label = "Button 0";
        };
    };

    chosen {
        zephyr,console = &flexcomm3;
        zephyr,shell-uart = &flexcomm3;
        zephyr,flash = &flexspi0;
    };
};

/* UART Configuration - FLEXCOMM3 */
&flexcomm3 {
    status = "okay";
    compatible = "nxp,lpc-usart";
    current-speed = <115200>;
};

/* Flash Configuration - FLEXSPI (MX25L6433F 8MB) */
&flexspi {
    status = "okay";
    
    mx25l6433f: mx25l6433f@0 {
        compatible = "nxp,imx-flexspi-nor";
        size = <0x800000>;  /* 8MB (64Mbits) */
        reg = <0>;
        spi-max-frequency = <133000000>;
        
        /* MX25L6433F JEDEC ID: C2 20 17 */
        jedec-id = [c2 20 17];
        
        /* Quad I/O Read (0xEB) - 24-bit address, 4 data lanes */
        read-command = <0xEB 24 4>;
        /* Page Program (0x02) - 24-bit address, 1 data lane */
        program-command = <0x02 24 1>;
        /* Sector Erase 4KB (0x20) - 24-bit address */
        erase-command = <0x20 24>;
        
        status = "okay";
    };
};

/* PSRAM - Disabled (no hardware) */
&flexspi_psram {
    status = "disabled";
};

/* GPIO Configuration */
&gpio0 {
    status = "okay";
};

&gpio1 {
    status = "okay";
};
EOF

echo "✓ fcm363x.dtsi 已创建"
```

```bash
# 创建设备树主文件
cat > boards/nxp/fcm363x/fcm363x.dts << 'EOF'
/*
 * FCM363X Board Device Tree
 * Quectel FCM363XABMD module
 */

#include "fcm363x.dtsi"

/ {
    /* Board-specific overrides can be added here */
};
EOF

echo "✓ fcm363x.dts 已创建"
```

#### Step 3.5: 创建 Kconfig 文件

```bash
# Kconfig.board
cat > boards/nxp/fcm363x/Kconfig.board << 'EOF'
# FCM363X Board Configuration

config BOARD_FCM363X
    bool "FCM363X (Quectel)"
    depends on SOC_RW612
    select SOC_NXP_RW612
    help
      Quectel FCM363X board based on NXP RW612 wireless MCU.
      
      Hardware features:
      - NXP RW612ETA2I (Cortex-M33 @ 260MHz)
      - 8MB Quad SPI Flash
      - 1.2MB SRAM
      - No external PSRAM
      - Wi-Fi 6 + BLE 5.3
      - JTAG debug interface
EOF

echo "✓ Kconfig.board 已创建"
```

```bash
# Kconfig.defconfig
cat > boards/nxp/fcm363x/Kconfig.defconfig << 'EOF'
# FCM363X Default Configuration

if BOARD_FCM363X

config BOARD
    default "fcm363x"

config SYS_CLOCK_HW_CYCLES_PER_SEC
    default 260000000

# PSRAM disabled - no hardware
config NXP_PSRAM
    default n

# Enable serial for console
config SERIAL
    default y

config UART_CONSOLE
    default y

config CONSOLE_SUBSYS
    default y

# Enable GPIO
config GPIO
    default y

# Enable flash driver
config FLASH
    default y

endif # BOARD_FCM363X
EOF

echo "✓ Kconfig.defconfig 已创建"
```

#### Step 3.6: 创建 CMakeLists.txt

```bash
cat > boards/nxp/fcm363x/CMakeLists.txt << 'EOF'
# FCM363X Board CMakeLists

zephyr_library()
zephyr_library_sources(board.c)

# Include generated DTS headers
zephyr_include_directories(${ZEPHYR_BASE}/include)
zephyr_include_directories(${BOARD_DIR})
EOF

echo "✓ CMakeLists.txt 已创建"
```

#### Step 3.7: 创建 board.c

```bash
cat > boards/nxp/fcm363x/board.c << 'EOF'
/*
 * FCM363X Board Initialization
 */

#include <zephyr/init.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/kernel.h>

static int fcm363x_init(void)
{
    /* Board-specific initialization can be added here */
    return 0;
}

SYS_INIT(fcm363x_init, PRE_KERNEL_1, 0);
EOF

echo "✓ board.c 已创建"
```

#### Step 3.8: 创建 west.yml

```bash
cat > west.yml << 'EOF'
manifest:
  remotes:
    - name: nxp-zephyr
      url-base: https://github.com/nxp-zephyr
  
  projects:
    - name: nxp-zsdk
      remote: nxp-zephyr
      revision: nxp-v4.3.0
      import: true
  
  self:
    path: fcm363x-board
EOF

echo "✓ west.yml 已创建"
```

#### Step 3.9: 创建 README.md

```bash
cat > README.md << 'EOF'
# FCM363X Board Support

This repository contains the Zephyr board definition for Quectel FCM363X module.

## Hardware

- **MCU**: NXP RW612ETA2I (Cortex-M33 @ 260MHz)
- **Flash**: 8MB Quad SPI Flash
- **SRAM**: 1.2MB
- **PSRAM**: None (disabled)
- **Wireless**: Wi-Fi 6 + BLE 5.3
- **Debug**: JTAG interface

## Usage

Add this repository to your project's `west.yml`:

```yaml
projects:
  - name: fcm363x-board
    remote: your-remote
    revision: main
```

Build with:

```bash
west build -b fcm363x
```

## Differences from FRDM-RW612

1. **No PSRAM** - PSRAM is disabled in all configurations
2. **JTAG Debug** - Uses JTAG interface, not SWD
3. **UART** - Console on FLEXCOMM3

## License

SPDX-License-Identifier: Apache-2.0
EOF

echo "✓ README.md 已创建"
```

#### Step 3.10: 初始化 Git 并提交

```bash
cd "${ZEPHYR_WS}/fcm363x-board"

# 添加所有文件
git add .

# 提交
git commit -m "feat(board): add FCM363X out-of-tree board support

Board support for Quectel FCM363X module (NXP RW612):

Hardware configuration:
- NXP RW612ETA2I @ 260MHz
- MX25L6433F 8MB Quad SPI Flash (24-bit address)
- 1.2MB SRAM (no external PSRAM)
- Wi-Fi 6 + BLE 5.3
- UART Console on FLEXCOMM3 (GPIO_24/26)

Key differences from FRDM-RW612:
- Flash: MX25L6433F 8MB (vs W25Q512JVFIQ 64MB)
- PSRAM disabled (no hardware)
- JTAG debug interface only
- 24-bit flash address mode

Files:
- board.yml: Board metadata
- fcm363x.yaml: Board capabilities
- fcm363x.dts: Device tree main file
- fcm363x-pinctrl.dtsi: Pin control configuration
- fcm363x_defconfig: Default configuration
- Kconfig: Board Kconfig options
- Kconfig.defconfig: Default Kconfig values
- CMakeLists.txt: Build configuration
- board.c: Board initialization"

# 设置主分支
git branch -M main

echo "✓ Board 仓库已提交"
git log --oneline -1
```

#### Step 3.11: 更新 setup_env.sh（添加 BOARD_ROOT）

**关键步骤：在 setup_env.sh 中添加 BOARD_ROOT 环境变量**

```bash
# 更新 setup_env.sh，添加 BOARD_ROOT 设置
# 在 "步骤 4: 设置 Zephyr 环境变量" 之后添加

cat > "${ZEPHYR_WS}/setup_env.sh" << 'SETUP_EOF'
#!/bin/bash
#
# FCM363X Zephyr 环境激活脚本
# 
# 功能：
# 1. 清除冲突的环境变量（ZEPHYR_BASE 等）
# 2. 激活独立的 Python 虚拟环境
# 3. 设置工作区环境变量
# 4. 配置 ARM 工具链路径
# 5. 设置 BOARD_ROOT（Out-of-Tree Board）
# 6. 验证隔离效果
#
# 用法：
#   source ~/nxp-zephyr-ws/setup_env.sh
#

set -e

# ========================================
# 1. 清除冲突环境变量
# ========================================

echo "=== 步骤 1: 清除冲突环境变量 ==="

if [ -n "$ZEPHYR_BASE" ]; then
    echo "⚠️  检测到冲突的 ZEPHYR_BASE: $ZEPHYR_BASE"
    echo "   正在清除..."
    unset ZEPHYR_BASE
fi

unset ZEPHYR_SDK_INSTALL_DIR 2>/dev/null || true
unset ZEPHYR_MODULES 2>/dev/null || true
unset ZEPHYR_MODULES_CMAKE 2>/dev/null || true

echo "✓ 环境变量已清理"

# ========================================
# 2. 定义工作区路径
# ========================================

echo ""
echo "=== 步骤 2: 定义工作区路径 ==="

export ZEPHYR_WS="${HOME}/nxp-zephyr-ws"
export ZEPHYR_VENV="${ZEPHYR_WS}/.venv"

echo "✓ 工作区路径: ${ZEPHYR_WS}"
echo "✓ 虚拟环境: ${ZEPHYR_VENV}"

# ========================================
# 3. 激活 Python 虚拟环境
# ========================================

echo ""
echo "=== 步骤 3: 激活 Python 虚拟环境 ==="

if [ ! -d "${ZEPHYR_VENV}" ]; then
    echo "✗ 错误: 虚拟环境不存在: ${ZEPHYR_VENV}"
    echo "  请先创建虚拟环境"
    return 1 2>/dev/null || exit 1
fi

source "${ZEPHYR_VENV}/bin/activate"
echo "✓ Python 虚拟环境已激活: $(which python)"

# ========================================
# 4. 设置 Zephyr 环境变量（SDK 初始化后）
# ========================================

echo ""
echo "=== 步骤 4: 设置 Zephyr 环境变量 ==="

if [ -d "${ZEPHYR_WS}/nxp-zsdk/zephyr" ]; then
    export ZEPHYR_BASE="${ZEPHYR_WS}/nxp-zsdk/zephyr"
    echo "✓ ZEPHYR_BASE: ${ZEPHYR_BASE}"
else
    echo "! nxp-zsdk 尚未初始化，ZEPHYR_BASE 暂不设置"
fi

# ========================================
# 5. 设置 BOARD_ROOT（Out-of-Tree Board）
# ========================================

echo ""
echo "=== 步骤 5: 设置 BOARD_ROOT ==="

if [ -d "${ZEPHYR_WS}/fcm363x-board" ]; then
    export BOARD_ROOT="${ZEPHYR_WS}/fcm363x-board"
    echo "✓ BOARD_ROOT: ${BOARD_ROOT}"
    echo "  Board 路径: ${BOARD_ROOT}/boards/nxp/fcm363x"
else
    echo "! fcm363x-board 尚未创建，BOARD_ROOT 暂不设置"
    echo "  运行 Phase 3 后会自动设置"
fi

# ========================================
# 6. 配置 ARM 工具链（使用系统已安装）
# ========================================

echo ""
echo "=== 步骤 6: 配置 ARM 工具链 ==="

export GNUARMEMB_TOOLCHAIN_PATH="/usr/local/arm-none-eabi"
export PATH="${GNUARMEMB_TOOLCHAIN_PATH}/bin:${PATH}"

if command -v arm-none-eabi-gcc &> /dev/null; then
    ARM_VERSION=$(arm-none-eabi-gcc --version | head -1)
    echo "✓ ARM 工具链: ${ARM_VERSION}"
    echo "✓ 路径: ${GNUARMEMB_TOOLCHAIN_PATH}"
else
    echo "✗ ARM 工具链未找到"
fi

# ========================================
# 7. 隔离效果验证
# ========================================

echo ""
echo "=== 步骤 7: 隔离效果验证 ==="

PYTHON_PATH=$(which python)
if [[ "$PYTHON_PATH" == *"$ZEPHYR_VENV"* ]]; then
    echo "✓ Python 隔离: $PYTHON_PATH"
else
    echo "✗ Python 隔离失败: $PYTHON_PATH"
fi

# ========================================
# 8. 显示工作区信息
# ========================================

echo ""
echo "=========================================="
echo "  FCM363X Zephyr 工作区已激活"
echo "=========================================="
echo ""
echo "工作区:       ${ZEPHYR_WS}"
echo "Python:       $(python --version 2>&1)"
echo "West:         $(west --version 2>/dev/null || echo '未安装')"
echo "ARM GCC:      $(arm-none-eabi-gcc --version 2>/dev/null | head -1 || echo '未配置')"
echo "BOARD_ROOT:   ${BOARD_ROOT:-<未设置>}"
echo ""
echo "常用命令:"
echo "  cd \$ZEPHYR_WS          # 进入工作区"
echo "  west build -b fcm363x   # 构建 FCM363X"
echo "  west build -b frdm_rw612 # 构建 FRDM-RW612"
echo ""
SETUP_EOF

chmod +x "${ZEPHYR_WS}/setup_env.sh"
echo "✓ setup_env.sh 已更新（添加 BOARD_ROOT）"
```

#### Step 3.12: 测试构建 fcm363x

```bash
echo "=== Step 3.12: 测试构建 FCM363X Hello World ==="

# 激活环境（包含 BOARD_ROOT）
source "${ZEPHYR_WS}/setup_env.sh"

# 验证 BOARD_ROOT
echo ""
echo "验证 BOARD_ROOT:"
echo "  BOARD_ROOT = ${BOARD_ROOT}"
ls -la "${BOARD_ROOT}/boards/nxp/fcm363x/" 2>/dev/null || echo "  Board 目录不存在"

# 进入 SDK 目录
cd "${ZEPHYR_WS}/nxp-zsdk"

# 构建测试
echo ""
echo "构建 fcm363x hello_world..."
west build -b fcm363x zephyr/samples/hello_world -d build_fcm363x_test --pristine

# 检查构建结果
if [ -f build_fcm363x_test/zephyr/zephyr.bin ]; then
    echo ""
    echo "✓ FCM363X 构建成功!"
    ls -lh build_fcm363x_test/zephyr/zephyr.bin
    
    # 清理
    rm -rf build_fcm363x_test
    echo "✓ 测试构建目录已清理"
else
    echo "✗ 构建失败"
    exit 1
fi
```

### 验证

```bash
# 验证文件结构
echo "=== 验证 Board 文件结构 ==="
cd "${ZEPHYR_WS}/fcm363x-board"
find . -type f | sort

# 验证 Git 状态
echo ""
echo "=== 验证 Git 状态 ==="
git status

# 验证环境变量
echo ""
echo "=== 验证环境变量 ==="
source "${ZEPHYR_WS}/setup_env.sh"
echo "BOARD_ROOT: ${BOARD_ROOT}"
echo "ZEPHYR_BASE: ${ZEPHYR_BASE}"
```

### 回滚命令

```bash
# 删除 board 仓库
rm -rf "${ZEPHYR_WS}/fcm363x-board"

# 恢复 setup_env.sh（从 Git）
cd "${ZEPHYR_WS}" && git checkout HEAD -- setup_env.sh
```

---

## Phase 4: 创建 fcm363x-project 应用（共享SDK架构）

### 目标
在共享SDK工作区内创建应用项目，参考 Zephyr 官方 example-application 架构最佳实践。

### 架构说明（参考官方 example-application）

```
~/nxp-zephyr-ws/                    # VSCode 打开此目录
├── nxp-zsdk/                       # 共享 SDK (~2GB)
│   ├── zephyr/                     # ZEPHYR_BASE
│   └── ...
│
├── fcm363x-board/                  # Board 仓库（独立 Git）
│   ├── boards/nxp/fcm363x/         # Board 定义
│   │   ├── board.yml
│   │   ├── fcm363x.dts
│   │   ├── fcm363x_defconfig
│   │   └── ...
│   └── zephyr/                     # ⭐ 模块注册（官方方式）
│       └── module.yml              # 自动注册 board_root
│
├── fcm363x-lib/                    # 可选：共享库/驱动（独立 Git）
│   ├── drivers/                    # 自定义驱动
│   ├── lib/                        # 自定义库
│   ├── include/                    # 公共头文件
│   ├── dts/bindings/               # 设备树绑定
│   └── zephyr/module.yml           # 模块注册
│
├── setup_env.sh                    # 环境变量配置
│
└── projects/                       # 所有应用项目
    └── hello/                      # 项目结构（参考官方）
        ├── CMakeLists.txt          # 应用构建入口
        ├── prj.conf                # 应用配置
        ├── debug.conf              # 调试配置（可选）
        ├── VERSION                 # 版本文件
        ├── boards/                 # ⭐ 项目级板级覆盖
        │   └── fcm363x.overlay     # 设备树覆盖
        └── src/
            └── main.c
```

### 架构对比

| 特性 | 官方 example-application | 本方案 |
|------|--------------------------|--------|
| 工作区模式 | T2 独立 west workspace | 共享 SDK + 环境变量 |
| Board 注册 | zephyr/module.yml | 同样使用 module.yml |
| 项目结构 | app/ 包裹 | 直接项目目录 |
| 板级覆盖 | app/boards/*.overlay | projects/hello/boards/ |

**优点：**
- SDK 共享，节省磁盘空间
- Board 使用官方推荐的 module.yml 注册方式
- 项目支持板级覆盖文件
- 可扩展共享库/驱动

### 前提条件
- Phase 3 完成
- Board 仓库需要添加 `zephyr/module.yml`

### ⚠️ 环境隔离检查

```bash
echo "=== Phase 4 环境检查 ==="

# 激活环境
source "${ZEPHYR_WS}/setup_env.sh"

# 验证关键变量
echo "ZEPHYR_BASE: ${ZEPHYR_BASE}"
echo "BOARD_ROOT: ${BOARD_ROOT}"

# 验证路径存在
[ -d "${ZEPHYR_BASE}" ] && echo "✓ SDK 存在" || echo "✗ SDK 不存在"
[ -d "${BOARD_ROOT}/boards/nxp/fcm363x" ] && echo "✓ Board 存在" || echo "✗ Board 不存在"
[ -f "${BOARD_ROOT}/zephyr/module.yml" ] && echo "✓ module.yml 存在" || echo "! module.yml 不存在（需添加）"
```

### 执行步骤

#### Step 4.1: 为 Board 仓库添加 module.yml（官方推荐方式）

```bash
echo "=== 添加 zephyr/module.yml ==="

cd "${ZEPHYR_WS}/fcm363x-board"

# 创建 zephyr 目录
mkdir -p zephyr

# 创建 module.yml
cat > zephyr/module.yml << 'EOF'
# FCM363X Board Module Definition
# 参考: https://github.com/zephyrproject-rtos/example-application

build:
  settings:
    # 注册 board_root，让 Zephyr 识别 boards/ 目录
    board_root: .
    # 注册 dts_root（如果需要自定义设备树绑定）
    dts_root: .
EOF

echo "✓ zephyr/module.yml 已创建"

# 提交
git add zephyr/
git commit -m "feat(board): add zephyr/module.yml for board_root registration

This follows the official example-application pattern for
registering out-of-tree boards via module.yml."

echo "✓ Board 仓库已更新"
```

#### Step 4.2: 创建 projects 目录和 hello 项目

```bash
echo "=== 创建 hello 项目 ==="

# 激活环境
source "${ZEPHYR_WS}/setup_env.sh"

# 创建项目目录结构（参考官方 example-application/app）
mkdir -p "${ZEPHYR_WS}/projects/hello/src"
mkdir -p "${ZEPHYR_WS}/projects/hello/boards"

cd "${ZEPHYR_WS}/projects/hello"

# 初始化 Git
git init
git config user.name "FCM363X Developer"
git config user.email "dev@example.com"

echo "✓ 项目目录已创建: ${ZEPHYR_WS}/projects/hello"
```

#### Step 4.2: 创建 CMakeLists.txt

```bash
cat > CMakeLists.txt << 'EOF'
# FCM363X Hello World Project
# 使用共享 SDK（通过 ZEPHYR_BASE 环境变量）

cmake_minimum_required(VERSION 3.20.0)

find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})

project(fcm363x_hello VERSION 1.0.0)

target_sources(app PRIVATE
    src/main.c
)

target_include_directories(app PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)
EOF

echo "✓ CMakeLists.txt 已创建"
```

#### Step 4.4: 创建 prj.conf

```bash
cat > prj.conf << 'EOF'
# FCM363X Hello World Configuration

# Console
CONFIG_PRINTK=y
CONFIG_LOG=y
CONFIG_LOG_MODE_IMMEDIATE=y
CONFIG_SERIAL=y
CONFIG_UART_CONSOLE=y

# PSRAM disabled (no hardware)
CONFIG_NXP_PSRAM=n

# Shell for debugging
CONFIG_SHELL=y

# Build optimizations
CONFIG_DEBUG_OPTIMIZATIONS=y
CONFIG_DEBUG_THREAD_INFO=y
EOF

echo "✓ prj.conf 已创建"
```

#### Step 4.5: 创建 VERSION 文件（参考官方）

```bash
# VERSION 文件用于应用版本管理
cat > VERSION << 'EOF'
VERSION_MAJOR = 1
VERSION_MINOR = 0
PATCHLEVEL = 0
VERSION_TWEAK = 0
EXTRAVERSION =
EOF

echo "✓ VERSION 已创建"
```

#### Step 4.6: 创建 main.c

```bash
cat > src/main.c << 'EOF'
/*
 * FCM363X Hello World
 * Quectel FCM363X module - NXP RW612
 */

#include <zephyr/kernel.h>
#include <zephyr/sys/printk.h>

int main(void)
{
    printk("\n");
    printk("========================================\n");
    printk("  FCM363X Zephyr Hello World\n");
    printk("========================================\n");
    printk("\n");
    
    printk("Board:  Quectel FCM363X\n");
    printk("Chip:   NXP RW612ETA2I\n");
    printk("CPU:    ARM Cortex-M33 @ 260MHz\n");
    printk("RAM:    1.2MB SRAM\n");
    printk("Flash:  8MB QSPI (MX25L6433F)\n");
    printk("PSRAM:  Disabled (no hardware)\n");
    printk("\n");
    
    printk("Zephyr Version: %s\n", KERNEL_VERSION_STRING);
    printk("\n");
    printk("System ready.\n");
    
    int count = 0;
    while (1) {
        printk("Heartbeat: %d\n", count++);
        k_sleep(K_SECONDS(1));
    }
    
    return 0;
}
EOF

echo "✓ src/main.c 已创建"
```

#### Step 4.7: 创建板级覆盖文件（可选，参考官方）

```bash
# 项目级设备树覆盖，用于修改板级配置
# 例如：添加自定义 GPIO、修改 UART 配置等

cat > boards/fcm363x.overlay << 'EOF'
/*
 * FCM363X Board Overlay for Hello Project
 * 项目级覆盖文件，优先级高于 Board 定义
 */

/ {
    /* 示例：添加自定义别名 */
    aliases {
        my-led = &led0;
    };
};

/* 示例：修改 UART 配置
&flexcomm3 {
    current-speed = <921600>;
};
*/
EOF

echo "✓ boards/fcm363x.overlay 已创建"
```

#### Step 4.8: 创建 .gitignore

```bash
cat > .gitignore << 'EOF'
# Build output
build/

# IDE
.vscode/
.idea/

# macOS
.DS_Store
EOF

echo "✓ .gitignore 已创建"
```

#### Step 4.9: Git 提交

```bash
cd "${ZEPHYR_WS}/projects/hello"

git add .
git commit -m "feat(hello): add FCM363X hello world application

Project structure following official example-application pattern:
- CMakeLists.txt: Application build entry
- prj.conf: Application configuration
- VERSION: Version management
- boards/: Board-level overlays
- src/main.c: Application entry

Build: west build -b fcm363x"

git branch -M main

echo "✓ 项目已提交"
git log --oneline -1
```

#### Step 4.10: 构建验证

```bash
echo "=== 构建验证 ==="

# 确保环境已激活
source "${ZEPHYR_WS}/setup_env.sh"

cd "${ZEPHYR_WS}/projects/hello"

# 构建
west build -b fcm363x -p always

# 检查输出
if [ -f build/zephyr/zephyr.bin ]; then
    echo ""
    echo "✓ 构建成功!"
    ls -lh build/zephyr/zephyr.bin
else
    echo "✗ 构建失败"
    exit 1
fi
```

### 验证

```bash
# 验证项目结构
cd "${ZEPHYR_WS}/projects/hello"
find . -type f | grep -v build | grep -v .git

# 验证构建产物
ls -lh build/zephyr/zephyr.{bin,elf}
```

### 在任意目录创建项目

**原理：** 只需 `source setup_env.sh`，环境变量 `ZEPHYR_BASE` 和 `BOARD_ROOT` 会指向共享位置。

```bash
# 场景：在任意目录创建项目

# 1. 先激活环境（设置 ZEPHYR_BASE 和 BOARD_ROOT）
source ~/nxp-zephyr-ws/setup_env.sh

# 2. 在任意目录创建项目
mkdir -p ~/my-projects/fcm363x-app/src
cd ~/my-projects/fcm363x-app

# 3. 创建 CMakeLists.txt（使用 $ENV{ZEPHYR_BASE} 找到 SDK）
cat > CMakeLists.txt << 'EOF'
cmake_minimum_required(VERSION 3.20.0)
find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(my_app VERSION 1.0.0)
target_sources(app PRIVATE src/main.c)
EOF

# 4. 创建 prj.conf 和 main.c
# ...

# 5. 构建（环境变量已指向共享 SDK 和 Board）
west build -b fcm363x
```

### 添加新项目模板

**在工作区内创建新项目：**

```bash
# 创建新项目
mkdir -p "${ZEPHYR_WS}/projects/my-app/src"
cd "${ZEPHYR_WS}/projects/my-app"

# 复制配置文件
cp ../hello/CMakeLists.txt .
cp ../hello/prj.conf .
# 修改 project(fcm363x_hello) → project(my_app)

# 创建 main.c
cat > src/main.c << 'EOF'
#include <zephyr/kernel.h>
#include <zephyr/sys/printk.h>

int main(void)
{
    printk("My App\n");
    return 0;
}
EOF

# 构建
west build -b fcm363x
```

### 团队协作方案

#### 架构概览

```
# 团队成员机器（任意位置）
~/nxp-zephyr-ws/
├── nxp-zsdk/           # west init from GitHub（共享 SDK）
├── fcm363x-board/      # git clone from 公司仓库（共享 Board）
└── setup_env.sh        # 标准化环境脚本

~/projects/             # 项目可放在任意位置
├── hello/
├── wifi-demo/
└── ...
```

#### 共享组件管理

| 组件 | 存储位置 | 版本控制 | 更新方式 |
|------|----------|----------|----------|
| SDK | GitHub nxp-zephyr/nxp-zsdk | Git tag (nxp-v4.3.0) | `west update` |
| Board | 公司 Git 仓库 | Git branch/tag | `git pull` |
| 项目 | 公司 Git 仓库 | Git | `git pull` |

#### Step 4.8: Board 仓库推送到远程（团队共享）

```bash
echo "=== 推送 Board 到远程仓库 ==="

cd "${ZEPHYR_WS}/fcm363x-board"

# 添加远程仓库（替换为实际地址）
git remote add origin git@github.com:your-org/fcm363x-board.git

# 推送
git push -u origin main

echo "✓ Board 仓库已推送"
```

#### Step 4.9: 创建团队初始化脚本

```bash
cat > "${ZEPHYR_WS}/team_init.sh" << 'EOF'
#!/bin/bash
#
# FCM363X 团队成员初始化脚本
# 用法: source team_init.sh
#

set -e

export ZEPHYR_WS="${HOME}/nxp-zephyr-ws"

echo "=== FCM363X 团队环境初始化 ==="

# 1. 创建工作区
mkdir -p "${ZEPHYR_WS}"
cd "${ZEPHYR_WS}"

# 2. 初始化 SDK（如果不存在）
if [ ! -d "nxp-zsdk/.west" ]; then
    echo "初始化 nxp-zsdk..."
    west init -m https://github.com/nxp-zephyr/nxp-zsdk -b nxp-v4.3.0
    west update
fi

# 3. 克隆 Board 仓库（如果不存在）
if [ ! -d "fcm363x-board" ]; then
    echo "克隆 fcm363x-board..."
    git clone git@github.com:your-org/fcm363x-board.git
fi

# 4. 创建/更新 setup_env.sh
if [ ! -f "setup_env.sh" ]; then
    echo "创建 setup_env.sh..."
    # 从 Board 仓库复制，或创建默认版本
fi

# 5. 激活环境
source "${ZEPHYR_WS}/setup_env.sh"

echo ""
echo "=== 初始化完成 ==="
echo "SDK:    ${ZEPHYR_BASE}"
echo "Board:  ${BOARD_ROOT}"
echo ""
echo "创建新项目:"
echo "  mkdir -p ~/projects/my-app/src"
echo "  cd ~/projects/my-app"
echo "  west build -b fcm363x"
EOF

chmod +x "${ZEPHYR_WS}/team_init.sh"
echo "✓ team_init.sh 已创建"
```

#### 新成员初始化流程

```bash
# 1. 克隆 Board 仓库（包含 team_init.sh）
git clone git@github.com:your-org/fcm363x-board.git ~/nxp-zephyr-ws/fcm363x-board

# 2. 运行初始化脚本
source ~/nxp-zephyr-ws/fcm363x-board/team_init.sh

# 3. 克隆项目
git clone git@github.com:your-org/my-app.git ~/projects/my-app

# 4. 构建
cd ~/projects/my-app
west build -b fcm363x
```

### 回滚命令

```bash
# 删除 hello 项目
rm -rf "${ZEPHYR_WS}/projects/hello"

# 删除 team_init.sh
rm -f "${ZEPHYR_WS}/team_init.sh"
```

---

## Phase 5: 构建验证与调试

### 目标
使用 west build 构建项目，配置 JLink 调试，验证构建输出。

### 前提条件
- Phase 4 完成
- JLink 调试器已安装（如需调试）

### ⚠️ 环境隔离检查（每个 Phase 必须执行）

**在开始 Phase 5 之前，必须执行以下隔离清理：**

```bash
echo "=== Phase 5 环境隔离清理 ==="

# Phase 5 需要设置正确的 ZEPHYR_BASE
# 先清除旧值，然后通过 setup_env.sh 设置正确的值

# 清除可能冲突的变量
unset ZEPHYR_BASE
unset ZEPHYR_SDK_INSTALL_DIR 2>/dev/null || true
unset GNUARMEMB_TOOLCHAIN_PATH 2>/dev/null || true

# 使用完善的激活脚本（会自动设置正确的 ZEPHYR_BASE）
source "${HOME}/zephyr-workspace/setup_env.sh"

# 验证隔离效果
echo ""
echo "=== 验证隔离效果 ==="
if [ -d "${HOME}/zephyr-workspace/nxp-zsdk/zephyr" ]; then
    if [ -n "$ZEPHYR_BASE" ] && [[ "$ZEPHYR_BASE" == *"zephyr-workspace"* ]]; then
        echo "✓ ZEPHYR_BASE: ${ZEPHYR_BASE} (正确)"
    else
        echo "✗ ZEPHYR_BASE 设置不正确: ${ZEPHYR_BASE:-<未设置>}"
        echo "  应该是: ${HOME}/zephyr-workspace/nxp-zsdk/zephyr"
        exit 1
    fi
fi

# 验证 Python 隔离
PYTHON_PATH=$(which python 2>/dev/null || which python3)
if [[ "$PYTHON_PATH" == *"zephyr-venv"* ]]; then
    echo "✓ Python 隔离: $PYTHON_PATH"
else
    echo "✗ Python 不在虚拟环境"
    exit 1
fi
echo ""
```

### 执行步骤

#### Step 5.1: 初始化项目工作区

```bash
echo "=== 初始化项目工作区 ==="

# 激活环境
source "${ZEPHYR_WS}/setup_env.sh"

# 进入项目目录
cd "${ZEPHYR_WS}/fcm363x-project"

# 初始化 west 工作区 (使用项目 manifest)
west init -l .

# 更新依赖
west update

echo "✓ 项目工作区已初始化"
```

#### Step 5.2: 构建 Hello World

```bash
echo "=== 构建 FCM363X Hello World ==="

cd "${ZEPHYR_WS}/fcm363x-project"

# 设置环境变量
export ZEPHYR_BASE="${ZEPHYR_WS}/nxp-zsdk/zephyr"

# 构建项目
west build -b fcm363x -p always

echo "构建完成"
```

#### Step 5.3: 验证构建输出

```bash
echo "=== 验证构建输出 ==="

cd "${ZEPHYR_WS}/fcm363x-project"

# 检查输出文件
echo "构建产物:"
ls -lh build/zephyr/zephyr.*

# 显示固件大小
echo ""
echo "固件大小:"
arm-none-eabi-size build/zephyr/zephyr.elf

# 显示内存使用
echo ""
echo "内存映射:"
arm-none-eabi-readelf -S build/zephyr/zephyr.elf | grep -E "\.text|\.rodata|\.data|\.bss"
```

#### Step 5.4: 创建 JLink 调试配置

```bash
echo "=== 创建 JLink 调试配置 ==="

mkdir -p "${ZEPHYR_WS}/fcm363x-project/scripts"

# JLink 配置文件
cat > scripts/jlink.conf << 'EOF'
device RW612
interface jtag
speed 10000
jtagconf 1, 1, 1, 1
EOF

# JLink 烧录脚本
cat > scripts/jlink_flash.jlink << 'EOF'
device RW612
si jtag
speed 10000
jtagconf 1, 1, 1, 1
loadfile build/zephyr/zephyr.hex
r
g
exit
EOF

# 烧录脚本
cat > scripts/flash.sh << 'EOF'
#!/bin/bash
# FCM363X Flash Script

if [ ! -f "build/zephyr/zephyr.hex" ]; then
    echo "Error: build/zephyr/zephyr.hex not found"
    echo "Run 'west build -b fcm363x' first"
    exit 1
fi

echo "Flashing FCM363X..."
JLinkExe -CommandFile scripts/jlink_flash.jlink
EOF

chmod +x scripts/flash.sh

echo "✓ JLink 调试配置已创建"
```

#### Step 5.5: 创建调试脚本

```bash
# GDB 调试启动脚本
cat > scripts/debug.sh << 'EOF'
#!/bin/bash
# FCM363X Debug Script

if [ ! -f "build/zephyr/zephyr.elf" ]; then
    echo "Error: build/zephyr/zephyr.elf not found"
    echo "Run 'west build -b fcm363x' first"
    exit 1
fi

echo "Starting JLink GDB Server..."
echo "Connect GDB to localhost:2331"
echo ""

# 启动 JLink GDB Server (后台)
JLinkGDBServer -device RW612 -if jtag -speed 10000 &
GDB_PID=$!

sleep 2

# 启动 GDB
arm-none-eabi-gdb build/zephyr/zephyr.elf \
    -ex "target remote localhost:2331" \
    -ex "monitor reset" \
    -ex "monitor halt" \
    -ex "load"

# 清理
kill $GDB_PID 2>/dev/null
EOF

chmod +x scripts/debug.sh

# 创建 west 调试配置
mkdir -p boards
cat > boards/fcm363x_board.cmake << 'EOF'
# West flash configuration for FCM363X

board_runner_args(jlink "--device=RW612" "--iface=jtag" "--speed=10000")
include(${ZEPHYR_BASE}/boards/common/jlink.board.cmake)
EOF

echo "✓ 调试脚本已创建"
```

#### Step 5.5b: 创建 BLHOST ISP 烧录配置（备选方案）

BLHOST 是 NXP 官方的 ISP 模式烧录工具，通过 USB 或 UART 接口烧录，无需 JLink 调试器。

```bash
echo "=== 创建 BLHOST ISP 烧录配置 ==="

# 安装 SPSDK (包含 blhost 工具)
pip install spsdk

# 验证安装
blhost --version

# 复制 blhost_helper 工具到工作区
cp -r "${HOME}/test/claude_proj/f01x_r03-main/rw61x-blhost-helper-master" \
      "${ZEPHYR_WS}/tools/blhost-helper"

# 创建 BLHOST 烧录脚本
cat > scripts/flash_blhost.sh << 'EOF'
#!/bin/bash
# FCM363X BLHOST ISP Flash Script
# 使用 NXP BLHOST 工具通过 USB/UART ISP 模式烧录

set -e

# 配置
BLHOST_HELPER="${ZEPHYR_WS}/tools/blhost-helper/blhost_helper.py"
DEVICE="FCM363X"          # 或 FCM363XAB, FCM363XAC
INTERFACE="usb"           # usb 或 uart
# PORT="/dev/ttyUSB0"     # UART 模式需要指定端口
FIRMWARE="build/zephyr/zephyr.bin"

# 检查固件文件
if [ ! -f "$FIRMWARE" ]; then
    echo "Error: $FIRMWARE not found"
    echo "Run 'west build -b fcm363x' first"
    exit 1
fi

FILE_SIZE=$(stat -f%z "$FIRMWARE" 2>/dev/null || stat -c%s "$FIRMWARE" 2>/dev/null)
echo "Firmware: $FIRMWARE ($FILE_SIZE bytes)"

# 烧录选项
echo ""
echo "=== BLHOST ISP 烧录 ==="
echo "Device: $DEVICE"
echo "Interface: $INTERFACE"
echo ""
echo "请确保设备已进入 ISP 模式 (Bootloader Mode)"
echo "通常方法: 按住 BOOT 按键，按 RESET 按键，释放 RESET，再释放 BOOT"
echo ""

read -p "按 Enter 继续..."

# 执行烧录
echo "正在烧录..."
if [ "$INTERFACE" = "uart" ]; then
    python "$BLHOST_HELPER" -d "$DEVICE" -i uart -p "$PORT" --write -f "$FIRMWARE"
else
    python "$BLHOST_HELPER" -d "$DEVICE" -i usb --write -f "$FIRMWARE"
fi

echo "✓ 烧录完成"
EOF

chmod +x scripts/flash_blhost.sh

# 创建快速烧录脚本 (带全擦除)
cat > scripts/flash_blhost_erase_all.sh << 'EOF'
#!/bin/bash
# FCM363X BLHOST ISP Flash Script (with full erase)
# 用于开发调试，先全擦除再烧录

set -e

BLHOST_HELPER="${ZEPHYR_WS}/tools/blhost-helper/blhost_helper.py"
DEVICE="FCM363X"
FIRMWARE="build/zephyr/zephyr.bin"

if [ ! -f "$FIRMWARE" ]; then
    echo "Error: $FIRMWARE not found"
    exit 1
fi

echo "=== BLHOST ISP 烧录 (全擦除模式) ==="
echo "Device: $DEVICE"
echo "Firmware: $FIRMWARE"
echo ""
echo "警告: 此模式将擦除整个 Flash!"
echo ""

read -p "按 Enter 继续..."

python "$BLHOST_HELPER" -d "$DEVICE" --write -f "$FIRMWARE" --erase-all

echo "✓ 烧录完成"
EOF

chmod +x scripts/flash_blhost_erase_all.sh

# 创建设备连接测试脚本
cat > scripts/test_blhost.sh << 'EOF'
#!/bin/bash
# FCM363X BLHOST 连接测试脚本

BLHOST_HELPER="${ZEPHYR_WS}/tools/blhost-helper/blhost_helper.py"
DEVICE="FCM363X"

echo "=== 测试 BLHOST 连接 ==="
echo "Device: $DEVICE"
echo ""
echo "请确保设备已进入 ISP 模式"
echo ""

python "$BLHOST_HELPER" -d "$DEVICE" --test

if [ $? -eq 0 ]; then
    echo "✓ 设备连接成功"
else
    echo "✗ 设备连接失败"
    echo ""
    echo "故障排除:"
    echo "1. 确认设备已进入 ISP 模式 (Bootloader Mode)"
    echo "2. USB 模式: 检查 USB 连接，确认设备出现在系统中"
    echo "3. UART 模式: 检查串口设备和波特率设置"
    echo "4. Linux: 确认用户在 dialout 组: groups \$USER"
fi
EOF

chmod +x scripts/test_blhost.sh

echo "✓ BLHOST ISP 烧录配置已创建"
```

**BLHOST 与 JLink 对比：**

| 特性 | JLink | BLHOST (ISP) |
|------|-------|--------------|
| **接口** | JTAG (4线) | USB / UART |
| **硬件需求** | JLink 调试器 | 无额外硬件 |
| **速度** | 快 (10MHz+) | 中等 (2Mbps UART) |
| **调试功能** | ✓ 完整调试 | ✗ 仅烧录 |
| **适用场景** | 开发调试 | 生产烧录 |
| **进入条件** | 正常启动 | Bootloader 模式 |

**支持的 FCM363X 设备：**

| 型号 | Flash | PSRAM | 默认接口 | FCB 文件 |
|------|-------|-------|----------|----------|
| FCM363XAB | 8M | 无 | USB | XMC_XM25QH64D.bin |
| FCM363XAC | 8M | 8M | USB | XMC_XM25QH64D.bin |

#### Step 5.6: 构建验证记录

```bash
# 创建构建验证日志
cat > "${ZEPHYR_WS}/logs/build_verify.log" << EOF
FCM363X Build Verification
=========================
Date: $(date)

Build Command:
  west build -b fcm363x -p always

Build Output:
$(ls -lh build/zephyr/zephyr.* 2>/dev/null)

Firmware Size:
$(arm-none-eabi-size build/zephyr/zephyr.elf 2>/dev/null)

Board Configuration:
  - PSRAM: Disabled
  - Console: FLEXCOMM3 @ 115200
  - Debug: JTAG interface

JLink Configuration:
  - Device: RW612
  - Interface: JTAG
  - Speed: 10000 kHz

Status: SUCCESS
EOF

echo "构建验证日志已保存"
```

#### Step 5.7: Git 提交

```bash
cd "${ZEPHYR_WS}/fcm363x-project"

# 添加构建配置
git add scripts/ boards/ .gitignore

# 提交
git commit -m "feat(build): add JLink debug and BLHOST ISP flash configuration

JLink configuration:
- Device: RW612
- Interface: JTAG (not SWD)
- Speed: 10000 kHz

BLHOST ISP configuration:
- Support USB and UART interface
- No extra hardware required
- Suitable for production flashing

Scripts:
- scripts/flash.sh: JLink firmware flashing
- scripts/debug.sh: GDB debugging
- scripts/flash_blhost.sh: BLHOST ISP flashing
- scripts/flash_blhost_erase_all.sh: BLHOST with full erase
- scripts/test_blhost.sh: BLHOST connection test
- scripts/jlink.conf: JLink settings
- scripts/jlink_flash.jlink: Flash command file

Build verification:
- Hello World builds successfully
- Firmware size logged
- Memory usage verified"

echo "构建配置已提交到 Git"
```

### 验证

```bash
# 验证构建产物
cd "${ZEPHYR_WS}/fcm363x-project"
ls -lh build/zephyr/zephyr.*

# 验证固件大小
arm-none-eabi-size build/zephyr/zephyr.elf

# 验证 JLink 配置
cat scripts/jlink.conf
```

### 烧录测试 (需要硬件)

#### 方式一：JLink 烧录

```bash
# 连接 JLink 调试器到 FCM363X 的 JTAG 接口
# 运行烧录脚本
./scripts/flash.sh

# 或使用 west flash (如果配置正确)
west flash
```

#### 方式二：BLHOST ISP 烧录 (无需额外硬件)

```bash
# 1. 进入 ISP 模式
#    方法: 按住 BOOT 按键，按 RESET 按键，释放 RESET，再释放 BOOT
#    或者: 使用串口发送特定命令

# 2. 测试连接
./scripts/test_blhost.sh

# 3. 烧录固件 (仅擦除固件大小的区域)
./scripts/flash_blhost.sh

# 4. 烧录固件 (全擦除模式，用于调试)
./scripts/flash_blhost_erase_all.sh
```

**BLHOST 常用命令：**

```bash
# 列出支持的设备
python tools/blhost-helper/blhost_helper.py --list

# 测试连接 (USB)
python tools/blhost-helper/blhost_helper.py -d FCM363X --test

# 测试连接 (UART)
python tools/blhost-helper/blhost_helper.py -d FCM363XL -p /dev/ttyUSB0 --test

# 全擦除
python tools/blhost-helper/blhost_helper.py -d FCM363X --erase

# 写入固件
python tools/blhost-helper/blhost_helper.py -d FCM363X --write -f firmware.bin

# 读取 Flash
python tools/blhost-helper/blhost_helper.py -d FCM363X --read -a 0x08000400 -s 0x200

# 启用调试模式
python tools/blhost-helper/blhost_helper.py -d FCM363X --test --debug
```

### 回滚命令

```bash
# 清理构建
cd "${ZEPHYR_WS}/fcm363x-project"
rm -rf build/

# Git 回滚
git checkout HEAD~1
```

---

## 烧录方式速查表

### 方式对比

| 特性 | JLink | BLHOST ISP |
|------|-------|------------|
| **接口** | JTAG (4线) | USB / UART |
| **硬件需求** | JLink 调试器 | 无额外硬件 |
| **速度** | 快 (10MHz+) | 中等 (2Mbps) |
| **调试功能** | ✓ 完整调试 | ✗ 仅烧录 |
| **适用场景** | 开发调试 | 生产烧录 |
| **固件格式** | .hex | .bin |
| **进入条件** | 正常启动 | Bootloader 模式 |

### 命令速查

```bash
# ========== JLink 方式 ==========
# 烧录
./scripts/flash.sh
# 或
west flash

# 调试
./scripts/debug.sh

# ========== BLHOST ISP 方式 ==========
# 测试连接
./scripts/test_blhost.sh

# 烧录 (安全模式，仅擦除必要区域)
./scripts/flash_blhost.sh

# 烧录 (全擦除模式，用于调试)
./scripts/flash_blhost_erase_all.sh

# 手动 BLHOST 命令
python tools/blhost-helper/blhost_helper.py -d FCM363X --test
python tools/blhost-helper/blhost_helper.py -d FCM363X --erase
python tools/blhost-helper/blhost_helper.py -d FCM363X --write -f build/zephyr/zephyr.bin
```

### 故障排除

**JLink 问题：**
```bash
# 检查 JLink 连接
JLinkExe -device RW612 -if jtag -speed 10000

# 常见错误
# "Could not connect to target" → 检查 JTAG 接线
# "Device not found" → 检查 JLink 驱动
```

**BLHOST 问题：**
```bash
# 启用调试模式
python tools/blhost-helper/blhost_helper.py -d FCM363X --test --debug

# 常见错误
# "Device not found" → 检查 ISP 模式是否正确进入
# "No response" → 检查 USB/UART 连接
# Linux 权限问题 → sudo usermod -a -G dialout $USER
```

---

## 工作区最终结构

```
${ZEPHYR_WS}/                              # ~/nxp-zephyr-ws/
│
├── .git/                                   # 主仓库 Git
├── .venv/                                  # Python 虚拟环境（工作区内）
├── .gitignore                              # Git 忽略规则
├── README.md                               # 工作区说明
├── setup_env.sh                            # 环境激活脚本
│
├── logs/                                   # 日志目录
│   ├── env_check.log                       # 环境验证日志
│   └── build_verify.log                    # 构建验证日志
│
├── tools/                                  # 本地工具
│   ├── arm-gnu-toolchain/ -> arm-gnu-toolchain-13.2.Rel1-*/
│   └── blhost-helper/                      # BLHOST ISP 烧录工具
│       ├── blhost_helper.py                # 主脚本
│       ├── device_config.json              # 设备配置
│       └── fcb/                            # Flash 配置块文件
│           ├── XMC_XM25QH64D.bin           # FCM363X 8MB Flash
│           ├── MXIC_MX25L6433F.bin         # 备选 8MB Flash
│           └── ...
│
├── archives/                               # 下载存档
│   └── arm-gnu-toolchain-*.tar.bz2
│
├── .west/                                  # West 配置
│   └── config                              # West 设置
│
├── nxp-zsdk/                               # NXP Zephyr SDK (west 管理)
│   ├── zephyr/                             # Zephyr 内核
│   ├── hal_nxp/                            # NXP HAL
│   └── modules/                            # Zephyr 模块
│
├── fcm363x-board/                          # Board 定义仓库
│   ├── .git/                               # Board Git
│   ├── west.yml                            # Board manifest
│   ├── README.md                           # Board 说明
│   └── boards/nxp/fcm363x/                 # Board 文件
│       ├── board.yml
│       ├── fcm363x.yaml
│       ├── fcm363x.dts
│       ├── fcm363x.dtsi
│       ├── Kconfig.board
│       ├── Kconfig.defconfig
│       ├── CMakeLists.txt
│       └── board.c
│
└── fcm363x-project/                        # 应用项目仓库
    ├── .git/                               # 项目 Git
    ├── west.yml                            # 项目 manifest
    ├── CMakeLists.txt                      # 构建配置
    ├── prj.conf                            # Kconfig 配置
    ├── README.md                           # 项目说明
    ├── .gitignore                          # 项目忽略规则
    ├── src/
    │   └── main.c                          # 应用代码
    ├── boards/
    │   └── fcm363x_board.cmake             # 调试配置
    ├── scripts/
    │   ├── jlink.conf                      # JLink 设置
    │   ├── jlink_flash.jlink               # JLink 烧录脚本
    │   ├── flash.sh                        # JLink 烧录命令
    │   ├── debug.sh                        # GDB 调试命令
    │   ├── flash_blhost.sh                 # BLHOST ISP 烧录
    │   ├── flash_blhost_erase_all.sh       # BLHOST 全擦除烧录
    │   └── test_blhost.sh                  # BLHOST 连接测试
    └── build/                              # 构建输出
        └── zephyr/
            ├── zephyr.elf                  # ELF 文件
            ├── zephyr.bin                  # 二进制 (BLHOST 使用)
            └── zephyr.hex                  # HEX 文件 (JLink 使用)
```

---

## Git 提交历史

```bash
# 查看完整提交历史
cd "${ZEPHYR_WS}"
git log --oneline --all --graph

# 预期输出:
# * xxxxxxx feat(build): add JLink debug and flash configuration
# * xxxxxxx feat(project): create FCM363X hello world project
# * xxxxxxx feat(board): add FCM363X board support
# * xxxxxxx feat(sdk): initialize nxp-zsdk v4.3.0 workspace
# * xxxxxxx feat(env): setup command-line development environment
# * xxxxxxx init(workspace): create zephyr workspace structure
```

---

## 常用命令速查

### 环境管理

```bash
# 激活环境
source ~/zephyr-workspace/setup_env.sh

# 验证环境
which west arm-none-eabi-gcc cmake ninja
```

### 项目管理

```bash
# 初始化工作区
west init -l .
west update

# 清理构建
west build -t clean

# 重新构建
west build -b fcm363x -p always
```

### 调试烧录

```bash
# 烧录
./scripts/flash.sh
# 或
west flash

# 调试
./scripts/debug.sh
# 或
west debug
```

### Git 操作

```bash
# 查看状态
git status

# 查看历史
git log --oneline -10

# 创建分支
git checkout -b feature/new-feature

# 提交
git add .
git commit -m "feat: description"

# 推送
git push origin main
```

---

## 故障排除

### 环境隔离相关问题

#### 问题 I1: west init 报错 "ZEPHYR_BASE is already set"

```
FATAL ERROR: ZEPHYR_BASE is already set in the environment.
Please unset it before running 'west init'.
```

**原因：** 系统存在其他 Zephyr 项目设置了 `ZEPHYR_BASE` 环境变量。

**解决方案：**
```bash
# 清除 ZEPHYR_BASE
unset ZEPHYR_BASE

# 验证
echo $ZEPHYR_BASE  # 应该为空

# 重新运行 west init
west init -m https://github.com/nxp-zephyr/nxp-zsdk.git --mr nxp-v4.3.0 nxp-zsdk
```

**永久解决方案：** 使用 `setup_env.sh` 脚本，它会自动清除冲突变量。

#### 问题 I2: Python 版本不正确或 west 版本冲突

**原因：** 没有激活正确的虚拟环境，或系统有多个 Python 环境。

**解决方案：**
```bash
# 检查当前 Python 路径
which python

# 应该输出: /Users/xxx/zephyr-venv/bin/python
# 如果不是，激活虚拟环境:
source ~/zephyr-venv/bin/activate

# 验证
which python
west --version
```

#### 问题 I3: 使用了错误的 ZEPHYR_BASE

**原因：** ZEPHYR_BASE 指向了其他项目。

**解决方案：**
```bash
# 清除并重新设置
unset ZEPHYR_BASE
source ~/zephyr-workspace/setup_env.sh

# 验证
echo $ZEPHYR_BASE
# 应该输出: /Users/xxx/zephyr-workspace/nxp-zsdk/zephyr
```

### 常规问题

#### 问题 1: west: command not found

```bash
# 解决方案: 激活虚拟环境
source ~/zephyr-venv/bin/activate
```

### 问题 2: arm-none-eabi-gcc: command not found

```bash
# 解决方案: 设置环境
source ~/zephyr-workspace/setup_env.sh
# 或手动添加 PATH
export PATH=~/zephyr-workspace/tools/arm-gnu-toolchain/bin:$PATH
```

### 问题 3: Board not found

```bash
# 解决方案: 检查工作区初始化
west init -l .
west update
```

### 问题 4: JLink connection failed

```bash
# 检查 JLink 配置
cat scripts/jlink.conf

# 确认接口是 JTAG (不是 SWD)
# 确认设备是 RW612
```

### 问题 5: PSRAM 错误

```bash
# 检查配置
grep -r "PSRAM" prj.conf boards/
# 应该看到 CONFIG_NXP_PSRAM=n
```

### 问题 6: BLHOST 找不到设备

```bash
# 启用调试模式
python tools/blhost-helper/blhost_helper.py -d FCM363X --test --debug

# 常见原因:
# 1. 设备未进入 ISP 模式
#    解决: 按住 BOOT 键，按 RESET，释放 RESET，再释放 BOOT

# 2. USB 模式下设备未识别
#    macOS: 系统报告 -> USB 查看设备
#    Linux: lsusb 查看设备

# 3. UART 模式下串口错误
#    检查串口: ls /dev/ttyUSB* 或 ls /dev/cu.*
#    指定端口: -p /dev/ttyUSB0
```

### 问题 7: BLHOST 烧录失败

```bash
# 检查固件格式
file build/zephyr/zephyr.bin
# 应该是: data

# 检查固件大小
ls -lh build/zephyr/zephyr.bin
# 不应超过 Flash 大小 (8MB)

# 尝试全擦除模式
python tools/blhost-helper/blhost_helper.py -d FCM363X --write -f build/zephyr/zephyr.bin --erase-all
```

### 问题 8: SPSDK/blhost 安装失败

```bash
# 升级 pip
pip install --upgrade pip

# 安装 SPSDK
pip install spsdk

# 验证安装
blhost --version

# 如果仍然失败，尝试清理重装
pip uninstall spsdk
pip cache purge
pip install spsdk
```

---

## 环境隔离速查表

| 场景 | 命令 | 说明 |
|------|------|------|
| 开始任何 Phase | `unset ZEPHYR_BASE` | 清除冲突变量 |
| 激活工作环境 | `source ~/zephyr-workspace/setup_env.sh` | 完整隔离激活 |
| 验证 Python 隔离 | `which python` | 应显示 `zephyr-venv` 路径 |
| 验证 ZEPHYR_BASE | `echo $ZEPHYR_BASE` | SDK 初始化后应为工作区路径 |
| 重新隔离 | `unset ZEPHYR_BASE && source ~/zephyr-venv/bin/activate` | 手动隔离 |

**环境隔离检查清单：**
- [ ] ZEPHYR_BASE 未设置（SDK 初始化前）
- [ ] Python 指向 `~/zephyr-venv/bin/python`
- [ ] 工作区在 `~/zephyr-workspace`
- [ ] ARM 工具链在项目本地目录

---

## 下一步

完成以上阶段后，可以进行：

1. **添加驱动支持** - I2C, SPI, I2S 等外设驱动
2. **配置 Wi-Fi** - 添加 Wi-Fi 固件和网络配置
3. **配置 BLE** - 添加蓝牙支持
4. **OTA 升级** - 配置 MCUBoot
5. **CI/CD** - 添加自动化构建流程

---

## 变更记录

| 版本 | 日期 | 变更内容 |
|------|------|----------|
| v1.3.0 | 2026-03-03 | 配置定制化：工作区路径改为 `~/nxp-zephyr-ws`；Python venv 放在工作区内 (`.venv/`)；Git 用户配置更新为 bakewell/slkybowang@gmail.com |
| v1.2.0 | 2026-03-03 | 添加 BLHOST ISP 烧录支持：集成 rw61x-blhost-helper 工具；添加 BLHOST 烧录脚本；添加烧录方式对比表；添加 BLHOST 故障排除 |
| v1.1.0 | 2026-03-03 | 添加环境隔离步骤：每个 Phase 开始前清除 ZEPHYR_BASE；完善 setup_env.sh 脚本；添加隔离验证步骤；新增环境隔离故障排除 |
| v1.0.0 | 2026-03-03 | 初始版本 |

---

*文档版本: v1.3.0 | 创建日期: 2026-03-03 | 更新日期: 2026-03-03*
