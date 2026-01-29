---
name: vivado-automation
description: |
  Xilinx Vivado 2019.1命令行自动化工具，完全通过终端完成FPGA开发全流程。
  触发条件：(1) 用户提到Vivado、FPGA、Verilog/SystemVerilog仿真、综合、实现、比特流等
  (2) 用户要求编译检查RTL代码 (3) 用户要求运行仿真testbench (4) 用户要求查看利用率/时序报告
  (5) 用户要求生成bitstream (6) 用户要求查看综合/实现日志或错误 (7) 用户要求Block Design操作
---

# Vivado命令行自动化

## 核心命令

### 仿真（XSim直接调用，最快）

```bash
# 编译源文件
xvlog -sv -i "include_dir" file1.sv file2.sv testbench.sv

# 装配设计
xelab -debug typical tb_TopModule -s sim_snapshot

# 运行仿真
xsim sim_snapshot -runall
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

## Block Design操作

### 查看BD信息
```bash
vivado -mode batch -nojournal -nolog -source scripts/bd_info.tcl -tclargs project.xpr
```

### 列出BD中的IP实例
```bash
vivado -mode batch -nojournal -nolog -source scripts/bd_list_ips.tcl -tclargs project.xpr
```

### 验证并生成BD输出
```bash
vivado -mode batch -nojournal -nolog -source scripts/bd_validate.tcl -tclargs project.xpr
```

### 导出BD为TCL脚本
```bash
vivado -mode batch -nojournal -nolog -source scripts/bd_export_tcl.tcl -tclargs project.xpr output.tcl
```

### BD TCL命令速查
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

## IP核管理

### 查看IP状态
```bash
vivado -mode batch -nojournal -nolog -source scripts/ip_status.tcl -tclargs project.xpr
```

### IP TCL命令速查
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
```

### 常用IP VLNV参考
| IP名称 | VLNV |
|--------|------|
| AXI BRAM Controller | `xilinx.com:ip:axi_bram_ctrl:4.1` |
| AXI CDMA | `xilinx.com:ip:axi_cdma:4.1` |
| AXI Interconnect | `xilinx.com:ip:axi_interconnect:2.1` |
| Processing System 7 | `xilinx.com:ip:processing_system7:5.5` |
| Processor System Reset | `xilinx.com:ip:proc_sys_reset:5.0` |
| Block Memory Generator | `xilinx.com:ip:blk_mem_gen:8.4` |
| DSP48 Macro | `xilinx.com:ip:xbip_dsp48_macro:3.0` |

## 脚本位置

### 构建流程
- `scripts/get_status.tcl` - 查询综合/实现状态
- `scripts/run_synth.tcl` - 运行综合
- `scripts/run_impl.tcl` - 运行实现
- `scripts/gen_bitstream.tcl` - 生成比特流
- `scripts/full_flow.tcl` - 完整构建流程

### Block Design
- `scripts/bd_info.tcl` - 查看BD设计信息
- `scripts/bd_list_ips.tcl` - 列出BD中IP实例
- `scripts/bd_validate.tcl` - 验证并生成BD输出
- `scripts/bd_export_tcl.tcl` - 导出BD为TCL脚本

### IP核
- `scripts/ip_status.tcl` - 报告IP状态

详细TCL命令参考：`references/tcl_commands.md`

## 注意事项

1. **仿真优先使用XSim直接调用**（xvlog→xelab→xsim），比launch_simulation更可靠
2. **Vivado批处理模式**需要`-mode batch`参数
3. **路径使用正斜杠**（Windows下TCL也用`/`）
4. **长时间操作**（综合/实现）建议后台运行
5. **-nojournal -nolog**可减少生成的临时文件
