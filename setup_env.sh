#!/bin/bash
#
# FCM363X Zephyr Development Environment Setup
# Cross-platform: macOS, Linux, Windows (Git Bash)
#
# Usage:
#   source setup_env.sh          # Activate environment
#   ./setup_env.sh --install     # Install tools first
#
set -e

# ========================================
# Color Definitions
# ========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# ========================================
# Detect Operating System
# ========================================
detect_os() {
    case "$(uname -s)" in
        Darwin*)    echo "macos" ;;
        Linux*)     echo "linux" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *)          echo "unknown" ;;
    esac
}

OS=$(detect_os)
info "Detected OS: $OS"

# ========================================
# Workspace Paths
# ========================================
if [[ "$OS" == "windows" ]]; then
    # Git Bash on Windows
    WORKSPACE="$(cygpath -m "$(cd "$(dirname "$0")" && pwd")"
    HOME_DIR="$USERPROFILE"
else
    WORKSPACE="$(cd "$(dirname "$0")" && pwd)"
    HOME_DIR="$HOME"
fi

export ZEPHYR_WS="$WORKSPACE"
export ZEPHYR_VENV="${WORKSPACE}/.venv"

info "Workspace: $WORKSPACE"

# ========================================
# Clear Conflicting Environment Variables
# ========================================
clear_env() {
    info "Clearing conflicting environment variables..."
    unset ZEPHYR_BASE 2>/dev/null || true
    unset ZEPHYR_SDK_INSTALL_DIR 2>/dev/null || true
    unset ZEPHYR_MODULES 2>/dev/null || true
    unset ZEPHYR_MODULES_CMAKE 2>/dev/null || true
    success "Environment variables cleared"
}

# ========================================
# Clone Tools from GitHub
# ========================================
clone_tools() {
    info "Checking and cloning tools..."
    
    mkdir -p "$WORKSPACE/tools"
    
    # Tool definitions: "directory:repo_url"
    local tools=(
        "rw61x-blhost-helper:https://github.com/Quectel-ShortRange/rw61x-blhost-helper.git"
        "jlink_patch:https://github.com/Quectel-ShortRange/jlink_patch.git"
    )
    
    for item in "${tools[@]}"; do
        local dir="${item%%:*}"
        local url="${item#*:}"
        local target="$WORKSPACE/tools/$dir"
        
        if [ -d "$target" ]; then
            success "Tool '$dir' already exists"
        else
            info "Cloning '$dir'..."
            git clone --depth 1 "$url" "$target"
            success "Cloned '$dir'"
        fi
    done
}

# ========================================
# Install JLink Patch
# ========================================
install_jlink_patch() {
    info "Installing JLink device patch..."
    
    local src_dir="$WORKSPACE/tools/jlink_patch/JLinkDevices"
    local dest_dir=""
    
    # Get JLink devices directory based on OS
    case "$OS" in
        macos)
            dest_dir="$HOME_DIR/Library/Application Support/SEGGER/JLinkDevices"
            ;;
        linux)
            dest_dir="$HOME_DIR/.config/SEGGER/JLinkDevices"
            ;;
        windows)
            dest_dir="$APPDATA/SEGGER/JLinkDevices"
            ;;
        *)
            warn "Unsupported OS for JLink patch: $OS"
            return 0
            ;;
    esac
    
    # Check if source exists
    if [ ! -d "$src_dir" ]; then
        warn "JLink patch source not found: $src_dir"
        warn "Run with --install to clone tools first"
        return 0
    fi
    
    # Check if already installed
    if [ -d "$dest_dir/Devices/QUECTEL/FCM363X" ]; then
        success "JLink patch already installed"
        return 0
    fi
    
    # Install
    info "Installing to: $dest_dir"
    mkdir -p "$dest_dir"
    cp -r "$src_dir"/* "$dest_dir/"
    success "JLink patch installed successfully"
}

# ========================================
# Setup Python Virtual Environment
# ========================================
setup_venv() {
    info "Setting up Python virtual environment..."
    
    if [ ! -d "$ZEPHYR_VENV" ]; then
        info "Creating virtual environment..."
        python3 -m venv "$ZEPHYR_VENV"
    fi
    
    # Activate venv (OS-specific path)
    if [[ "$OS" == "windows" ]]; then
        source "$ZEPHYR_VENV/Scripts/activate"
    else
        source "$ZEPHYR_VENV/bin/activate"
    fi
    
    success "Python venv activated: $(which python)"
}

# ========================================
# Setup ARM Toolchain
# ========================================
setup_toolchain() {
    info "Setting up ARM toolchain..."
    
    # Try common paths based on OS
    local toolchain_paths=()
    
    case "$OS" in
        macos)
            toolchain_paths=(
                "/usr/local/arm-none-eabi"
                "/opt/homebrew/opt/arm-none-eabi"
                "$HOME_DIR/arm-toolchain"
            )
            ;;
        linux)
            toolchain_paths=(
                "/usr/local/arm-none-eabi"
                "/opt/arm-none-eabi"
                "$HOME_DIR/arm-toolchain"
            )
            ;;
        windows)
            toolchain_paths=(
                "C:/Program Files (x86)/GNU Arm Embedded Toolchain"
                "C:/Program Files/GNU Arm Embedded Toolchain"
                "$HOME_DIR/arm-toolchain"
            )
            ;;
    esac
    
    for path in "${toolchain_paths[@]}"; do
        if [ -d "$path/bin" ] && [ -x "$path/bin/arm-none-eabi-gcc" ] || \
           [ -x "$path/bin/arm-none-eabi-gcc.exe" ]; then
            export GNUARMEMB_TOOLCHAIN_PATH="$path"
            export PATH="$path/bin:$PATH"
            success "ARM toolchain: $path"
            return 0
        fi
    done
    
    warn "ARM toolchain not found, will use Zephyr SDK toolchain"
}

# ========================================
# Setup Zephyr Environment
# ========================================
setup_zephyr() {
    info "Setting up Zephyr environment..."
    
    if [ -d "$WORKSPACE/nxp-zsdk/zephyr" ]; then
        export ZEPHYR_BASE="$WORKSPACE/nxp-zsdk/zephyr"
        success "ZEPHYR_BASE: $ZEPHYR_BASE"
    else
        warn "nxp-zsdk not initialized. Run 'west init' first"
    fi
    
    if [ -d "$WORKSPACE/fcm363x-board" ]; then
        export BOARD_ROOT="$WORKSPACE/fcm363x-board"
        success "BOARD_ROOT: $BOARD_ROOT"
    else
        warn "fcm363x-board not found"
    fi
}

# ========================================
# Add Tools to PATH
# ========================================
setup_path() {
    info "Adding tools to PATH..."
    
    # blhost helper
    local blhost_dir="$WORKSPACE/tools/rw61x-blhost-helper"
    if [ -d "$blhost_dir" ]; then
        export PATH="$blhost_dir:$PATH"
        success "blhost helper in PATH"
    fi
}

# ========================================
# Print Summary
# ========================================
print_summary() {
    echo ""
    echo "=========================================="
    echo "  FCM363X Zephyr Environment Ready"
    echo "=========================================="
    echo ""
    echo "Workspace:     $WORKSPACE"
    echo "OS:            $OS"
    echo "Python:        $(python --version 2>&1)"
    echo "West:          $(west --version 2>&1 | head -1 || echo 'not installed')"
    echo "ARM GCC:       ${GNUARMEMB_TOOLCHAIN_PATH:-using Zephyr SDK}"
    echo "BOARD_ROOT:    ${BOARD_ROOT:-<not set>}"
    echo ""
    echo "Quick Commands:"
    echo "  cd \$ZEPHYR_WS              # Go to workspace"
    echo "  west build -b fcm363x       # Build for FCM363X"
    echo "  blhost_helper.py --help     # Flash programming"
    echo ""
}

# ========================================
# Main
# ========================================
main() {
    echo ""
    echo "=========================================="
    echo "  FCM363X Zephyr Setup"
    echo "=========================================="
    echo ""
    
    # Check for --install flag
    if [ "$1" == "--install" ]; then
        clone_tools
        install_jlink_patch
    fi
    
    clear_env
    setup_venv
    setup_toolchain
    setup_zephyr
    setup_path
    
    # Also install JLink patch if tools exist
    if [ -d "$WORKSPACE/tools/jlink_patch" ]; then
        install_jlink_patch
    fi
    
    print_summary
}

# Run main function
main "$@"
