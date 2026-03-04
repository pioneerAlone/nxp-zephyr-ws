# FCM363X vs FRDM-RW612 硬件配置对比分析

**Domain:** 嵌入式无线 IoT 模块
**Researched:** 2026-03-03
**Overall confidence:** HIGH

## Executive Summary

FCM363X 是 Quectel 基于 NXP RW612 芯片开发的无线模块，与 NXP 官方 FRDM-RW612 开发板采用同一芯片（RW612ETA2I）。本文档详细对比两者的硬件配置差异，为 Zephyr 移植提供关键参数。

**核心发现:**
- 两者 **芯片完全相同**（RW612ETA2I），底层驱动可直接复用
- **时钟配置完全一致**（260MHz 主频，40MHz 外部晶振）
- **主要差异在于 Flash 配置**：FCM363X 使用 8MB Flash，FRDM-RW612 使用 64MB
- **调试引脚差异**：FCM363X 引脚位置 F3，FRDM-RW612 引脚位置 E5
- **PSRAM 配置相同**：两者均配置了 64Mb PSRAM（但可选禁用）

---

## 1. FCM363X 硬件配置分析

### 1.1 基础配置 (board.h)

| 配置项 | 值 | 说明 |
|--------|-----|------|
| `BOARD_NAME` | `"FCM363X"` | 板子名称标识 |
| `DEBUG_CONSOLE_UART_INDEX` | `3` | 默认调试 UART 为 FLEXCOMM3 |
| `BOARD_DEBUG_UART_BAUDRATE` | `115200` | 调试串口波特率 |
| `BOARD_FLEXSPI_PSRAM` | `FLEXSPI` | PSRAM 控制器 |
| `BOARD_ENABLE_PSRAM_CACHE` | `1` | 启用 PSRAM 缓存 |
| `BOARD_LED_BLUE_GPIO_PIN` | `0U` | LED 蓝灯引脚 GPIO0[0] |
| `BOARD_SW2_GPIO_PIN` | `11U` | 按键 SW2 引脚 GPIO0[11] |
| `BOARD_ENET0_PHY_ADDRESS` | `0x02U` | 以太网 PHY 地址 |

### 1.2 UART 调试配置

```c
// FCM363X 调试串口配置 (FLEXCOMM3)
#define BOARD_DEBUG_UART_BASEADDR   (uint32_t) FLEXCOMM3
#define BOARD_DEBUG_UART_INSTANCE   3U
#define BOARD_DEBUG_UART            USART3
#define BOARD_DEBUG_UART_CLK_FREQ   CLOCK_GetFlexCommClkFreq(3)
#define BOARD_DEBUG_UART_CLK_ATTACH kFRG_to_FLEXCOMM3
```

### 1.3 引脚配置 (pin_mux.c)

```c
// FCM363X 默认引脚配置
void BOARD_InitPins(void)
{
    /* Initialize FC3_USART_DATA functionality on pin GPIO_24 (pin F3) */
    IO_MUX_SetPinMux(IO_MUX_FC3_USART_DATA);
}
```

**关键引脚映射:**
- GPIO_24 (pin F3) → FLEXCOMM3 USART (调试串口)

### 1.4 时钟配置 (clock_config.c/h)

| 时钟输出 | 频率 | 说明 |
|----------|------|------|
| `MAIN_CLK` | 260 MHz | 主系统时钟 |
| `HCLK` | 260 MHz | AHB 总线时钟 |
| `AUX0_PLL_CLK` | 260 MHz | 辅助 PLL 输出 |
| `TDDR_MCI_FLEXSPI_CLK` | 320 MHz | FlexSPI 时钟 |
| `REFCLK_PHY` | 40 MHz | PHY 参考时钟 |
| `CLK_32K` | 32 kHz | RTC 时钟 |
| `ELS_128M_CLK` | 128 MHz | ELS 安全模块时钟 |
| `ELS_256M_CLK` | 256 MHz | ELS 高速时钟 |

**时钟源配置:**
- 外部晶振: 40 MHz (CAU.XTAL_OSC)
- 无外部 32.768 kHz 晶振（使用内部 RC32K）

### 1.5 Flash 配置 (flash_config.c)

| 配置项 | FCM363X | 说明 |
|--------|---------|------|
| `sflashA1Size` | `0x800000U` (8 MB) | 连接到 A1 的 Flash 大小 |
| `sflashPadType` | `kSerialFlash_4Pads` | 四线模式 |
| `serialClkFreq` | `7` (133 MHz) | Flash 串行时钟频率 |
| `pageSize` | `0x100` (256 bytes) | 页大小 |
| `sectorSize` | `0x1000` (4 KB) | 扇区大小 |
| `blockSize` | `0x8000` (32 KB) | 块大小 |
| `deviceModeArg` | `0x0200` | Quad Enable 参数 |

**Flash LUT (Look-Up Table) 配置:**

| 序号 | 命令 | 说明 |
|------|------|------|
| 0 | `0xEB` (Quad Read) | 四线快速读取，24 位地址 |
| 1 | `0x05` (Read Status) | 读取状态寄存器 |
| 2 | `0x01` (Write Status) | 写入状态寄存器 |
| 3 | `0x06` (Write Enable) | 写使能 |
| 5 | `0x20` (Sector Erase) | 扇区擦除，24 位地址 |
| 8 | `0x52` (Block Erase) | 块擦除，24 位地址 |
| 9 | `0x02` (Page Program) | 页编程，单线模式 |
| 11 | `0x60` (Chip Erase) | 全片擦除 |

---

## 2. FRDM-RW612 硬件配置分析

### 2.1 基础配置 (board.h)

| 配置项 | 值 | 说明 |
|--------|-----|------|
| `BOARD_NAME` | `"FRDM-RW612"` | 板子名称标识 |
| `DEBUG_CONSOLE_UART_INDEX` | `3` | 默认调试 UART 为 FLEXCOMM3 |
| `BOARD_DEBUG_UART_BAUDRATE` | `115200` | 调试串口波特率 |
| `BOARD_FLEXSPI_PSRAM` | `FLEXSPI` | PSRAM 控制器 |
| `BOARD_ENABLE_PSRAM_CACHE` | `1` | 启用 PSRAM 缓存 |
| `BOARD_LED_BLUE_GPIO_PIN` | `0U` | LED 蓝灯引脚 GPIO0[0] |
| `BOARD_SW2_GPIO_PIN` | `11U` | 按键 SW2 引脚 GPIO0[11] |
| `BOARD_ENET0_PHY_ADDRESS` | `0x02U` | 以太网 PHY 地址 |

### 2.2 引脚配置 (pin_mux.c)

```c
// FRDM-RW612 默认引脚配置
void BOARD_InitPins(void)
{
    /* Initialize FC3_USART_DATA functionality on pin GPIO_24 (pin E5) */
    IO_MUX_SetPinMux(IO_MUX_FC3_USART_DATA);
}
```

**关键引脚映射:**
- GPIO_24 (pin E5) → FLEXCOMM3 USART (调试串口)

### 2.3 时钟配置 (clock_config.c/h)

与 FCM363X **完全相同**，时钟配置一致。

**差异点:** FRDM-RW612 配置了外部 32.768 kHz 晶振 (PMU.XTAL32K)

### 2.4 Flash 配置 (flash_config.c)

| 配置项 | FRDM-RW612 | 说明 |
|--------|------------|------|
| `sflashA1Size` | `0x4000000U` (64 MB) | 连接到 A1 的 Flash 大小 |
| `sflashPadType` | `kSerialFlash_4Pads` | 四线模式 |
| `serialClkFreq` | `5` (100 MHz) | Flash 串行时钟频率 |
| `pageSize` | `0x100` (256 bytes) | 页大小 |
| `sectorSize` | `0x1000` (4 KB) | 扇区大小 |
| `blockSize` | `0x10000` (64 KB) | 块大小 |
| `deviceModeArg` | `0x02` | Quad Enable 参数 |

**Flash LUT 差异:**

| 序号 | FCM363X | FRDM-RW612 | 说明 |
|------|---------|------------|------|
| 0 | `0xEB` (Quad Read 24-bit) | `0xEC` (Quad Read 32-bit) | 读取命令不同 |
| 2 | `0x01` (Write Status) | `0x31` (Write Status Volatile) | 状态写入命令不同 |
| 5 | `0x20` (Sector Erase 24-bit) | `0x21` (Sector Erase 32-bit) | 扇区擦除地址宽度 |
| 8 | `0x52` (Block Erase 24-bit) | `0xDC` (Block Erase 32-bit) | 块擦除地址宽度 |
| 9 | `0x02` (Page Program 1-pad) | `0x34` (Page Program 4-pad) | 页编程模式 |
| 11 | `0x60` (Chip Erase) | `0xC7` (Chip Erase) | 全片擦除命令 |

---

## 3. 详细对比分析

### 3.1 引脚映射差异

| 功能 | FCM363X | FRDM-RW612 | 差异说明 |
|------|---------|------------|----------|
| 调试串口 TX/RX | GPIO_24 (pin F3) | GPIO_24 (pin E5) | 引脚号相同，物理位置不同 |
| LED 蓝灯 | GPIO0[0] | GPIO0[0] | 相同 |
| 按键 SW2 | GPIO0[11] | GPIO0[11] | 相同 |
| I2C2 SDA | GPIO0[16] | GPIO0[16] | 相同 |
| I2C2 SCL | GPIO0[17] | GPIO0[17] | 相同 |

**结论:** 引脚功能定义相同，主要差异在于物理封装位置（F3 vs E5），这对 Zephyr 设备树配置无影响。

### 3.2 时钟配置差异

| 时钟源 | FCM363X | FRDM-RW612 |
|--------|---------|------------|
| 外部晶振 (XTAL_OSC) | 40 MHz | 40 MHz |
| 外部 32K 晶振 (XTAL32K) | **无** | **有 (32.768 kHz)** |
| 内部 RC32K | 使用 | 使用 |

**Zephyr 移植影响:**
- FCM363X 使用内部 RC32K 作为 32K 时钟源
- 需要在设备树中配置 `clk32k` 使用内部 RC 而非外部晶振

```dts
/* FCM363X 需要的设备树配置 */
&clk32k {
    clock-source = <CLK_32K_SRC_RC32K>;
};
```

### 3.3 Flash 配置差异（关键差异）

| 配置项 | FCM363X | FRDM-RW612 | 差异 |
|--------|---------|------------|------|
| Flash 大小 | 8 MB | 64 MB | **8 倍差异** |
| 块大小 | 32 KB | 64 KB | 不同 Flash 型号 |
| 串行时钟频率 | 133 MHz | 100 MHz | FCM363X 更高 |
| 读取命令 | 0xEB (24-bit) | 0xEC (32-bit) | 地址宽度不同 |
| 编程命令 | 0x02 (1-pad) | 0x34 (4-pad) | 编程模式不同 |

**Flash 型号推测:**
- FCM363X: 可能使用 MXIC MX25L6433F 或同类 8MB Flash
- FRDM-RW612: 使用 64MB 大容量 Flash

**Zephyr 移植影响:**
- 需要修改 FlexSPI 配置的 LUT 表
- 需要修改 Flash 大小参数
- 需要使用 24 位地址命令（非 32 位）

### 3.4 外设启用差异

| 外设 | FCM363X | FRDM-RW612 |
|------|---------|------------|
| FLEXCOMM3 (UART) | ✓ 启用 | ✓ 启用 |
| GPIO0 | ✓ 启用 | ✓ 启用 |
| I2C2 | ✓ 可用 | ✓ 可用 |
| ENET | ✓ 可用 | ✓ 可用 |
| USBOTG | ✓ 可用 | ✓ 可用 |
| FlexSPI | ✓ 启用 | ✓ 启用 |
| PSRAM | 64 Mb | 64 Mb |
| Wi-Fi | ✓ 内置 | ✓ 内置 |
| BLE | ✓ 内置 | ✓ 内置 |

### 3.5 内存配置对比

| 配置项 | FCM363X | FRDM-RW612 |
|--------|---------|------------|
| SRAM | 640 KB (芯片内置) | 640 KB (芯片内置) |
| PSRAM | 64 Mb (FlexSPI Port B1) | 64 Mb (FlexSPI Port B1) |
| PSRAM 时钟 | 106.67 MHz | 106.67 MHz |
| PSRAM 缓存 | 启用 CACHE64_POLSEL1 | 启用 CACHE64_POLSEL1 |

**PSRAM 初始化代码（相同）:**

```c
flexspi_device_config_t psramConfig = {
    .flexspiRootClk       = 106666667, /* 106MHz SPI serial clock */
    .flashSize            = 0x2000,    /* 64Mb/KByte */
    .CSHoldTime           = 3,
    .CSSetupTime          = 3,
    // ... 相同配置
};
```

---

## 4. 需要移植到 Zephyr 的关键配置

### 4.1 设备树修改清单

```dts
/* fcm363x.dts - 基于 frdm_rw612.dts 修改 */

/ {
    model = "Quectel FCM363X Wireless Module";
    compatible = "quectel,fcm363x", "nxp,rw612";

    chosen {
        zephyr,console = &flexcomm3;
        zephyr,shell-uart = &flexcomm3;
    };
};

/* Flash 配置修改 */
&flexspi {
    status = "okay";

    flash0: flash@0 {
        compatible = "nxp,flexspi-mx25l6433f";  /* 8MB Flash */
        size = <0x800000>;  /* 8 MB */
        block-size = <0x8000>;  /* 32 KB */
        sector-size = <0x1000>;  /* 4 KB */
        
        /* 使用 24-bit 地址命令 */
        read-command = <0xEB>;  /* Quad Read 24-bit */
        program-command = <0x02>;  /* Page Program 1-pad */
    };
};

/* 32K 时钟源配置 */
&clk32k {
    clock-source = <CLK_32K_SRC_RC32K>;  /* 使用内部 RC32K */
};
```

### 4.2 Kconfig 配置清单

```kconfig
# fcm363x_defconfig

# 基础配置
CONFIG_SOC_SERIES_RW612=y
CONFIG_SOC_RW612=y
CONFIG_BOARD_FCM363X=y

# 时钟配置
CONFIG_CLOCK_CONTROL=y
CONFIG_NXP_RW6XX_CLOCK=y

# Flash 配置
CONFIG_FLASH=y
CONFIG_FLASH_SIZE=8192  # 8 MB
CONFIG_FLASH_BLOCK_SIZE=32768  # 32 KB

# 调试串口
CONFIG_SERIAL=y
CONFIG_UART_RW6XX=y

# Wi-Fi/BLE
CONFIG_WIFI=y
CONFIG_WIFI_NM=y
CONFIG_BT=y
```

### 4.3 CMake 配置

```cmake
# boards/arm/fcm363x/CMakeLists.txt

# Flash LUT 配置
set(FLEXSPI_FLASH_LUT
    # Read command (0xEB, 24-bit address, 4-pad)
    0xEB 0x18 0xF0 0x04 0x04
    # Write Enable (0x06)
    0x06 0x00
    # Sector Erase (0x20, 24-bit address)
    0x20 0x18
    # Page Program (0x02, 24-bit address, 1-pad)
    0x02 0x18
)
```

---

## 5. FCM363X 特定硬件

### 5.1 Wi-Fi 模块配置

FCM363X 的 Wi-Fi 模块与 RW612 芯片内置 Wi-Fi 相同，配置位于:

```
Code/boards/fcm363x/wifi_examples/
├── wifi_cli/           # Wi-Fi 命令行示例
├── wifi_httpsrv/       # HTTP 服务器示例
├── wifi_mqtt/          # MQTT 示例
├── wifi_wpa_supplicant/# WPA Supplicant 示例
└── wifi_cert/          # Wi-Fi 认证测试
```

**Wi-Fi 配置关键点:**
- Wi-Fi 固件嵌入在 Flash 中
- 使用 SDIO/SPI 接口通信（RW612 内置）
- 支持 Wi-Fi 6 (802.11ax)

### 5.2 BLE 配置

FCM363X 的 BLE 功能与 RW612 芯片内置 BLE 相同:

```
Code/boards/fcm363x/bt_ble_examples/
├── ble_central/        # BLE 中心设备示例
├── ble_peripheral/     # BLE 外围设备示例
└── ble_beacon/         # BLE Beacon 示例
```

**BLE 配置关键点:**
- BLE 5.3 支持
- 内置 BLE 控制器 (BLECTRL)
- 支持多连接

### 5.3 调试接口配置

**JTAG 调试配置（FCM363X 特有）:**

FCM363X 模块可能仅暴露 JTAG 接口（非 SWD），需要在 Zephyr 中配置:

```dts
/* JTAG 调试配置 */
&debug_interface {
    compatible = "nxp,rw6xx-jtag";
    status = "okay";
};
```

**JLink 调试配置:**

```ini
# JLinkSettings.ini
[Device]
Name=RW612
Core=ARM Cortex-M33

[Debug]
Interface=JTAG
Speed=4000
```

### 5.4 Flash 配置注意事项

**FCM363X Flash 特性:**
- 8 MB 容量
- 32 KB 块大小（非标准 64 KB）
- 24 位地址模式
- 133 MHz 最高时钟

**烧录配置:**

```bash
# blhost 烧录命令
blhost --port /dev/ttyUSB0 \
    flash-image fcm363x_image.bin 0x08000000 \
    --flash-size 0x800000
```

---

## 6. 差异总结表

| 类别 | 配置项 | FCM363X | FRDM-RW612 | 影响 |
|------|--------|---------|------------|------|
| **Flash** | 大小 | 8 MB | 64 MB | ⚠️ 高 |
| **Flash** | 块大小 | 32 KB | 64 KB | ⚠️ 中 |
| **Flash** | 读取命令 | 0xEB (24-bit) | 0xEC (32-bit) | ⚠️ 高 |
| **Flash** | 编程命令 | 0x02 (1-pad) | 0x34 (4-pad) | ⚠️ 中 |
| **Flash** | 时钟频率 | 133 MHz | 100 MHz | ✓ 低 |
| **时钟** | 32K 源 | RC32K | XTAL32K | ⚠️ 中 |
| **调试** | 引脚位置 | F3 | E5 | ✓ 无 |
| **调试** | 接口 | JTAG | SWD/JTAG | ⚠️ 中 |
| **内存** | PSRAM | 64 Mb | 64 Mb | ✓ 相同 |
| **外设** | GPIO | 相同 | 相同 | ✓ 相同 |
| **Wi-Fi** | 模块 | 内置 | 内置 | ✓ 相同 |
| **BLE** | 版本 | 5.3 | 5.3 | ✓ 相同 |

---

## 7. Zephyr 移植检查清单

### 必须修改

- [ ] **Flash 大小**: 从 64 MB 改为 8 MB
- [ ] **Flash LUT**: 修改为 24 位地址命令
- [ ] **块大小**: 从 64 KB 改为 32 KB
- [ ] **32K 时钟源**: 配置为内部 RC32K

### 建议修改

- [ ] **Flash 时钟频率**: 可配置为 133 MHz（更高性能）
- [ ] **JTAG 调试**: 验证 JTAG 调试配置
- [ ] **Board Name**: 修改为 "FCM363X"

### 无需修改

- [x] PSRAM 配置
- [x] GPIO 引脚映射
- [x] UART 配置
- [x] I2C 配置
- [x] 以太网 PHY 地址
- [x] Wi-Fi/BLE 驱动

---

## Sources

- FCM363X SDK 源码: `Code/boards/fcm363x/` (HIGH confidence)
- FRDM-RW612 SDK 源码: `Code/boards/frdmrw612/` (HIGH confidence)
- NXP RW612 数据手册 (HIGH confidence)
- Quectel FCM363X 规格书 (需参考官方文档)

---

## 附录: Flash LUT 完整对比

### FCM363X Flash LUT

```
[0]  = CMD_SDR(0xEB) + RADDR_SDR(24-bit, 4-pad)
[1]  = MODE8_SDR(0xF0, 4-pad) + DUMMY_SDR(4, 4-pad)
[2]  = READ_SDR(4, 4-pad) + STOP

[4]  = CMD_SDR(0x05) + READ_SDR(4, 1-pad)   // Read Status
[8]  = CMD_SDR(0x01) + WRITE_SDR(4, 1-pad)  // Write Status
[12] = CMD_SDR(0x06) + STOP                  // Write Enable
[20] = CMD_SDR(0x20) + RADDR_SDR(24-bit)     // Sector Erase
[32] = CMD_SDR(0x52) + RADDR_SDR(24-bit)     // Block Erase
[36] = CMD_SDR(0x02) + RADDR_SDR(24-bit) + WRITE_SDR(1-pad) // Page Program
[44] = CMD_SDR(0x60) + STOP                  // Chip Erase
```

### FRDM-RW612 Flash LUT

```
[0]  = CMD_SDR(0xEC) + RADDR_SDR(32-bit, 4-pad)
[1]  = MODE8_SDR(0xF0, 4-pad) + DUMMY_SDR(4, 4-pad)
[2]  = READ_SDR(4, 4-pad) + STOP

[4]  = CMD_SDR(0x05) + READ_SDR(4, 1-pad)   // Read Status
[8]  = CMD_SDR(0x31) + WRITE_SDR(1, 1-pad)  // Write Status Volatile
[12] = CMD_SDR(0x06) + STOP                  // Write Enable
[20] = CMD_SDR(0x21) + RADDR_SDR(32-bit)     // Sector Erase
[32] = CMD_SDR(0xDC) + RADDR_SDR(32-bit)     // Block Erase
[36] = CMD_SDR(0x34) + RADDR_SDR(32-bit) + WRITE_SDR(4-pad) // Page Program
[44] = CMD_SDR(0xC7) + STOP                  // Chip Erase
```
