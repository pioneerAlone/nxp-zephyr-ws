# Feature Landscape

**Domain:** 嵌入式无线 IoT 设备
**Researched:** 2026-03-03

## Table Stakes

Features users expect. Missing = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **GPIO 控制** | 基础 IO 操作，所有嵌入式应用必需 | Low | Zephyr 完全支持，设备树配置即可 |
| **UART 串口** | 调试输出、通信接口 | Low | FLEXCOMM3 作为调试串口，已配置 |
| **SPI 总线** | 外设扩展（Flash、传感器等） | Low | FLEXSPI0 支持，Flash 已配置 |
| **I2C 总线** | 传感器、EEPROM 等 | Low | FLEXCOMM 支持，需设备树配置 |
| **ADC** | 模拟信号采集 | Low | ADC 模块可用，需配置通道 |
| **PWM** | 电机控制、LED 调光 | Low | PWM 模块可用，需配置引脚 |
| **定时器** | 精确时序控制 | Low | 硬件定时器支持 |
| **Wi-Fi 连接** | 无线网络通信 | Medium | Wi-Fi 6 支持，需配置认证方式 |
| **BLE 5.3** | 低功耗蓝牙通信 | Medium | BLE 5.3 支持，需配置 GATT |
| **Flash 存储** | 固件存储、数据持久化 | Low | 8MB QSPI Flash，已配置 |
| **OTA 升级** | 远程固件更新 | Medium | MCUBoot 支持，需配置分区 |
| **看门狗** | 系统可靠性 | Low | 硬件看门狗可用 |
| **低功耗模式** | 电池供电设备 | Medium | RW612 支持多种低功耗模式 |

## Differentiators

Features that set product apart. Not expected, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Wi-Fi 6 (802.11ax)** | 更高吞吐量、更低延迟、更好电源效率 | Medium | RW612 原生支持，需要 Zephyr 驱动 |
| **BLE 5.3** | 最新蓝牙特性、更好功耗 | Medium | RW612 原生支持 |
| **Thread (802.15.4)** | Mesh 网络、低功耗物联网 | High | RW612 支持，但 Zephyr 支持有限（需验证） |
| **PSA Crypto** | 硬件加密加速、安全认证 | Medium | RW612 支持 PSA Crypto Driver |
| **LVGL 图形库** | 图形 UI、触摸屏支持 | High | 内置 LVGL 支持，需配置显示驱动 |
| **LittleFS 文件系统** | Flash 文件系统、数据持久化 | Low | 内置 LittleFS，易于配置 |
| **Shell 命令行** | 交互式调试、运行时配置 | Low | Zephyr Shell 框架可用 |
| **USB Device** | USB 通信、模拟串口 | Medium | USB Device Stack 支持 |

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **PSRAM 支持** | FCM363XABMD 无外部 PSRAM 硬件 | 显式禁用 PSRAM 配置，避免内存分配失败 |
| **SWD 调试** | FCM363X 仅支持 JTAG 接口 | 使用 JTAG 调试接口，配置 JLink 为 JTAG 模式 |
| **Thread (802.15.4)** | Zephyr 对 RW612 的 Thread 支持不完整 | 暂不使用，等待上游支持完善 |
| **以太网** | FCM363X 无以太网硬件 | 使用 Wi-Fi 进行网络通信 |

## Feature Dependencies

```
GPIO → 基础 IO 操作 (无依赖)
UART → GPIO (引脚配置)
SPI → GPIO (引脚配置)
I2C → GPIO (引脚配置)
ADC → GPIO (引脚配置)
PWM → GPIO (引脚配置)
Wi-Fi → SPI (固件加载) + 网络栈 (lwIP)
BLE → UART (HCI) + BLE 协议栈
OTA → Flash (固件存储) + MCUBoot (引导加载)
LVGL → SPI/I2C (显示接口) + GPIO (触摸)
PSA Crypto → 硬件加密模块
```

## MVP Recommendation

Prioritize:
1. **GPIO + UART** - 基础调试和 IO 控制
2. **Wi-Fi 连接** - 核心无线功能
3. **Flash 存储** - 数据持久化和 OTA 基础

Defer:
- Thread (802.15.4): Zephyr 支持不完整，需要等待上游支持
- LVGL 图形库: 需要显示硬件，后续阶段考虑
- USB Device: 非核心功能，后续阶段考虑

## nxp-zsdk vs FreeRTOS SDK Feature Comparison

| Feature | nxp-zsdk | FreeRTOS SDK | Notes |
|---------|----------|--------------|-------|
| **GPIO** | ✅ 完全支持 | ✅ 完全支持 | API 不同，功能相当 |
| **UART** | ✅ 完全支持 | ✅ 完全支持 | API 不同，功能相当 |
| **SPI** | ✅ 完全支持 | ✅ 完全支持 | API 不同，功能相当 |
| **I2C** | ✅ 完全支持 | ✅ 完全支持 | API 不同，功能相当 |
| **ADC** | ✅ 完全支持 | ✅ 完全支持 | API 不同，功能相当 |
| **Wi-Fi** | ✅ 支持 (Wi-Fi 6) | ✅ 支持 (Wi-Fi 6) | API 不同，功能相当 |
| **BLE** | ✅ 支持 (BLE 5.3) | ✅ 支持 (BLE 5.3) | API 不同，功能相当 |
| **OTA** | ✅ MCUBoot | ✅ MCUBoot | 实现方式相同 |
| **PSA Crypto** | ✅ 支持 | ✅ 支持 | 功能相当 |
| **Thread** | ⚠️ 部分支持 | ❌ 不支持 | nxp-zsdk 有基础支持，但不完整 |
| **LVGL** | ✅ 内置 | ❌ 需手动集成 | nxp-zsdk 更方便 |
| **Shell** | ✅ 内置 | ❌ 需手动实现 | nxp-zsdk 更方便 |
| **设备树** | ✅ 标准化 | ❌ 不支持 | nxp-zsdk 更灵活 |

## Sources

- nxp-zsdk Board Support Status: https://github.com/nxp-zephyr/nxp-zsdk/blob/main/doc/releases/Board-Support-Status.md (HIGH confidence)
- FRDM-RW612 Zephyr 文档: https://docs.zephyrproject.org/latest/boards/nxp/frdm_rw612/doc/index.html (HIGH confidence)
- Quectel FCM363X 产品页面: https://www.quectel.com/product/mcu-wi-fi-bluetooth-fcm363x/ (MEDIUM confidence)
- NXP RW612 数据手册: 内部 SDK 文档 (HIGH confidence)
- Zephyr 外设支持: https://docs.zephyrproject.org/latest/hardware/peripherals/index.html (HIGH confidence)