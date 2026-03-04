# Architecture Patterns

**Domain:** 嵌入式无线 IoT 设备
**Researched:** 2026-03-06

## Recommended Architecture

基于 Zephyr RTOS 的分层嵌入式架构，采用设备树驱动模型和多仓库管理。

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                        │
│          (User Applications & Examples)                      │
│  Location: fcm363x-project/src/                              │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    Zephyr RTOS Layer                        │
│          (Kernel, Scheduler, Memory Management)               │
│  Location: nxp-zsdk/zephyr/                                  │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    Device Tree & HAL Layer                   │
│          (Hardware Abstraction, Device Drivers)               │
│  Location: nxp-zsdk/hal_nxp/, boards/nxp/fcm363x/            │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    Hardware Layer                            │
│          (NXP RW612 MCU, Flash, Peripherals)                 │
│  Location: Physical Hardware                                 │
└─────────────────────────────────────────────────────────────┘
```

### Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| **Application** | 业务逻辑、用户界面 | Zephyr API, Device Drivers |
| **Zephyr Kernel** | 任务调度、内存管理、同步机制 | Application, HAL |
| **Device Drivers** | 硬件抽象、外设驱动 | HAL, Hardware |
| **HAL (Hardware Abstraction Layer)** | 芯片级初始化、寄存器访问 | Device Drivers, Hardware |
| **Device Tree** | 硬件配置、引脚映射 | HAL, Device Drivers |

### Data Flow

**启动流程:**

```
1. Reset_Handler (startup_RW612.S)
   ↓
2. SystemInit (system_RW612.c)
   - 初始化系统时钟
   - 配置 Flash
   - 设置中断向量表
   ↓
3. z_cstart (Zephyr 启动)
   - 初始化内核
   - 加载设备树
   - 初始化驱动
   ↓
4. zephyr_app_main (main.c)
   - 应用初始化
   - 任务创建
   ↓
5. FreeRTOS (可选) / Zephyr 任务调度
   - 多任务执行
```

**Wi-Fi 数据流:**

```
Application
   ↓ (调用 zsock_socket, zsock_connect)
Zephyr Socket API
   ↓ (lwIP 协议栈)
lwIP (TCP/IP)
   ↓ (网络数据包)
Wi-Fi Driver (wifi_nm)
   ↓ (SPI/固件接口)
RW612 Wi-Fi 固件
   ↓ (无线传输)
Wi-Fi 6 网络
```

**外设访问流:**

```
Application
   ↓ (调用 gpio_pin_set, uart_transmit)
Zephyr Device API
   ↓ (设备树查找)
Device Driver
   ↓ (HAL 调用)
HAL (fsl_gpio, fsl_uart)
   ↓ (寄存器操作)
Hardware Registers
```

**OTA 升级流:**

```
Application
   ↓ (下载固件)
HTTP Client (lwIP)
   ↓ (存储到 Flash 分区)
Flash Partition (MCUBoot)
   ↓ (验证签名)
MCUBoot (Bootloader)
   ↓ (启动新固件)
New Application
```

## Patterns to Follow

### Pattern 1: 设备树驱动模型 (Device Tree Driver Model)

**What:** Zephyr 使用设备树（Device Tree）描述硬件配置，驱动自动绑定和初始化。

**When:** 所有硬件配置和驱动初始化

**Example:**
```dts
/* fcm363x.dtsi */
&flexcomm3 {
    status = "okay";
    compatible = "nxp,lpc-usart";
    current-speed = <115200>;
};

&gpio0 {
    status = "okay";
};
```

```c
/* main.c */
#include <zephyr/drivers/gpio.h>

static const struct device *gpio_dev = DEVICE_DT_GET(DT_NODELABEL(gpio0));

if (!device_is_ready(gpio_dev)) {
    printk("GPIO device not ready\n");
    return;
}
```

### Pattern 2: Zephyr Devicetree Overlay

**What:** 使用设备树覆盖（Overlay）定制硬件配置，无需修改核心设备树。

**When:** 需要定制硬件配置，保持核心配置不变

**Example:**
```dts
/* boards/fcm363x.overlay */
/ {
    chosen {
        zephyr,console = &flexcomm3;
        zephyr,shell-uart = &flexcomm3;
    };
};

&flexcomm3 {
    status = "okay";
    current-speed = <115200>;
};
```

### Pattern 3: Zephyr Kconfig 配置系统

**What:** 使用 Kconfig 进行配置管理，支持依赖解析和条件编译。

**When:** 所有功能配置和特性选择

**Example:**
```kconfig
/* prj.conf */
# 基础配置
CONFIG_PRINTK=y
CONFIG_LOG=y

# Wi-Fi 配置
CONFIG_WIFI=y
CONFIG_WIFI_NM=y

# 禁用 PSRAM
CONFIG_NXP_PSRAM=n
```

### Pattern 4: Zephyr Devicetree Macros

**What:** 使用设备树宏简化硬件访问。

**When:** 访问硬件引脚和设备节点

**Example:**
```c
/* 获取设备树中的引脚配置 */
#define LED0_NODE DT_ALIAS(led0)
static const struct gpio_dt_spec led = GPIO_DT_SPEC_GET(LED0_NODE, gpios);

/* 获取设备树中的设备 */
#define UART_NODE DT_CHOSEN(zephyr_console)
static const struct device *uart_dev = DEVICE_DT_GET(UART_NODE);
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: 硬编码引脚配置

**What:** 在代码中硬编码 GPIO 引脚号和外设基地址。

**Why bad:** 代码不可移植，难以维护，违反设备树原则。

**Instead:** 使用设备树宏和 Zephyr Device API。

```c
/* ❌ Bad */
gpio_pin_set(0, 10, 1);  // 硬编码引脚

/* ✅ Good */
gpio_dt_spec_set(&led, 1);  // 从设备树获取
```

### Anti-Pattern 2: 直接操作寄存器

**What:** 在应用层直接访问硬件寄存器。

**Why bad:** 绕过 HAL 和驱动模型，代码不可移植，难以调试。

**Instead:** 使用 Zephyr Device API。

```c
/* ❌ Bad */
*(volatile uint32_t *)0x4004C000 = 0x01;  // 直接操作寄存器

/* ✅ Good */
gpio_pin_set(gpio_dev, pin, 1);  // 使用 Device API
```

### Anti-Pattern 3: 混合 FreeRTOS 和 Zephyr API

**What:** 同时使用 FreeRTOS 和 Zephyr API。

**Why bad:** 语义冲突，内存管理混乱，调度器冲突。

**Instead:** 选择一个 RTOS，建议使用 Zephyr RTOS。

### Anti-Pattern 4: 忽略设备树状态检查

**What:** 不检查设备是否 ready 就使用。

**Why bad:** 可能导致运行时错误，难以调试。

**Instead:** 始终检查 device_is_ready()。

```c
/* ❌ Bad */
const struct device *dev = DEVICE_DT_GET(DT_NODELABEL(i2c0));
i2c_write(dev, data, len, addr);  // 未检查 ready 状态

/* ✅ Good */
const struct device *dev = DEVICE_DT_GET(DT_NODELABEL(i2c0));
if (!device_is_ready(dev)) {
    printk("I2C device not ready\n");
    return -ENODEV;
}
i2c_write(dev, data, len, addr);
```

## Scalability Considerations

| Concern | At 100 users | At 10K users | At 1M users |
|---------|--------------|--------------|-------------|
| **任务数量** | 单任务或少量任务 | 使用多任务 + 工作队列 | 需要任务优先级优化 |
| **网络连接** | 单一 Wi-Fi 连接 | 连接池 + 会话管理 | 需要负载均衡 |
| **Flash 存储** | 简单文件系统 | LittleFS + 分区管理 | 需要磨损均衡 |
| **内存管理** | 静态分配 | 动态内存池 | 需要内存池优化 |
| **功耗管理** | 基本低功耗模式 | 自适应功耗管理 | 需要深度功耗优化 |

## Multi-Repository Architecture

### T2 Topology (Application as Manifest Repository)

```
~/zephyr_ws/
│
├── fcm363x-project/            # 应用项目 (Git 管理)
│   ├── .git/
│   ├── west.yml                # Manifest 仓库
│   ├── src/
│   ├── build/
│   └── ...
│
├── fcm363x-board/             # Board 定义 (Git 管理)
│   ├── .git/
│   ├── west.yml
│   └── boards/nxp/fcm363x/
│
├── nxp-zsdk/                 # NXP Zephyr SDK (自动获取)
│   ├── zephyr/
│   ├── hal_nxp/
│   └── modules/
│
└── .west/
    └── config
```

**Advantages:**
- 应用和 Board 定义分离，便于独立维护
- 多个项目可以共享同一 Board 定义
- 便于团队协作和版本管理

**Manifest Example (fcm363x-project/west.yml):**
```yaml
manifest:
  remotes:
    - name: nxp-zephyr
      url-base: https://github.com/nxp-zephyr
    - name: myrepo
      url-base: https://github.com/your-team

  projects:
    - name: nxp-zsdk
      remote: nxp-zephyr
      revision: nxp-v4.3.0
      import: true

    - name: fcm363x-board
      remote: myrepo
      revision: main

  self:
    path: application
```

## Sources

- Zephyr 官方文档: https://docs.zephyrproject.org (HIGH confidence)
- nxp-zsdk 架构文档: https://github.com/nxp-zephyr/nxp-zsdk/blob/main/doc/Introduction-to-ZSDK-Downstream.md (HIGH confidence)
- Zephyr Device Tree: https://docs.zephyrproject.org/latest/build/dts/index.html (HIGH confidence)
- Zephyr Board Porting: https://docs.zephyrproject.org/latest/hardware/porting/board_porting.html (HIGH confidence)
- Zephyr Kconfig: https://docs.zephyrproject.org/latest/build/kconfig/index.html (HIGH confidence)
- 内部 FreeRTOS SDK 架构分析: Code/ 目录 (HIGH confidence)