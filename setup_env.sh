#!/bin/bash
#
# FCM363X Zephyr 环境激活脚本
# 
# 功能：
# 1. 清除冲突的环境变量（ZEPHYR_BASE 等）
# 2. 激活独立的 Python 虚拟环境
# 3. 设置工作区环境变量
# 4. 配置 ARM 工具链路径（使用系统已安装的工具链）
# 5. 验证隔离效果
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
# 5. 配置 ARM 工具链（使用系统已安装）
# ========================================

echo ""
echo "=== 步骤 5: 配置 ARM 工具链 ==="

# 使用系统已安装的 ARM 工具链
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
# 6. 隔离效果验证
# ========================================

echo ""
echo "=== 步骤 6: 隔离效果验证 ==="

# 检查 Python 隔离
PYTHON_PATH=$(which python)
if [[ "$PYTHON_PATH" == *"$ZEPHYR_VENV"* ]]; then
    echo "✓ Python 隔离: $PYTHON_PATH"
else
    echo "✗ Python 隔离失败: $PYTHON_PATH"
fi

# ========================================
# 7. 显示工作区信息
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
echo ""
echo "常用命令:"
echo "  cd \$ZEPHYR_WS          # 进入工作区"
echo "  west build -b fcm363x   # 构建"
echo "  west flash              # 烧录"
echo ""
