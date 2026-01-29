# Vivado TCL命令速查

## 项目操作

```tcl
# 打开/关闭项目
open_project path/to/project.xpr
close_project

# 创建内存项目
create_project -in_memory -part xc7z020clg400-1

# 获取项目信息
get_property NAME [current_project]
get_property PART [current_project]
get_property DIRECTORY [current_project]
```

## 运行管理

```tcl
# 获取综合/实现运行
get_runs -filter {IS_SYNTHESIS == 1}
get_runs -filter {IS_IMPLEMENTATION == 1}

# 运行状态
get_property STATUS [get_runs synth_1]
get_property PROGRESS [get_runs synth_1]

# 执行运行
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# 执行到特定步骤
launch_runs impl_1 -to_step write_bitstream
```

## 文件操作

```tcl
# 获取文件列表
get_files -filter {FILE_TYPE =~ *Verilog*}
get_files -filter {FILE_TYPE == SystemVerilog}
get_files -filter {FILE_TYPE == XDC}

# 添加文件
add_files -fileset sources_1 file.sv
read_verilog -sv file.sv

# 设置include路径
set_property include_dirs [list path/to/include] [current_fileset -simset]
```

## 报告生成

```tcl
# 利用率
report_utilization -file util.rpt

# 时序
report_timing_summary -max_paths 10 -file timing.rpt

# DRC
report_drc -file drc.rpt

# 功耗
report_power -file power.rpt

# 时钟
report_clock_utilization -file clocks.rpt
```

## Block Design

```tcl
# 获取BD文件
get_files *.bd

# 打开BD
open_bd_design [get_files *.bd]
open_bd_design path/to/design.bd

# 当前BD设计
current_bd_design

# 关闭BD
close_bd_design [current_bd_design]

# 保存BD
save_bd_design

# 验证设计
validate_bd_design

# 生成BD输出
generate_target all [get_files design.bd]

# 创建HDL包装器
make_wrapper -files [get_files design.bd] -top

# 导出BD为TCL脚本
write_bd_tcl -force output.tcl
```

## BD单元格（IP实例）操作

```tcl
# 列出所有单元格
get_bd_cells

# 创建IP实例
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 my_bram

# 创建自定义模块实例
create_bd_cell -type module -reference MyModule my_instance

# 删除单元格
delete_bd_objs [get_bd_cells my_cell]

# 获取单元格属性
get_property VLNV [get_bd_cells my_cell]
get_property CONFIG.DATA_WIDTH [get_bd_cells my_cell]

# 设置IP参数
set_property -dict [list \
    CONFIG.DATA_WIDTH {64} \
    CONFIG.READ_LATENCY {2} \
] [get_bd_cells my_bram]

# 列出所有CONFIG属性
list_property [get_bd_cells my_cell] CONFIG.*
```

## BD接口连接

```tcl
# 获取接口端口
get_bd_intf_ports
get_bd_intf_pins

# 获取单元格的接口引脚
get_bd_intf_pins -of_objects [get_bd_cells my_cell]

# 连接接口
connect_bd_intf_net [get_bd_intf_pins cell1/M_AXI] [get_bd_intf_pins cell2/S_AXI]

# 带名称连接
connect_bd_intf_net -intf_net my_axi_net \
    [get_bd_intf_pins ps/M_AXI_GP0] \
    [get_bd_intf_pins interconnect/S00_AXI]

# 获取接口网络
get_bd_intf_nets
```

## BD信号连接

```tcl
# 获取普通端口
get_bd_ports
get_bd_pins

# 获取单元格的引脚
get_bd_pins -of_objects [get_bd_cells my_cell]

# 连接信号
connect_bd_net [get_bd_pins ps/FCLK_CLK0] [get_bd_pins my_ip/clk]

# 连接多个目标
connect_bd_net -net clk_net \
    [get_bd_pins ps/FCLK_CLK0] \
    [get_bd_pins ip1/clk] \
    [get_bd_pins ip2/clk]

# 获取信号网络
get_bd_nets
```

## BD地址映射

```tcl
# 创建地址段
create_bd_addr_seg -range 0x00040000 -offset 0xC0000000 \
    [get_bd_addr_spaces cdma/Data] \
    [get_bd_addr_segs bram_ctrl/S_AXI/Mem0] \
    SEG_bram_ctrl_Mem0

# 获取地址空间
get_bd_addr_spaces
get_bd_addr_segs
```

## IP核管理

```tcl
# 列出项目中的IP
get_files -filter {FILE_TYPE == "IP"}

# 获取IP属性
get_property IPDEF [get_files my_ip.xci]
get_property IS_LOCKED [get_files my_ip.xci]
get_property UPGRADE_VERSIONS [get_files my_ip.xci]

# 升级IP版本
upgrade_ip [get_ips my_ip]

# 锁定/解锁IP
set_property IS_LOCKED 1 [get_files my_ip.xci]
set_property IS_LOCKED 0 [get_files my_ip.xci]

# 生成IP产品
generate_target all [get_files my_ip.xci]

# 报告IP状态
report_ip_status

# 搜索可用IP
get_ipdefs
get_ipdefs -filter {NAME =~ "axi_*"}
```

## 综合设计命令

```tcl
synth_design -top TopModule -part xc7z020clg400-1 \
    -fanout_limit 400 \
    -fsm_extraction one_hot

write_checkpoint -force design.dcp
```

## 实现设计命令

```tcl
opt_design -directive Explore
place_design -directive ExtraTimingOpt
phys_opt_design -directive Explore
route_design -directive AggressiveExplore
write_checkpoint -force routed.dcp
write_bitstream -force design.bit
```
