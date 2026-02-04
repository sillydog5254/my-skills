---
name: zynq-debug
description: |
  Zynq FPGA+ARM 集成调试工具，用于 PL 和 PS 侧的硬件调试。
  触发条件：
  (1) 用户提到 JTAG、调试、hw_server、硬件调试
  (2) 用户要求检测/连接 FPGA
  (3) 用户要求控制 CPU (停止/运行/复位)
  (4) 用户要求读写内存/寄存器
  (5) 用户要求检查 FPGA 配置状态
  (6) 用户要求系统复位
  (7) 用户说 /debug /jtag /hw-server /cpu /mem /reset /fpga-status
---

# Zynq 集成调试工具

## 快速命令参考

| 命令 | 说明 | 脚本 |
|------|------|------|
| `/hw-server [start\|stop\|status]` | hw_server 管理 | hw_server_control.tcl |
| `/jtag` | JTAG 设备检测 | jtag_detect.tcl |
| `/fpga-status` | FPGA 配置状态 | fpga_status.tcl |
| `/cpu [stop\|run\|reset\|status]` | CPU 控制 | cpu_control.tcl |
| `/mem read <addr> [count]` | 读内存 | memory_access.tcl |
| `/mem write <addr> <value>` | 写内存 | memory_access.tcl |
| `/reset [--full\|--ps\|--cores]` | 系统复位 | system_reset.tcl |

## 工具路径

```bash
# XSCT 完整路径 (SDK 2019.1)
XSCT="D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat"

# hw_server 完整路径
HW_SERVER="D:/Program-Files/Xilinx/SDK/2019.1/bin/hw_server.bat"
```

---

## hw_server 管理 (/hw-server)

hw_server 是 Xilinx 硬件调试服务器，必须运行才能进行 JTAG 调试。

```bash
# 检查状态
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/hw_server_control.tcl status

# 启动
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/hw_server_control.tcl start

# 或直接启动
"D:/Program-Files/Xilinx/SDK/2019.1/bin/hw_server.bat"

# 停止
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/hw_server_control.tcl stop
```

---

## JTAG 设备检测 (/jtag)

检测连接的 JTAG 设备和可用目标：

```bash
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/jtag_detect.tcl
```

输出信息：
- 可用目标列表
- JTAG 链信息
- Zynq 设备检测状态

---

## FPGA 状态检查 (/fpga-status)

检查 FPGA 配置状态和处理器状态：

```bash
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/fpga_status.tcl
```

输出信息：
- FPGA 配置状态 (DONE pin)
- ARM 核心状态 (PC 值)
- 内存映射概览

---

## CPU 控制 (/cpu)

控制 ARM Cortex-A9 处理器：

```bash
# 显示 CPU 状态和寄存器
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/cpu_control.tcl status

# 停止 CPU
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/cpu_control.tcl stop

# 恢复运行
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/cpu_control.tcl run

# 复位处理器
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/cpu_control.tcl reset

# 控制 CPU #1 (双核)
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/cpu_control.tcl status 1
```

---

## 内存访问 (/mem)

读写 PS 和 PL 内存区域：

```bash
# 读取单个字 (32-bit)
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/memory_access.tcl read 0x43C00000

# 读取多个字
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/memory_access.tcl read 0x43C00000 16

# 读取字节
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/memory_access.tcl read 0x43C00000 4 b

# 写入字
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/memory_access.tcl write 0x43C00000 0x12345678

# 写入字节
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/memory_access.tcl write 0x43C00000 0xFF b

# 内存转储
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/memory_access.tcl dump 0x00000000 64
```

### Zynq 内存映射

| 区域 | 地址范围 | 说明 |
|------|----------|------|
| DDR | 0x00000000 - 0x3FFFFFFF | 最大 1GB DDR 内存 |
| PL AXI GP0 | 0x40000000 - 0x7FFFFFFF | PL 外设区域 0 |
| PL AXI GP1 | 0x80000000 - 0xBFFFFFFF | PL 外设区域 1 |
| SLCR | 0xF8000000 - 0xF8000FFF | 系统级控制寄存器 |
| PS 外设 | 0xE0000000 - 0xF8FFFFFF | UART, GPIO, SPI 等 |
| OCM | 0xFFFC0000 - 0xFFFFFFFF | 片上存储器 256KB |

---

## 系统复位 (/reset)

```bash
# 复位所有 ARM 核心 (默认)
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/system_reset.tcl

# 或明确指定
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/system_reset.tcl --cores

# 复位 PS 子系统
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/system_reset.tcl --ps

# 完整系统复位 (会清除 FPGA 配置!)
"D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat" scripts/xsct/system_reset.tcl --full
```

**警告**: `--full` 模式会清除 FPGA 配置，需要重新烧录比特流！

---

## 脚本位置

| 脚本 | 说明 |
|------|------|
| `scripts/xsct/hw_server_control.tcl` | hw_server 管理 |
| `scripts/xsct/jtag_detect.tcl` | JTAG 设备检测 |
| `scripts/xsct/fpga_status.tcl` | FPGA 状态检查 |
| `scripts/xsct/cpu_control.tcl` | CPU 控制 |
| `scripts/xsct/memory_access.tcl` | 内存读写 |
| `scripts/xsct/system_reset.tcl` | 系统复位 |

---

## XSCT 调试命令速查

```tcl
# 连接
connect

# 列出目标
targets

# 选择目标
targets -set -filter {name =~ "ARM*#0"}

# 停止/运行
stop
con

# 复位
rst -processor    # 复位当前处理器
rst -cores        # 复位处理器组
rst -system       # 系统复位

# 读写内存
mrd 0x0 10        # 读 10 个字
mwr 0x0 0x1234    # 写 1 个字

# 读写寄存器
rrd               # 读所有寄存器
rrd pc            # 读 PC
rwr pc 0x100000   # 写 PC

# 下载程序
dow app.elf

# 断点
bpadd -addr &main
bplist
bpremove -all

# 配置 FPGA
fpga design.bit

# 断开
disconnect
```

---

## 常见问题

### 1. 无法连接 hw_server

```
ERROR: Failed to connect to hw_server.
```

解决方案：
1. 检查 hw_server 是否运行
2. 检查防火墙是否阻止端口 3121
3. 手动启动：`"D:/Program-Files/Xilinx/SDK/2019.1/bin/hw_server.bat"`

### 2. 找不到 JTAG 设备

解决方案：
1. 检查 JTAG 线缆连接
2. 确保开发板已上电
3. 安装正确的驱动（Digilent 或 Xilinx Cable）
4. 尝试重新插拔 USB

### 3. 无法访问内存

解决方案：
1. 确保 CPU 已停止（使用 `/cpu stop`）
2. 检查地址是否有效
3. 对于 PL 区域，确保 FPGA 已配置

### 4. 系统复位后 FPGA 不工作

这是正常的！`--full` 模式会清除 FPGA 配置。
需要重新烧录比特流：
```bash
vivado -mode batch -source program_fpga.tcl -tclargs design.bit
```

### 5. FPGA 状态检测不准确

`fpga_status.tcl` 通过读取 SLCR 寄存器来检测 FPGA 状态，可能不完全准确。

更可靠的方法是通过 Vivado Hardware Manager：
```bash
vivado -mode batch -source scripts/program_fpga.tcl -nojournal -nolog
```

如果能成功烧录，说明 JTAG 工作正常。

### 6. 串口调试

**重要经验**: 不要使用 XSCT 直接写 UART 寄存器来测试串口，这通常不工作。

正确的方法是运行一个包含 `printf` 的程序：
```bash
# 终端 1: 监听串口
python ~/.claude/skills/zynq-sdk/scripts/python/uart_terminal.py COM6 115200

# 终端 2: 下载运行程序
xsct download_elf.tcl app.elf --reset
```

### 7. 物理连接检查

如果串口无输出，首先检查物理连接：
1. **重新插拔盖帽/杜邦线**
2. 确认 TX/RX 没有接反
3. 确认 GND 已连接
4. 确认使用正确的 UART (UART0 = MIO 14/15 或 UART1 = MIO 48/49)
