# Domain Pitfalls

**Domain:** 嵌入式无线 IoT 设备 Zephyr 移植
**Researched:** 2026-03-03

## Critical Pitfalls

Mistakes that cause rewrites or major issues.

### Pitfall 1: PSRAM 配置错误

**What goes wrong:** FC M363XABMD 无外部 PSRAM 硬件，但配置未禁用 PSRAM，导致内存分配失败或系统崩溃。

**Why it happens:**
- FRDM-RW612 开发板有 PSRAM，配置默认启用
- 复制配置时未禁用 PSRAM
- 多个配置文件中都有 PSRAM 配置（Kconfig, DTS, prj.conf）

**Consequences:**
- 启动时内存分配失败
- 运行时随机崩溃
- 系统无法正常工作

**Prevention:**
1. 在 `boards/nxp/fcm363x/Kconfig.defconfig` 中显式禁用:
   ```kconfig
   config NXP_PSRAM
       default n
   ```
2. 在 `prj.conf` 中禁用:
   ```
   CONFIG_NXP_PSRAM=n
   ```
3. 在 DTS overlay 中禁用:
   ```dts
   &psram {
       status = "disabled";
   };
   ```
4. 验证内存映射正确（1.2MB SRAM，无 PSRAM）

**Detection:**
- 启动日志中出现 "PSRAM initialization failed"
- 内存分配失败（ENOMEM）
- 系统随机崩溃

### Pitfall 2: JTAG 调试接口配置错误

**What goes wrong:** FCM363X 仅支持 JTAG 接口，但配置为 SWD，导致调试失败。

**Why it happens:**
- 大多数 ARM 芯片默认使用 SWD
- 复制配置时未修改调试接口
- JLink 配置文件错误

**Consequences:**
- 无法连接调试器
- 无法下载固件
- 无法单步调试

**Prevention:**
1. JLink 配置使用 JTAG:
   ```
   device RW612
   interface jtag
   speed 10000
   ```
2. VSCode launch.json 配置:
   ```json
   {
       "device": "RW612",
       "interface": "jtag"
   }
   ```
3. 验证 JLink 版本支持 RW612

**Detection:**
- JLink 报告 "Could not connect to target"
- 调试器无法识别设备
- 固件下载失败

### Pitfall 3: 设备树配置不完整

**What goes wrong:** 设备树配置不完整或错误，导致驱动无法初始化。

**Why it happens:**
- 设备树语法错误
- 引脚映射错误
- 忘记启用设备节点

**Consequences:**
- 驱动初始化失败
- 外设无法使用
- 系统启动失败

**Prevention:**
1. 使用 `west build -t dtbs` 生成设备树
2. 检查编译日志中的设备树错误
3. 使用 `dtc` 工具验证设备树语法
4. 参考现有 FRDM-RW612 设备树配置

**Detection:**
- 编译错误："Failed to parse device tree"
- 启动日志："Device X not ready"
- `device_is_ready()` 返回 false

### Pitfall 4: 依赖版本不匹配

**What goes wrong:** nxp-zsdk、Zephyr、工具链版本不匹配，导致构建失败。

**Why it happens:**
- west.yml 中版本指定错误
- 工具链版本过旧或过新
- Python 依赖版本冲突

**Consequences:**
- 构建失败
- 运行时错误
- 无法使用新特性

**Prevention:**
1. 使用 nxp-zsdk 推荐的工具链版本
2. 固定 west.yml 中的版本号
3. 使用 Python 虚拟环境隔离依赖
4. 定期更新到稳定版本

**Detection:**
- 编译错误："Unsupported toolchain version"
- 运行时错误："Symbol not found"
- west update 失败

## Moderate Pitfalls

### Pitfall 1: 引脚映射错误

**What goes wrong:** 引脚复用配置错误，导致外设无法工作。

**Prevention:**
- 参考现有 FreeRTOS SDK 的引脚配置
- 使用设备树定义引脚功能
- 验证硬件原理图

### Pitfall 2: 时钟配置错误

**What goes wrong:** 时钟配置不正确，导致外设无法工作或性能低下。

**Prevention:**
- 参考现有 clock_config.c 配置
- 使用设备树定义时钟源
- 验证时钟频率

### Pitfall 3: 内存分配失败

**What goes wrong:** 静态内存分配过大，导致内存不足。

**Prevention:**
- 使用动态内存池
- 监控内存使用情况
- 优化数据结构

### Pitfall 4: Wi-Fi 固件加载失败

**What goes wrong:** Wi-Fi 固件未正确加载，导致无法连接网络。

**Prevention:**
- 确保固件文件正确放置
- 检查 Flash 分区配置
- 验证固件版本兼容性

## Minor Pitfalls

### Pitfall 1: 日志输出过多

**What goes wrong:** 调试日志过多，影响性能和 Flash 使用。

**Prevention:**
- 使用 Kconfig 控制日志级别
- 生产环境禁用详细日志
- 使用条件编译

### Pitfall 2: 编译时间过长

**What goes wrong:** 增量编译失效，每次都全量编译。

**Prevention:**
- 使用 ninja 构建后端
- 使用 ccache 加速编译
- 避免不必要的头文件包含

### Pitfall 3: Flash 空间不足

**What goes wrong:** 固件过大，超出 Flash 容量。

**Prevention:**
- 优化代码大小
- 启用编译器优化（-Os）
- 移除未使用的功能

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| **Phase 1: 环境准备** | 工具链版本不匹配 | 使用 nxp-zsdk 推荐版本，验证工具链 |
| **Phase 2: Board 定义** | PSRAM 未禁用 | 在 Kconfig, prj.conf, DTS 中显式禁用 |
| **Phase 2: Board 定义** | 设备树配置错误 | 参考现有配置，使用 dtc 验证 |
| **Phase 3: 项目创建** | west.yml 配置错误 | 验证仓库 URL 和版本号 |
| **Phase 4: 构建验证** | JTAG 配置错误 | 使用 JTAG 接口，验证 JLink 版本 |
| **Phase 4: 构建验证** | 内存分配失败 | 检查 SRAM 配置，禁用 PSRAM |
| **Phase 5: 团队协作** | 依赖版本冲突 | 使用虚拟环境，固定版本号 |

## Common Issues and Solutions

### Issue 1: "Device not ready" Error

**Symptoms:**
- 启动日志中出现 "Device X not ready"
- `device_is_ready()` 返回 false

**Root Causes:**
- 设备树配置错误
- 驱动未初始化
- 硬件未连接

**Solutions:**
1. 检查设备树配置
2. 验证驱动是否启用（Kconfig）
3. 检查硬件连接

### Issue 2: Build Failure with "Undefined reference"

**Symptoms:**
- 链接错误，提示符号未定义
- 构建失败

**Root Causes:**
- 缺少依赖库
- Kconfig 配置错误
- 版本不匹配

**Solutions:**
1. 检查 Kconfig 配置
2. 添加缺失的依赖
3. 验证版本兼容性

### Issue 3: Wi-Fi Connection Failed

**Symptoms:**
- 无法连接 Wi-Fi 网络
- 扫描不到 AP

**Root Causes:**
- 固件未加载
- 认证配置错误
- 硬件问题

**Solutions:**
1. 检查固件加载
2. 验证 SSID 和密码
3. 检查天线连接

### Issue 4: Flash Write Failed

**Symptoms:**
- 无法写入 Flash
- OTA 升级失败

**Root Causes:**
- Flash 分区配置错误
- Flash 磨损
- 权限问题

**Solutions:**
1. 检查 Flash 分区配置
2. 验证 Flash 健康
3. 检查写入权限

## Sources

- nxp-zsdk 已知问题: https://github.com/nxp-zephyr/nxp-zsdk/issues (MEDIUM confidence)
- Zephyr 移植指南: https://docs.zephyrproject.org/latest/hardware/porting/board_porting.html (HIGH confidence)
- NXP Community 知识库: https://community.nxp.com/t5/Zephyr-Project-Knowledge-Base/tkb-p/Zephyr-Project (MEDIUM confidence)
- 内部 FreeRTOS SDK 问题记录: Code/ 目录 (HIGH confidence)
- RW612 数据手册: 内部 SDK 文档 (HIGH confidence)
---

## Phase 4 实战发现 (2026-03-04)

### Critical Pitfall 5: FCB 缺失导致串口无输出

**What goes wrong:** 编译成功的 zephyr.bin 烧录后串口无任何输出，但 FreeRTOS SDK 的 hello_world.bin 正常工作。

**Why it happens:**
- RW612 boot ROM 要求 Flash 偏移 0x400 处必须有 FCB (Flash Configuration Block)
- FCB 配置 FlexSPI 访问 NOR Flash 的时序和命令
- Zephyr 的 `.flash_conf` section 默认为空，除非 Board 提供配置
- 没有 FCB，芯片无法正确读取 Flash 指令 → 无法启动

**Consequences:**
- 串口无输出
- 看起来像是硬件问题
- 实际上是启动失败

**Prevention:**
1. 创建 `boards/nxp/fcm363x/flash_config.c`：
   ```c
   #include <zephyr/kernel.h>
   #include <flash_config.h>

   __attribute__((section(".flash_conf"), used))
   const fc_flexspi_nor_config_t flexspi_config = {
       .memConfig = {
           .tag = FC_BLOCK_TAG,
           .version = FC_BLOCK_VERSION,
           .readSampleClkSrc = 1,
           .csHoldTime = 3,
           .csSetupTime = 3,
           .deviceModeCfgEnable = 1,
           .deviceModeSeq = {.seqNum = 1, .seqId = 2},
           .deviceModeArg = 0x0200,
           .deviceType = 0x1,
           .sflashPadType = kSerialFlash_4Pads,
           .serialClkFreq = 7,  /* 133MHz */
           .sflashA1Size = 0x800000U,  /* 8MB */
           .lookupTable = {
               /* Read: Quad I/O (0xEB), 24-bit address */
               [0] = FC_FLEXSPI_LUT_SEQ(FC_CMD_SDR, FC_FLEXSPI_1PAD, 0xEB,
                                        FC_RADDR_SDR, FC_FLEXSPI_4PAD, 0x18),
               [1] = FC_FLEXSPI_LUT_SEQ(FC_MODE8_SDR, FC_FLEXSPI_4PAD, 0xF0,
                                        FC_DUMMY_SDR, FC_FLEXSPI_4PAD, 0x04),
               [2] = FC_FLEXSPI_LUT_SEQ(FC_READ_SDR, FC_FLEXSPI_4PAD, 0x04,
                                        FC_STOP_EXE, FC_FLEXSPI_1PAD, 0x00),
               /* ... 其他命令配置 ... */
           },
       },
       .pageSize = 0x100,
       .sectorSize = 0x1000,
       .blockSize = 0x8000,
       .fcb_fill = {0xFFFFFFFF},
   };
   ```

2. 在 CMakeLists.txt 中添加编译：
   ```cmake
   zephyr_library_sources(
       board.c
       flash_config.c
   )
   ```

3. 关键参数（MX25L6433F）：
   - Flash 大小: 8MB (0x800000)
   - 地址模式: 24-bit (不是 32-bit!)
   - 读取命令: 0xEB (Quad I/O)
   - 时钟频率: 133MHz

**Detection:**
- 比较 bin 文件偏移 0x400 内容：
  - FreeRTOS SDK: 有 FCB 数据
  - Zephyr: 全 0x00 或 0xFF
- 使用 `hexdump -C zephyr.bin | grep "00000400"`

**Reference:**
- `Code/boards/fcm363x/flash_config/flash_config.c` (FreeRTOS SDK)
- RW612 Reference Manual: FlexSPI Boot Flow

### Critical Pitfall 6: OS Timer 时钟频率配置错误

**What goes wrong:** `k_sleep(K_SECONDS(1))` 实际睡眠 260 秒（约 4.3 分钟），所有定时相关功能异常。

**Why it happens:**
- RW612 使用 OS Timer 作为系统定时器（不是 SysTick）
- OS Timer 时钟源是 **LPOSC (1MHz)**，不是 CPU 时钟 (260MHz)
- Board 的 Kconfig.defconfig 硬编码了 `SYS_CLOCK_HW_CYCLES_PER_SEC=260000000`
- SoC 层正确配置被覆盖
- 时间计算错误：260MHz / 1MHz = 260 倍

**Consequences:**
- k_sleep() 延时 260 倍
- 超时功能异常
- 调度器行为不正确

**Prevention:**
1. **不要在 Board 层覆盖时钟频率**：
   ```kconfig
   # 错误！不要这样做
   config SYS_CLOCK_HW_CYCLES_PER_SEC
       default 260000000
   
   # 正确：让 SoC 层自动选择
   # SoC Kconfig.defconfig 已有：
   # config SYS_CLOCK_HW_CYCLES_PER_SEC
   #     default 1000000 if MCUX_OS_TIMER
   #     default 260000000 if CORTEX_M_SYSTICK
   ```

2. 验证配置正确：
   ```bash
   grep SYS_CLOCK_HW_CYCLES_PER_SEC build/zephyr/.config
   # 应输出: CONFIG_SYS_CLOCK_HW_CYCLES_PER_SEC=1000000
   ```

**Technical Background:**
- RW612 OS Timer 使用 LPOSC (Low Power Oscillator) 作为时钟源
- LPOSC 频率: 1MHz
- SoC 层 `soc/nxp/rw/Kconfig.defconfig` 已正确配置
- Board 层不应覆盖此配置

**Detection:**
- 检查 `.config` 文件中的 `SYS_CLOCK_HW_CYCLES_PER_SEC`
- 如果是 260000000 且使用 OS Timer，则有问题
- 定时器延时明显变长

**Reference:**
- `soc/nxp/rw/Kconfig.defconfig`
- RW612 Reference Manual: OS Timer Clock Source

### Moderate Pitfall: ANSI 颜色码终端兼容

**What goes wrong:** 串口输出显示 `[1;32muart~$ [m` 而不是正常的彩色提示符。

**Why it happens:**
- Zephyr Shell 默认输出 ANSI 颜色转义序列
- 部分终端不支持 ANSI 颜色

**Solutions:**
1. 使用支持 ANSI 的终端（PuTTY、minicom、screen）
2. 或在 prj.conf 中禁用颜色：
   ```
   CONFIG_SHELL_VT100_COLORS=n
   ```


### Phase 4 Warnings Updated

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| **Phase 4: 构建验证** | FCB 缺失导致无启动 | 创建 flash_config.c，配置 FlexSPI |
| **Phase 4: 构建验证** | OS Timer 时钟配置错误 | 不覆盖 SYS_CLOCK_HW_CYCLES_PER_SEC |
| **Phase 4: 构建验证** | ANSI 颜色码不显示 | 使用 PuTTY 或禁用颜色 |
