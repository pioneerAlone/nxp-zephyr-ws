#!/bin/bash
# FCM363X Zephyr Development Environment Setup
set -e

#===========================================
# SDK Version Configuration
#===========================================
# Change this to use a different SDK version
# Use "latest" to auto-detect latest version
SDK_VERSION="${SDK_VERSION:-nxp-v4.3.0}"
SDK_REPO="https://github.com/nxp-zephyr/nxp-zsdk.git"

#===========================================
# Colors and Output Functions
#===========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { printf '%b\n' "${BLUE}[INFO]${NC} $1"; }
success() { printf '%b\n' "${GREEN}[OK]${NC} $1"; }
warn()    { printf '%b\n' "${YELLOW}[WARN]${NC} $1"; }
error()   { printf '%b\n' "${RED}[ERROR]${NC} $1"; }
step()    { printf '%b\n' "${CYAN}==>${NC} $1"; }

detect_os() {
    case "$(uname -s)" in
        Darwin*)    echo "macos" ;;
        Linux*)     echo "linux" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *)          echo "unknown" ;;
    esac
}

get_latest_sdk_version() {
    # 获取最新 SDK 版本 tag
    git ls-remote --tags "$SDK_REPO" 2>/dev/null | \
        awk -F'/' '{print $3}' | \
        grep '^nxp-v' | \
        grep -v '\^{}$' | \
        sort -V | \
        tail -1
}

list_sdk_versions() {
    # 列出所有可用的 SDK 版本
    echo ""
    echo "=========================================="
    echo "  Available NXP Zephyr SDK Versions"
    echo "=========================================="
    echo ""
    
    local versions
    versions=$(git ls-remote --tags "$SDK_REPO" 2>/dev/null | \
        awk -F'/' '{print $3}' | \
        grep '^nxp-v' | \
        grep -v '\^{}$' | \
        sort -V)
    
    if [[ -z "$versions" ]]; then
        error "Failed to fetch versions from GitHub"
        return 1
    fi
    
    local latest
    latest=$(echo "$versions" | tail -1)
    
    echo "$versions" | while read -r ver; do
        if [[ "$ver" == "$latest" ]]; then
            echo "  * $ver (latest)"
        else
            echo "    $ver"
        fi
    done
    
    echo ""
    echo "Usage:"
    echo "  SDK_VERSION=nxp-v4.3.0 source setup_env.sh --init-sdk"
    echo "  SDK_VERSION=latest source setup_env.sh --init-sdk"
    echo ""
}

resolve_sdk_version() {
    # 解析 SDK 版本，支持 "latest" 关键字
    if [[ "$SDK_VERSION" == "latest" ]]; then
        local latest
        latest=$(get_latest_sdk_version)
        if [[ -n "$latest" ]]; then
            SDK_VERSION="$latest"
            info "Latest SDK version: $SDK_VERSION"
        else
            warn "Failed to detect latest version, using default: nxp-v4.3.0"
            SDK_VERSION="nxp-v4.3.0"
        fi
    fi
    export SDK_VERSION
}

OS=$(detect_os)

# WORKSPACE 路径检测
# 在 bash -c "source setup_env.sh" 模式下，$0 是 "-bash" 不可用
# 需要使用备选方法检测工作区路径
detect_workspace() {
    # 方法1: $0 是有效脚本路径
    if [[ -f "${BASH_SOURCE[0]}" ]] && [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
        cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
        return
    fi
    
    # 方法2: 当前目录有 setup_env.sh
    if [[ -f "$PWD/setup_env.sh" ]]; then
        echo "$PWD"
        return
    fi
    
    # 方法3: 已设置 ZEPHYR_WS 环境变量
    if [[ -n "$ZEPHYR_WS" ]] && [[ -f "$ZEPHYR_WS/setup_env.sh" ]]; then
        echo "$ZEPHYR_WS"
        return
    fi
    
    # 方法4: 向上查找包含 setup_env.sh 的目录
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/setup_env.sh" ]]; then
            echo "$dir"
            return
        fi
        dir=$(dirname "$dir")
    done
    
    # 方法5: 回退到 $0（可能在传统 source 模式下工作）
    if [[ -f "$0" ]] && [[ "$0" != "-bash" ]] && [[ "$0" != "bash" ]]; then
        cd "$(dirname "$0")" && pwd
        return
    fi
    
    # 最后回退到当前目录
    echo "$PWD"
}

if [[ "$OS" == "windows" ]]; then
    WORKSPACE="$(cygpath -m "$(detect_workspace)")"
    HOME_DIR="$USERPROFILE"
else
    WORKSPACE="$(detect_workspace)"
    HOME_DIR="$HOME"
fi

export ZEPHYR_WS="$WORKSPACE"
export ZEPHYR_VENV="${WORKSPACE}/.venv"

check_git() {
    if command -v git >/dev/null 2>&1; then
        success "Git: $(git --version | awk '{print $3}')"
        return 0
    fi
    error "Git not found!"
    echo "  Download: https://git-scm.com/downloads"
    return 1
}

check_python() {
    local py=""
    command -v python3 >/dev/null 2>&1 && py="python3"
    command -v python >/dev/null 2>&1 && py="python"
    
    if [[ -n "$py" ]]; then
        local ver
        ver=$($py --version 2>&1 | awk '{print $2}')
        local major minor
        major=$(echo "$ver" | cut -d. -f1)
        minor=$(echo "$ver" | cut -d. -f2)
        if [[ $major -ge 3 && $minor -ge 10 ]] || [[ $major -gt 3 ]]; then
            success "Python: $ver"
            export PYTHON_CMD="$py"
            return 0
        fi
        error "Python too old: $ver (need 3.10+)"
        return 1
    fi
    error "Python not found!"
    return 1
}

check_west() {
    if command -v west >/dev/null 2>&1; then
        success "West: $(west --version 2>&1 | head -1)"
        return 0
    fi
    warn "West not installed"
    echo "  Install: pip install west"
    return 1
}

check_jlink() {
    # JLink 命令名因平台不同
    local jlink_cmd=""
    case "$OS" in
        macos)  jlink_cmd="JLinkExe" ;;
        linux)  jlink_cmd="JLinkExe" ;;
        windows) jlink_cmd="JLink.exe" ;;
    esac
    
    if command -v "$jlink_cmd" >/dev/null 2>&1; then
        local jlink_path
        jlink_path=$(command -v "$jlink_cmd")
        success "JLink: found"
        success "  Path: $jlink_path"
        # 设置 JLink 目录
        export JLINK_DIR=$(dirname "$(dirname "$jlink_path")")
        return 0
    fi
    
    warn "JLink not found in PATH"
    echo "  Download: https://www.segger.com/downloads/jlink/"
    return 1
}

check_arm_gcc() {
    # 直接检测 arm-none-eabi-gcc 是否在 PATH 中
    local gcc_bin=""
    if command -v arm-none-eabi-gcc >/dev/null 2>&1; then
        gcc_bin=$(command -v arm-none-eabi-gcc)
    fi
    
    if [[ -n "$gcc_bin" ]]; then
        local ver
        ver=$(arm-none-eabi-gcc --version 2>/dev/null | head -1)
        success "ARM GCC: $ver"
        success "  Path: $gcc_bin"
        # 设置工具链路径 (从 bin 目录向上查找)
        local toolchain_dir
        toolchain_dir=$(dirname "$(dirname "$gcc_bin")")
        export GNUARMEMB_TOOLCHAIN_PATH="$toolchain_dir"
        export ARM_TOOLCHAIN_FOUND=1
        return 0
    fi
    
    # 未找到
    warn "ARM GCC not found in PATH"
    echo "  Install from: https://developer.arm.com/tools-and-software/open-source-software/developer-tools/gnu-toolchain/gnu-rm"
    echo '  Or use: brew install --cask gcc-aarch64-embedded (macOS)'
    export ARM_TOOLCHAIN_FOUND=0
    return 1
}

check_all_dependencies() {
    echo ""
    echo "=========================================="
    echo "  Dependency Check"
    echo "=========================================="
    echo ""
    local failed=0
    step "Checking Git..."; check_git || failed=$((failed + 1)); echo ""
    step "Checking Python..."; check_python || failed=$((failed + 1)); echo ""
    step "Checking West..."; check_west || true; echo ""
    step "Checking ARM Toolchain..."; check_arm_gcc || true; echo ""
    step "Checking JLink..."; check_jlink || true; echo ""
    [[ $failed -eq 0 ]] && success "All required dependencies satisfied"
    return $failed
}

clear_env() {
    step "Clearing conflicting env vars..."
    unset ZEPHYR_BASE ZEPHYR_SDK_INSTALL_DIR ZEPHYR_MODULES 2>/dev/null || true
    success "Done"
}

clone_tools() {
    step "Cloning external tools..."
    mkdir -p "$WORKSPACE/tools"
    
    local blhost="$WORKSPACE/tools/rw61x-blhost-helper"
    local jlink_patch="$WORKSPACE/tools/jlink_patch"
    
    if [ -d "$blhost" ]; then
        info "blhost helper exists"
    else
        info "Cloning blhost helper..."
        git clone --depth 1 https://github.com/Quectel-ShortRange/rw61x-blhost-helper.git "$blhost"
    fi
    
    if [ -d "$jlink_patch" ]; then
        info "jlink_patch exists"
    else
        info "Cloning jlink_patch..."
        git clone --depth 1 https://github.com/Quectel-ShortRange/jlink_patch.git "$jlink_patch"
    fi
    success "Tools ready"
}

install_jlink_patch() {
    step "Installing JLink patch..."
    [[ -z "$JLINK_DIR" ]] && { warn "JLink not installed, skipping"; return 0; }
    
    local dest=""
    case "$OS" in
        macos)  dest="$HOME/Library/Application Support/SEGGER/JLinkDevices" ;;
        linux)  dest="$HOME/.config/SEGGER/JLinkDevices" ;;
        windows) dest="$APPDATA/SEGGER/JLinkDevices" ;;
    esac
    
    [ -d "$dest/Devices/QUECTEL/FCM363X" ] && { success "JLink patch already installed"; return 0; }
    
    mkdir -p "$dest"
    cp -r "$WORKSPACE/tools/jlink_patch/JLinkDevices"/* "$dest/" 2>/dev/null || true
    success "JLink patch installed"
}

setup_venv() {
    step "Setting up Python venv..."
    if [ ! -d "$ZEPHYR_VENV" ]; then
        info "Creating venv..."
        ${PYTHON_CMD:-python3} -m venv "$ZEPHYR_VENV"
        "$ZEPHYR_VENV/bin/pip" install -q west
    fi
    source "$ZEPHYR_VENV/bin/activate"
    success "venv: $(which python)"
}

init_sdk() {
    step "Initializing NXP Zephyr SDK..."
    
    # 检查 west 是否可用
    if ! command -v west >/dev/null 2>&1; then
        error "west not found. Please activate venv first."
        return 1
    fi
    
    # 检查是否已初始化
    if [ -d "$WORKSPACE/nxp-zsdk/zephyr" ]; then
        info "SDK already initialized at $WORKSPACE/nxp-zsdk"
        return 0
    fi
    
    # 解析版本号 (支持 "latest")
    resolve_sdk_version
    
    # 清除可能冲突的环境变量
    unset ZEPHYR_BASE 2>/dev/null || true
    
    # west init
    info "Running: west init -m $SDK_REPO --mr $SDK_VERSION nxp-zsdk"
    west init -m "$SDK_REPO" --mr "$SDK_VERSION" nxp-zsdk || {
        error "west init failed"
        return 1
    }
    
    # west update
    info "Running: west update (this may take 10-20 minutes)..."
    cd "$WORKSPACE/nxp-zsdk"
    west update || {
        error "west update failed"
        return 1
    }
    
    # 安装 Python 依赖
    info "Installing Python dependencies..."
    pip install -q -r zephyr/scripts/requirements.txt || {
        warn "Failed to install some Python dependencies"
    }
    
    cd "$WORKSPACE"
    success "SDK initialized: $WORKSPACE/nxp-zsdk"
}

setup_zephyr() {
    step "Setting up Zephyr..."
    [ -d "$WORKSPACE/nxp-zsdk/zephyr" ] && { export ZEPHYR_BASE="$WORKSPACE/nxp-zsdk/zephyr"; success "ZEPHYR_BASE set"; }
    [ -d "$WORKSPACE/fcm363x-board" ] && { export BOARD_ROOT="$WORKSPACE/fcm363x-board"; success "BOARD_ROOT set"; }
}

setup_path() {
    step "Updating PATH..."
    [ -d "$WORKSPACE/tools/rw61x-blhost-helper" ] && export PATH="$WORKSPACE/tools/rw61x-blhost-helper:$PATH"
    success "Done"
}

print_summary() {
    echo ""
    echo "=========================================="
    echo "  FCM363X Zephyr Environment Ready"
    echo "=========================================="
    echo ""
    echo "Workspace:     $WORKSPACE"
    echo "OS:            $OS"
    echo "Python:        $(python --version 2>&1)"
    echo "SDK Version:   $SDK_VERSION"
    
    if [[ "$ARM_TOOLCHAIN_FOUND" == "1" ]]; then
        echo "ARM GCC:       $GNUARMEMB_TOOLCHAIN_PATH"
    else
        echo 'ARM GCC:       (using Zephyr SDK built-in)'
    fi
    
    echo "JLink:         ${JLINK_DIR:-not installed}"
    echo "ZEPHYR_BASE:   ${ZEPHYR_BASE:-not set}"
    echo "BOARD_ROOT:    ${BOARD_ROOT:-not set}"
    echo ""
    echo "Usage:"
    echo "  source setup_env.sh               # Activate environment"
    echo "  source setup_env.sh --init-sdk    # Initialize NXP Zephyr SDK"
    echo "  source setup_env.sh --install     # Install JLink patch, blhost"
    echo "  source setup_env.sh --list-versions # List available SDK versions"
    echo "  source setup_env.sh --check       # Check dependencies only"
    echo ""
    echo "SDK Version Override:"
    echo "  SDK_VERSION=nxp-v4.3.0 source setup_env.sh --init-sdk"
    echo "  SDK_VERSION=latest source setup_env.sh --init-sdk"
    echo ""
    echo "Build:"
    echo "  cd \$ZEPHYR_WS/fcm363x-examples/hello && west build -b fcm363x"
    echo ""
    echo "Flash (JLink):"
    echo "  west flash"
    echo ""
}

main() {
    # --list-versions: 列出可用 SDK 版本
    if [[ "$1" == "--list-versions" ]]; then
        list_sdk_versions
        return 0
    fi
    
    echo ""
    echo "=========================================="
    echo "  FCM363X Zephyr Setup"
    echo "=========================================="
    echo ""
    info "OS: $OS"
    info "Workspace: $WORKSPACE"
    info "SDK Version: $SDK_VERSION"
    
    check_all_dependencies || true
    
    # --check: 仅检查依赖
    [[ "$1" == "--check" ]] && return 0
    
    # --init-sdk: 初始化 NXP Zephyr SDK
    if [[ "$1" == "--init-sdk" ]]; then
        setup_venv
        init_sdk || return 1
        setup_zephyr
        print_summary
        return 0
    fi
    
    # --install: 安装工具 (JLink patch, blhost)
    [[ "$1" == "--install" ]] && { clone_tools; install_jlink_patch; }
    
    # 检查 SDK 是否已初始化
    if [ ! -d "$WORKSPACE/nxp-zsdk/zephyr" ]; then
        echo ""
        warn "NXP Zephyr SDK not found!"
        echo "  Run: source setup_env.sh --init-sdk"
        echo "  Or specify version: SDK_VERSION=nxp-v4.3.0 source setup_env.sh --init-sdk"
        echo "  List versions: source setup_env.sh --list-versions"
        echo ""
    fi
    
    # ARM 工具链未找到时提示 (Zephyr SDK 有内置工具链，可选)
    if [[ "$ARM_TOOLCHAIN_FOUND" != "1" ]]; then
        echo ""
        info "ARM Toolchain not in PATH. Zephyr SDK will use built-in toolchain."
        echo ""
    fi
    
    clear_env
    setup_venv
    setup_zephyr
    setup_path
    print_summary
    
    # 设置提示符：显示 venv 激活状态和当前目录
    # 仅在交互式 shell 中设置
    if [[ $- == *i* ]] || [[ -n "$PS1" ]]; then
        export PS1="(.venv) \w\$ "
    fi
}

main "$@"
