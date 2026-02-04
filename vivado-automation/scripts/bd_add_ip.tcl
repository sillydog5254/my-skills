# bd_add_ip.tcl - 向 Block Design 添加 IP 核
# 用法: vivado -mode batch -source bd_add_ip.tcl -tclargs <project.xpr> <vlnv> <instance_name> [bd_name]
#
# 参数:
#   project.xpr   - Vivado 项目文件
#   vlnv          - IP 的 VLNV 标识符 (如 xilinx.com:ip:axi_bram_ctrl:4.1)
#   instance_name - 实例名称
#   bd_name       - 可选，Block Design 名称

if {$argc < 3} {
    puts "Usage: vivado -mode batch -source bd_add_ip.tcl -tclargs <project.xpr> <vlnv> <instance_name> \[bd_name\]"
    puts ""
    puts "Common IP VLNVs:"
    puts "  xilinx.com:ip:processing_system7:5.5    - Zynq PS"
    puts "  xilinx.com:ip:axi_bram_ctrl:4.1         - AXI BRAM Controller"
    puts "  xilinx.com:ip:blk_mem_gen:8.4           - Block Memory Generator"
    puts "  xilinx.com:ip:axi_gpio:2.0              - AXI GPIO"
    puts "  xilinx.com:ip:axi_uartlite:2.0          - AXI UART Lite"
    puts "  xilinx.com:ip:axi_dma:7.1               - AXI DMA"
    puts "  xilinx.com:ip:axi_interconnect:2.1      - AXI Interconnect"
    puts "  xilinx.com:ip:proc_sys_reset:5.0        - Processor System Reset"
    puts "  xilinx.com:ip:xlconcat:2.1              - Concat"
    puts "  xilinx.com:ip:xlconstant:1.1            - Constant"
    puts "  xilinx.com:ip:xlslice:1.0               - Slice"
    puts ""
    puts "Example:"
    puts "  vivado -mode batch -source bd_add_ip.tcl -tclargs project.xpr xilinx.com:ip:axi_gpio:2.0 my_gpio"
    exit 1
}

set proj_path [lindex $argv 0]
set vlnv [lindex $argv 1]
set instance_name [lindex $argv 2]
set bd_name [expr {$argc > 3 ? [lindex $argv 3] : ""}]

puts "============================================"
puts "       ADD IP TO BLOCK DESIGN"
puts "============================================"
puts "Project:  $proj_path"
puts "IP VLNV:  $vlnv"
puts "Instance: $instance_name"
puts "============================================"

# 打开项目
puts "\nOpening project..."
open_project $proj_path

# 获取 BD 文件
if {$bd_name eq ""} {
    set bd_files [get_files *.bd]
    if {[llength $bd_files] == 0} {
        puts "ERROR: No Block Design found in project."
        close_project
        exit 1
    }
    set bd_file [lindex $bd_files 0]
} else {
    set bd_file [get_files *$bd_name.bd]
}

puts "Opening BD: $bd_file"
open_bd_design $bd_file

# 检查实例名是否已存在
set existing [get_bd_cells -quiet $instance_name]
if {$existing ne ""} {
    puts "ERROR: Cell '$instance_name' already exists!"
    close_bd_design [current_bd_design]
    close_project
    exit 1
}

# 添加 IP
puts "\nAdding IP: $vlnv as $instance_name..."
if {[catch {create_bd_cell -type ip -vlnv $vlnv $instance_name} result]} {
    puts "ERROR: Failed to create IP - $result"
    puts ""
    puts "Searching for available IPs matching pattern..."
    set ip_name [lindex [split $vlnv :] 2]
    set available [get_ipdefs -filter "NAME =~ *$ip_name*"]
    if {[llength $available] > 0} {
        puts "Available matches:"
        foreach ip $available {
            puts "  $ip"
        }
    }
    close_bd_design [current_bd_design]
    close_project
    exit 1
}

puts "IP added successfully!"

# 显示 IP 属性
puts "\n=== IP Properties ==="
set cell [get_bd_cells $instance_name]
puts "VLNV: [get_property VLNV $cell]"
puts "Name: [get_property NAME $cell]"

# 显示可配置参数
puts "\n=== Configurable Parameters ==="
set config_props [list_property $cell CONFIG.*]
set count 0
foreach prop $config_props {
    set val [get_property $prop $cell]
    if {$val ne "" && $count < 20} {
        puts "  $prop = $val"
        incr count
    }
}
if {$count >= 20} {
    puts "  ... ([llength $config_props] total parameters)"
}

# 显示端口
puts "\n=== Interface Pins ==="
foreach pin [get_bd_intf_pins -of_objects $cell] {
    set mode [get_property MODE $pin]
    puts "  $pin ($mode)"
}

puts "\n=== Signal Pins ==="
set pins [get_bd_pins -of_objects $cell]
if {[llength $pins] <= 20} {
    foreach pin $pins {
        set dir [get_property DIR $pin]
        puts "  $pin ($dir)"
    }
} else {
    puts "  ([llength $pins] pins - use bd_info.tcl for full list)"
}

# 保存设计
puts "\nSaving design..."
save_bd_design

close_bd_design [current_bd_design]
close_project
puts "\n============================================"
puts "IP '$instance_name' added successfully!"
puts "============================================"
