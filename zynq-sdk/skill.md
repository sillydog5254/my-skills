---
name: zynq-sdk
description: |
  Xilinx SDK 2019.1 命令行自动化工具，用于 Zynq PS (ARM) 侧软件开发。
  触发条件：
  (1) 用户提到 SDK、BSP、ARM、Cortex-A9、PS侧开发
  (2) 用户要求导出硬件平台 (export hardware)
  (3) 用户要求创建/配置 BSP
  (4) 用户要求编译 C/C++ 应用程序
  (5) 用户要求下载/运行 ELF 文件
  (6) 用户要求打开串口/UART 终端
  (7) 用户说 /sdk /export-hw /create-bsp /build-app /run-elf /uart
---

# Zynq SDK 命令行自动化

## 快速命令参考

| 命令 | 说明 | 脚本/工具 |
|------|------|-----------|
| `/export-hw [xpr]` | 导出硬件定义(HDF) | Vivado TCL |
| `/create-bsp [hdf]` | 创建 BSP | xsct |
| `/create-app` | 创建应用程序 | xsct |
| `/build-app [name]` | 编译应用程序 | xsct |
| `/run-elf [elf]` | 下载并运行 ELF | xsct |
| `/uart [port]` | 打开串口终端 | Python |

## 工具路径

```bash
# XSCT 完整路径 (SDK 2019.1)
XSCT="D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat"

# Vivado (用于导出硬件)
VIVADO="vivado"
```

---

## 完整开发流程

### 1. 导出硬件定义 (/export-hw)

从 Vivado 项目导出 HDF 文件（需要完成实现）：

```bash
# 自动检测项目
vivado -mode batch -source scripts/xsct/export_hardware.tcl -nojournal -nolog

# 指定项目
vivado -mode batch -source scripts/xsct/export_hardware.tcl -tclargs project/MyProject.xpr -nojournal -nolog

# 指定输出目录
vivado -mode batch -source scripts/xsct/export_hardware.tcl -tclargs project/MyProject.xpr output_dir -nojournal -nolog
```

输出：`<output_dir>/<top_name>.hdf`

### 2. 创建硬件平台

```bash
# 使用 XSCT 创建硬件平台
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/create_hw_platform.tcl <hdf_file> [workspace]
```

### 3. 创建 BSP (/create-bsp)

```bash
# 自动检测 HDF
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/create_bsp.tcl

# 指定参数
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/create_bsp.tcl <hdf_file> [workspace] [bsp_name] [processor]

# 示例
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/create_bsp.tcl project/project.sdk/design_wrapper.hdf project/project.sdk standalone_bsp ps7_cortexa9_0
```

### 4. 创建应用程序 (/create-app)

```bash
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/create_app.tcl <workspace> <bsp_name> <app_name> [template]
```

可用模板：
- `"Hello World"` (默认)
- `"Empty Application"`
- `"Zynq FSBL"`
- `"Memory Tests"`
- `"Peripheral Tests"`

### 5. 编译应用程序 (/build-app)

```bash
# 编译
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/build_app.tcl <workspace> <app_name>

# 清理并重新编译
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/build_app.tcl <workspace> <app_name> clean
```

输出：`<workspace>/<app_name>/Debug/<app_name>.elf`

### 6. 下载并运行 ELF (/run-elf)

```bash
# 自动检测 ELF
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/download_elf.tcl

# 指定 ELF
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/download_elf.tcl path/to/app.elf

# 带比特流
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/download_elf.tcl app.elf design.bit

# 重置处理器后运行
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/download_elf.tcl app.elf --reset
```

注意：需要 hw_server 运行或 JTAG 连接

### 7. 串口终端 (/uart)

```bash
# 自动检测串口
python scripts/python/uart_terminal.py

# 指定串口
python scripts/python/uart_terminal.py COM6

# 指定串口和波特率
python scripts/python/uart_terminal.py COM6 115200

# 列出可用串口
python scripts/python/uart_terminal.py --list
```

**依赖**: 需要安装 pyserial
```bash
pip install pyserial
```

### 8. 验证串口通信的正确方法

**重要**: 不要使用 XSCT 直接写 UART 寄存器来测试，这通常会失败。

正确的方法是使用两个终端窗口：

**终端 1 - 监听串口**:
```bash
python scripts/python/uart_terminal.py COM6 115200
```

**终端 2 - 下载运行 ELF**:
```bash
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/download_elf.tcl app.elf --reset
```

程序的 `printf` 输出会显示在终端 1 中。

---

## 脚本位置

| 脚本 | 说明 |
|------|------|
| `scripts/xsct/export_hardware.tcl` | 导出硬件定义 (Vivado) |
| `scripts/xsct/create_hw_platform.tcl` | 创建硬件平台 |
| `scripts/xsct/create_bsp.tcl` | 创建 BSP |
| `scripts/xsct/create_app.tcl` | 创建应用程序 |
| `scripts/xsct/build_app.tcl` | 编译应用程序 |
| `scripts/xsct/download_elf.tcl` | 下载并运行 ELF |
| `scripts/python/uart_terminal.py` | 串口终端 |

---

## XSCT 常用命令速查

```tcl
# 设置工作区
setws /path/to/workspace

# 获取工作区
getws

# 列出项目
getprojects

# 创建硬件项目
createhw -name hw_platform -hwspec system.hdf

# 创建 BSP
createbsp -name my_bsp -hwproject hw_platform -proc ps7_cortexa9_0 -os standalone

# 配置 BSP
configbsp -bsp my_bsp stdin ps7_uart_0
configbsp -bsp my_bsp stdout ps7_uart_0

# 创建应用
createapp -name my_app -app {Hello World} -hwproject hw_platform -proc ps7_cortexa9_0 -bsp my_bsp

# 编译项目
projects -build -type app -name my_app
projects -clean -type app -name my_app

# 连接目标
connect
targets

# 配置 FPGA
fpga design.bit

# 选择处理器
targets -set -filter {name =~ "ARM*#0"}

# 下载 ELF
dow app.elf

# 运行/停止
con
stop

# 读写内存
mrd 0x0 10
mwr 0x0 0x12345678

# 断开连接
disconnect
```

---

## 处理器标识

| 平台 | 处理器 ID |
|------|-----------|
| Zynq-7000 | `ps7_cortexa9_0`, `ps7_cortexa9_1` |
| Zynq UltraScale+ | `psu_cortexa53_0`, `psu_cortexr5_0` |
| MicroBlaze | `microblaze_0` |

---

## 常见问题

### 1. hw_server 未运行

```
ERROR: Failed to connect to hw_server.
```

解决方案：
```bash
# 启动 hw_server
"D:/Program-Files/Xilinx/SDK/2019.1/bin/hw_server.bat"
```

### 2. 找不到处理器

```
ERROR: Cannot find ARM processor.
```

解决方案：检查 JTAG 连接，确保 FPGA 已配置。

### 3. BSP 编译失败

可能是缺少驱动程序。检查 HDF 文件中的外设配置。

### 4. ELF 运行后无输出

- 检查 BSP 的 stdin/stdout 配置是否正确
- 确认串口波特率（通常 115200）
- 确认使用正确的 COM 端口
- **重要**: 确认物理连接正确（盖帽/杜邦线）

### 5. 串口无法接收数据

**重要经验**: 直接通过 XSCT 写 UART 寄存器通常不工作（TX FIFO 状态异常）。

正确的测试方法是运行一个使用 `printf` 的程序：

```bash
# 正确的方式：下载运行 ELF，同时监听串口
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/download_elf.tcl app.elf --reset

# 同时在另一个终端监听串口
python scripts/python/uart_terminal.py COM6 115200
```

**调试步骤**：
1. 确认物理连接（重新插拔盖帽/杜邦线）
2. 检查 BSP 中 stdout 配置的 UART (ps7_uart_0 或 ps7_uart_1)
3. 确认串口波特率 (115200)
4. 运行包含 `printf` 的程序进行测试

### 6. UART 寄存器状态异常

如果看到 `Status: 0x0000000A` (TX FIFO Empty=1 但 TX FIFO Not Full=0)，这通常意味着：
- UART 时钟或复位配置问题
- 物理连接问题
- 需要完整运行 ps7_init 后再使用 printf

解决方案：使用程序的 printf 输出而不是直接写寄存器

---

## 综合验证脚本 (verify_all.py)

一键验证所有 Zynq 工具链功能：

```bash
# 完整测试（自动检测文件）
python ~/.claude/skills/zynq-sdk/scripts/verify_all.py --port COM6

# 指定文件
python ~/.claude/skills/zynq-sdk/scripts/verify_all.py \
    --bit design.bit \
    --elf app.elf \
    --port COM6

# 跳过特定测试
python ~/.claude/skills/zynq-sdk/scripts/verify_all.py --skip-fpga --skip-uart
```

验证项目：
| 测试 | 说明 | 对应 Skill |
|------|------|------------|
| JTAG Detection | 检测 JTAG 设备和 Zynq 芯片 | zynq-debug |
| FPGA Programming | 通过 XSCT 烧录比特流 | vivado-automation |
| CPU Control | 停止/读取寄存器/恢复运行 | zynq-debug |
| Memory Access | 读写 DDR 内存并验证 | zynq-debug |
| ELF Download | 下载并运行程序 | zynq-sdk |
| UART Output | 捕获串口输出 | zynq-sdk |
