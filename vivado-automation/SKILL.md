---
name: vivado-automation
description: |
  Xilinx Vivado 2019.1命令行自动化工具，完全通过终端完成FPGA开发全流程。
  触发条件：(1) 用户提到Vivado、FPGA、Verilog/SystemVerilog仿真、综合、实现、比特流等
  (2) 用户要求编译检查RTL代码 (3) 用户要求运行仿真testbench (4) 用户要求查看利用率/时序报告
  (5) 用户要求生成bitstream (6) 用户要求查看综合/实现日志或错误 (7) 用户要求Block Design操作
  (8) 用户要求烧录/下载FPGA (9) 用户说/lint /timing /resources /program
---

# Vivado命令行自动化

## 快速命令参考

| 命令 | 说明 | 脚本 |
|------|------|------|
| `/lint [path]` | RTL语法检查 | xvlog/xvhdl 直接调用 |
| `/sim <tb>` | 运行仿真 | xvlog→xelab→xsim |
| `/synth [xpr]` | 运行综合 | scripts/run_synth.tcl |
| `/impl [xpr]` | 运行实现 | scripts/run_impl.tcl |
| `/timing [xpr]` | 时序分析 | scripts/timing_analysis.tcl |
| `/resources [xpr]` | 资源利用率 | scripts/resource_analysis.tcl |
| `/program [bit]` | 烧录FPGA | scripts/program_fpga.tcl |
| `/reset-ooc [xpr]` | 重置所有OOC | scripts/reset_all_ooc.tcl |

## 核心命令

### 仿真（完整支持 IP 依赖）⭐

我们的仿真脚本**完全支持依赖 Xilinx IP 核的 testbench**，包括：
- Block Memory (BRAM)
- DSP48 Macro
- FIFO Generator
- Block Design 中的 IP
- 任何其他 Xilinx IP

**推荐方式 - Python 脚本：**
```bash
# 运行依赖 IP 核的 testbench
python scripts/run_sim.py project.xpr tb_ModMul

# 指定仿真时间
python scripts/run_sim.py project.xpr tb_ModMul 1000ns

# 运行到仿真结束 ($finish)
python scripts/run_sim.py project.xpr tb_ModMul all
```

**工作原理**：
1. 使用 Vivado `export_simulation` 生成正确的 .prj 文件列表
2. 直接调用 `xvlog` 编译（包含所有 IP 仿真模型）
3. 直接调用 `xelab` 装配（链接所有必要的库）
4. 直接调用 `xsim` 运行仿真

**这种方法避免了 Vivado `launch_simulation` 在批处理模式下的 "Broken pipe" 问题。**

**简单方式 - XSim 直接调用（仅适用于无 IP 依赖的简单 testbench）：**
```bash
# 编译源文件
xvlog -sv -i "include_dir" file1.sv file2.sv testbench.sv

# 装配设计
xelab -debug typical tb_TopModule -s sim_snapshot

# 运行仿真
xsim sim_snapshot -runall
```

**TCL 方式（通过 Vivado 项目运行）：**
```bash
# 使用 run_simulation.tcl（需要项目中已配置好仿真设置）
vivado -mode batch -source scripts/run_simulation.tcl -tclargs project.xpr tb_ModMul 1000ns
```

### 项目操作（TCL批处理）

```bash
# 查询项目状态
vivado -mode batch -source scripts/get_status.tcl -tclargs project.xpr -nojournal -nolog

# 运行综合
vivado -mode batch -source scripts/run_synth.tcl -tclargs project.xpr synth_1 4 -nojournal

# 运行实现
vivado -mode batch -source scripts/run_impl.tcl -tclargs project.xpr impl_1 4 -nojournal

# 生成比特流
vivado -mode batch -source scripts/gen_bitstream.tcl -tclargs project.xpr impl_1 -nojournal

# 完整流程
vivado -mode batch -source scripts/full_flow.tcl -tclargs project.xpr synth_1 impl_1 4 -nojournal
```

## 读取报告

报告位置：`project/.runs/{synth_1,impl_1}/*.rpt`

关键报告：
- `*_utilization_synth.rpt` - 综合后资源利用率
- `*_utilization_placed.rpt` - 布局后资源利用率
- `*_timing_summary_routed.rpt` - 时序分析
- `*_power_routed.rpt` - 功耗分析
- `*_drc_routed.rpt` - 设计规则检查

提取关键指标时，搜索：
- LUT利用率：`Slice LUTs`
- FF利用率：`Slice Registers`
- BRAM：`Block RAM Tile`
- DSP：`DSPs`
- WNS（最差负slack）：`WNS`
- TNS（总负slack）：`TNS`

## 日志分析

日志位置：`project/.runs/{synth_1,impl_1}/*.log`

搜索模式：
- 错误：`ERROR:`
- 警告：`WARNING:`
- 关键警告：`CRITICAL WARNING:`

## Block Design 操作 (完整 CRUD)

### 创建 Block Design
```bash
# 创建空白 BD
vivado -mode batch -nojournal -nolog -source scripts/bd_create.tcl -tclargs project.xpr my_design

# 创建带 Zynq PS 的 BD (自动配置 DDR, FIXED_IO, 时钟和复位)
vivado -mode batch -nojournal -nolog -source scripts/bd_create.tcl -tclargs project.xpr my_design zynq
```

### 添加 IP 到 BD
```bash
# 添加 Xilinx IP
vivado -mode batch -nojournal -nolog -source scripts/bd_add_ip.tcl \
    -tclargs project.xpr xilinx.com:ip:axi_gpio:2.0 my_gpio

# 添加自定义 RTL 模块
vivado -mode batch -nojournal -nolog -source scripts/bd_add_module.tcl \
    -tclargs project.xpr MyCustomModule my_custom_0
```

### 配置 IP 参数
```bash
# 配置参数 (格式: param1 value1 param2 value2 ...)
vivado -mode batch -nojournal -nolog -source scripts/bd_config_ip.tcl \
    -tclargs project.xpr my_const CONST_WIDTH 8 CONST_VAL 255

# 配置 AXI GPIO
vivado -mode batch -nojournal -nolog -source scripts/bd_config_ip.tcl \
    -tclargs project.xpr my_gpio C_GPIO_WIDTH 32 C_ALL_INPUTS 1
```

### 连接 IP
```bash
# 连接 AXI 接口
vivado -mode batch -nojournal -nolog -source scripts/bd_connect.tcl \
    -tclargs project.xpr intf processing_system7_0/M_AXI_GP0 my_ip/S_AXI

# 连接时钟信号
vivado -mode batch -nojournal -nolog -source scripts/bd_connect.tcl \
    -tclargs project.xpr net processing_system7_0/FCLK_CLK0 my_ip/clk

# 连接复位信号
vivado -mode batch -nojournal -nolog -source scripts/bd_connect.tcl \
    -tclargs project.xpr net rst_ps7_0_100M/peripheral_aresetn my_ip/aresetn
```

### 删除 IP
```bash
vivado -mode batch -nojournal -nolog -source scripts/bd_delete_cell.tcl \
    -tclargs project.xpr my_gpio
```

### 查看 BD 信息
```bash
vivado -mode batch -nojournal -nolog -source scripts/bd_info.tcl -tclargs project.xpr
```

### 列出 BD 中的 IP 实例
```bash
vivado -mode batch -nojournal -nolog -source scripts/bd_list_ips.tcl -tclargs project.xpr
```

### 验证并生成 BD 输出
```bash
vivado -mode batch -nojournal -nolog -source scripts/bd_validate.tcl -tclargs project.xpr
```

### 导出 BD 为 TCL 脚本
```bash
vivado -mode batch -nojournal -nolog -source scripts/bd_export_tcl.tcl -tclargs project.xpr output.tcl
```

### BD TCL 命令速查
```tcl
# 打开BD
open_bd_design [get_files *.bd]

# 查看IP实例
get_bd_cells

# 添加IP
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 my_bram

# 添加自定义模块
create_bd_cell -type module -reference MyModule my_instance

# 配置IP参数
set_property -dict [list CONFIG.DATA_WIDTH {64}] [get_bd_cells my_bram]

# 连接接口
connect_bd_intf_net [get_bd_intf_pins cell1/M_AXI] [get_bd_intf_pins cell2/S_AXI]

# 连接信号
connect_bd_net [get_bd_pins ps/FCLK_CLK0] [get_bd_pins my_ip/clk]

# 验证设计
validate_bd_design

# 生成输出
generate_target all [get_files *.bd]
make_wrapper -files [get_files *.bd] -top

# 保存并关闭
save_bd_design
close_bd_design [current_bd_design]
```

---

## IP 核管理 (完整 CRUD)

### 搜索可用 IP
```bash
# 列出所有可用 IP
vivado -mode batch -nojournal -nolog -source scripts/ip_search.tcl -tclargs project.xpr

# 搜索特定关键字
vivado -mode batch -nojournal -nolog -source scripts/ip_search.tcl -tclargs project.xpr axi
vivado -mode batch -nojournal -nolog -source scripts/ip_search.tcl -tclargs project.xpr bram
```

### 创建自定义 IP (从 RTL 模块封装)
```bash
# 将 RTL 模块封装为可复用 IP
vivado -mode batch -nojournal -nolog -source scripts/ip_create.tcl \
    -tclargs project.xpr MyModule my_custom_ip_v1_0

# 指定输出目录
vivado -mode batch -nojournal -nolog -source scripts/ip_create.tcl \
    -tclargs project.xpr MyModule my_custom_ip_v1_0 ./ip_repo
```

### 查看项目 IP 状态
```bash
vivado -mode batch -nojournal -nolog -source scripts/ip_status.tcl -tclargs project.xpr
```

### IP TCL 命令速查
```tcl
# 列出项目中的IP
get_files -filter {FILE_TYPE == "IP"}

# 获取IP属性
get_property IPDEF [get_files my_ip.xci]

# 升级IP版本
upgrade_ip [get_ips my_ip]

# 生成IP产品
generate_target all [get_files my_ip.xci]

# 报告IP状态
report_ip_status

# 添加 IP 仓库
set_property IP_REPO_PATHS [concat [get_property IP_REPO_PATHS [current_project]] ./ip_repo] [current_project]
update_ip_catalog
```

### Zynq PS 配置 (zynq_ps_config.tcl)

专用脚本查看和编辑 Zynq Processing System 7 配置：

```bash
# 查看时钟配置
vivado -mode batch -source scripts/zynq_ps_config.tcl -tclargs project.xpr show clocks

# 查看 UART 配置
vivado -mode batch -source scripts/zynq_ps_config.tcl -tclargs project.xpr show uart

# 查看外设启用状态
vivado -mode batch -source scripts/zynq_ps_config.tcl -tclargs project.xpr show periph

# 查看 GPIO/MIO 配置
vivado -mode batch -source scripts/zynq_ps_config.tcl -tclargs project.xpr show gpio

# 查看 AXI 接口配置
vivado -mode batch -source scripts/zynq_ps_config.tcl -tclargs project.xpr show axi

# 查看 DDR 配置
vivado -mode batch -source scripts/zynq_ps_config.tcl -tclargs project.xpr show ddr

# 修改 FCLK0 频率为 100 MHz
vivado -mode batch -source scripts/zynq_ps_config.tcl -tclargs project.xpr set PCW_FPGA0_PERIPHERAL_FREQMHZ 100

# 启用 UART1
vivado -mode batch -source scripts/zynq_ps_config.tcl -tclargs project.xpr set PCW_UART1_PERIPHERAL_ENABLE 1
```

配置类别：
| 类别 | 说明 |
|------|------|
| `clocks` | FCLK0-3 时钟配置 |
| `uart` | UART 配置 |
| `gpio` | GPIO/MIO/EMIO 配置 |
| `ddr` | DDR 内存配置 |
| `axi` | AXI GP/HP/ACP 接口 |
| `periph` | 外设启用状态 |
| `all` | 所有配置 (800+参数) |

---

### 常用 IP VLNV 参考
| IP 名称 | VLNV |
|---------|------|
| Zynq Processing System | `xilinx.com:ip:processing_system7:5.5` |
| AXI BRAM Controller | `xilinx.com:ip:axi_bram_ctrl:4.1` |
| Block Memory Generator | `xilinx.com:ip:blk_mem_gen:8.4` |
| AXI GPIO | `xilinx.com:ip:axi_gpio:2.0` |
| AXI UART Lite | `xilinx.com:ip:axi_uartlite:2.0` |
| AXI Timer | `xilinx.com:ip:axi_timer:2.0` |
| AXI DMA | `xilinx.com:ip:axi_dma:7.1` |
| AXI CDMA | `xilinx.com:ip:axi_cdma:4.1` |
| AXI Interconnect | `xilinx.com:ip:axi_interconnect:2.1` |
| Processor System Reset | `xilinx.com:ip:proc_sys_reset:5.0` |
| Clocking Wizard | `xilinx.com:ip:clk_wiz:6.0` |
| Concat | `xilinx.com:ip:xlconcat:2.1` |
| Constant | `xilinx.com:ip:xlconstant:1.1` |
| Slice | `xilinx.com:ip:xlslice:1.0` |

---

## 脚本位置

### 构建流程
- `scripts/get_status.tcl` - 查询综合/实现状态
- `scripts/run_synth.tcl` - 运行综合
- `scripts/run_impl.tcl` - 运行实现
- `scripts/gen_bitstream.tcl` - 生成比特流
- `scripts/full_flow.tcl` - 完整构建流程
- `scripts/reset_all_ooc.tcl` - 重置所有OOC综合运行

### 仿真
- `scripts/run_sim.py` - **Python 仿真脚本（完整支持 IP 依赖）** ⭐
- `scripts/run_simulation.tcl` - TCL 仿真脚本（通过 Vivado 项目）

### 分析报告
- `scripts/timing_analysis.tcl` - 详细时序分析（WNS/TNS/关键路径）
- `scripts/resource_analysis.tcl` - 资源利用率分析（LUT/FF/BRAM/DSP）

### 硬件编程
- `scripts/program_fpga.tcl` - 通过JTAG烧录比特流

### Block Design (完整 CRUD)
- `scripts/bd_create.tcl` - **创建** Block Design (可选带 Zynq PS)
- `scripts/bd_add_ip.tcl` - **添加** Xilinx IP 到 BD
- `scripts/bd_add_module.tcl` - **添加** 自定义 RTL 模块到 BD
- `scripts/bd_config_ip.tcl` - **配置** IP 参数
- `scripts/bd_connect.tcl` - **连接** 信号和接口
- `scripts/bd_delete_cell.tcl` - **删除** IP 实例
- `scripts/bd_info.tcl` - 查看BD设计信息
- `scripts/bd_list_ips.tcl` - 列出BD中IP实例
- `scripts/bd_validate.tcl` - 验证并生成BD输出
- `scripts/bd_export_tcl.tcl` - 导出BD为TCL脚本

### IP 核 (完整 CRUD)
- `scripts/ip_search.tcl` - **搜索** 可用 IP
- `scripts/ip_create.tcl` - **创建** 自定义 IP (从 RTL 封装)
- `scripts/ip_status.tcl` - 报告IP状态

### Zynq PS 配置
- `scripts/zynq_ps_config.tcl` - **查看和编辑** Zynq PS7 配置 (时钟/UART/GPIO/DDR/AXI等)

详细TCL命令参考：`references/tcl_commands.md`

---

## 时序分析 (/timing)

```bash
# 分析时序（自动检测项目）
vivado -mode batch -source scripts/timing_analysis.tcl -nojournal -nolog

# 指定项目
vivado -mode batch -source scripts/timing_analysis.tcl -tclargs project/MyProject.xpr -nojournal -nolog
```

输出内容：
- WNS (最差负slack) / TNS (总负slack)
- WHS (最差保持slack) / THS (总保持slack)
- 前10条关键路径详情
- 时钟频率汇总

---

## 资源分析 (/resources)

```bash
# 分析资源（自动检测项目）
vivado -mode batch -source scripts/resource_analysis.tcl -nojournal -nolog

# 指定项目和运行
vivado -mode batch -source scripts/resource_analysis.tcl -tclargs project/MyProject.xpr synth_1 -nojournal -nolog
```

输出内容：
- LUT/FF/BRAM/DSP 使用量和利用率百分比
- 按顶层模块的层次化分解

---

## FPGA烧录 (/program)

```bash
# 自动检测比特流并烧录
vivado -mode batch -source scripts/program_fpga.tcl -nojournal -nolog

# 指定比特流文件
vivado -mode batch -source scripts/program_fpga.tcl -tclargs output.bit -nojournal -nolog

# 带调试探针
vivado -mode batch -source scripts/program_fpga.tcl -tclargs output.bit output.ltx -nojournal -nolog
```

注意：需要 hw_server 运行或 JTAG 直接连接

---

## RTL Linting (/lint)

直接使用 xvlog/xvhdl 进行语法检查：

```bash
# 检查单个文件
xvlog -sv src/MyModule.sv

# 检查整个目录
xvlog -sv -i src src/**/*.sv

# VHDL 文件
xvhdl src/*.vhd
```

---

## 重置OOC综合 (/reset-ooc)

当修改RTL后综合结果不变时使用：

```bash
vivado -mode batch -source scripts/reset_all_ooc.tcl -tclargs project/MyProject.xpr -nojournal -nolog
```

## 注意事项

1. **仿真优先使用XSim直接调用**（xvlog→xelab→xsim），比launch_simulation更可靠
2. **Vivado批处理模式**需要`-mode batch`参数
3. **路径使用正斜杠**（Windows下TCL也用`/`）
4. **长时间操作**（综合/实现）建议后台运行
5. **-nojournal -nolog**可减少生成的临时文件

## Python 依赖

串口功能需要安装 pyserial：
```bash
pip install pyserial
```

## 工具路径配置

```bash
# Vivado (已在 PATH 中)
vivado -version

# SDK/XSCT (使用完整路径)
XSCT="D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat"
HW_SERVER="D:/Program-Files/Xilinx/SDK/2019.1/bin/hw_server.bat"
```

---

## ⚠️ 常见陷阱与解决方案

### 陷阱1: OOC (Out-of-Context) 综合缓存 ⭐ 最重要

**问题**: Block Design 中的自定义模块使用 OOC 方式独立综合。`reset_run synth_1` 只重置顶层综合，**不会触发 OOC 模块重新综合**。

**症状**: 修改了 RTL 源代码后，综合结果完全相同。

**解决方案**: 重置所有 OOC 综合 run：
```tcl
# 重置所有综合 run（包括 OOC）
set all_runs [get_runs -filter {IS_SYNTHESIS}]
foreach run $all_runs {
    puts "Resetting: $run"
    reset_run $run
}

# 重置所有实现 run
set impl_runs [get_runs -filter {IS_IMPLEMENTATION}]
foreach run $impl_runs {
    reset_run $run
}
```

**验证方法**: 检查 OOC 综合日志的时间戳：
```bash
ls -la project/*.runs/*_synth_1/*.rpt | head -5
```

### 陷阱2: 器件速度等级被意外修改

**问题**: run 的器件设置可能被意外修改（如 `-2` 变成 `-1`）。

**症状**: 原本能收敛的设计突然时序失败。

**解决方案**: 检查并修复所有 run 的 PART 属性：
```tcl
set target_part "xc7z020clg400-2"  # 根据实际项目修改

# 检查当前设置
puts "Project: [get_property PART [current_project]]"
puts "synth_1: [get_property PART [get_runs synth_1]]"
puts "impl_1:  [get_property PART [get_runs impl_1]]"

# 修复所有 run
set_property PART $target_part [current_project]
foreach run [get_runs] {
    set_property PART $target_part $run
}
```

**验证方法**: 检查报告头部的器件信息：
```bash
head -10 project/*.runs/impl_1/*_utilization_placed.rpt | grep "Part"
```

### 陷阱3: 源文件未添加到项目

**问题**: 文件存在于目录中，但没有被添加到 Vivado 项目的 fileset。

**症状**: 综合失败，报 "module 'XXX' not found"。

**解决方案**: 添加文件并更新编译顺序：
```tcl
# 检查文件是否已在项目中
get_files -quiet *MyModule.sv

# 添加文件
add_files -norecurse /path/to/MyModule.sv

# 更新编译顺序
update_compile_order -fileset sources_1

# 验证
get_files *MyModule.sv
```

### 陷阱4: dcp 文件锁定

**问题**: 之前的 Vivado 进程锁着 .dcp 文件。

**症状**: "Failed to open zip archive ... .dcp" 错误。

**解决方案**:
```bash
# 删除旧的 dcp 文件
rm -f project/*.runs/*_synth_1/*.dcp
rm -f project/*.runs/*_impl_1/*.dcp
```

### 陷阱5: 综合状态检查不完整

**问题**: `get_property STATUS [get_runs synth_1]` 可能返回 "Scripts Generated" 而非 "Complete"。

**症状**: 脚本认为综合失败，但实际上只是在等待 OOC 综合完成。

**解决方案**: 检查所有相关 run 的状态：
```tcl
# 检查所有综合 run 状态
foreach run [get_runs -filter {IS_SYNTHESIS}] {
    set status [get_property STATUS $run]
    if {[string match "*ERROR*" $status]} {
        puts "FAILED: $run - $status"
    } else {
        puts "OK: $run - $status"
    }
}
```

---

## 完整重建流程（推荐）

当修改了 RTL 源代码后，使用以下脚本确保完整重建：

```tcl
# reset_all_and_build.tcl
set proj_path "project/MyProject.xpr"
set target_part "xc7z020clg400-2"

open_project $proj_path

# 1. 修复所有 run 的器件设置
foreach run [get_runs] {
    set_property PART $target_part $run
}

# 2. 重置所有综合 run（包括 OOC）
foreach run [get_runs -filter {IS_SYNTHESIS}] {
    reset_run $run
}

# 3. 重置所有实现 run
foreach run [get_runs -filter {IS_IMPLEMENTATION}] {
    reset_run $run
}

# 4. 运行综合
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# 5. 检查综合状态
set synth_status [get_property STATUS [get_runs synth_1]]
if {![string match "*Complete*" $synth_status]} {
    puts "ERROR: Synthesis failed!"
    # 检查 OOC 状态
    foreach run [get_runs -filter {IS_SYNTHESIS}] {
        puts "  $run: [get_property STATUS $run]"
    }
    exit 1
}

# 6. 运行实现
launch_runs impl_1 -jobs 4
wait_on_run impl_1

# 7. 生成比特流
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

close_project
```
