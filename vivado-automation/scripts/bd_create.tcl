# bd_create.tcl - 创建新的 Block Design
# 用法: vivado -mode batch -source bd_create.tcl -tclargs <project.xpr> <bd_name> [with_zynq]
#
# 参数:
#   project.xpr - Vivado 项目文件
#   bd_name     - Block Design 名称
#   with_zynq   - 可选，如果为 "zynq" 则自动添加 Zynq PS

if {$argc < 2} {
    puts "Usage: vivado -mode batch -source bd_create.tcl -tclargs <project.xpr> <bd_name> \[with_zynq\]"
    puts ""
    puts "Examples:"
    puts "  vivado -mode batch -source bd_create.tcl -tclargs project.xpr my_design"
    puts "  vivado -mode batch -source bd_create.tcl -tclargs project.xpr my_design zynq"
    exit 1
}

set proj_path [lindex $argv 0]
set bd_name [lindex $argv 1]
set with_zynq [expr {$argc > 2 && [lindex $argv 2] eq "zynq"}]

puts "============================================"
puts "       CREATE BLOCK DESIGN"
puts "============================================"
puts "Project:  $proj_path"
puts "BD Name:  $bd_name"
puts "With Zynq PS: [expr {$with_zynq ? \"YES\" : \"NO\"}]"
puts "============================================"

# 打开项目
puts "\nOpening project..."
open_project $proj_path

# 检查 BD 是否已存在
set existing_bds [get_files -quiet *$bd_name.bd]
if {[llength $existing_bds] > 0} {
    puts "ERROR: Block Design '$bd_name' already exists!"
    puts "Existing: $existing_bds"
    close_project
    exit 1
}

# 创建 Block Design
puts "\nCreating Block Design: $bd_name..."
create_bd_design $bd_name

# 如果需要添加 Zynq PS
if {$with_zynq} {
    puts "\nAdding Zynq Processing System..."

    # 添加 Zynq PS IP
    set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0]

    # 运行默认自动化配置
    puts "Running block automation..."
    apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
        -config { \
            make_external "FIXED_IO, DDR" \
            apply_board_preset "1" \
            Master "Disable" \
            Slave "Disable" \
        } [get_bd_cells processing_system7_0]

    # 配置基本的时钟和复位
    puts "Configuring PS clocks..."
    set_property -dict [list \
        CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} \
        CONFIG.PCW_USE_M_AXI_GP0 {1} \
        CONFIG.PCW_USE_FABRIC_INTERRUPT {0} \
    ] [get_bd_cells processing_system7_0]

    # 添加处理器系统复位
    puts "Adding Processor System Reset..."
    set rst [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps7_0_100M]

    # 连接时钟和复位
    connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] \
                   [get_bd_pins rst_ps7_0_100M/slowest_sync_clk]
    connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] \
                   [get_bd_pins rst_ps7_0_100M/ext_reset_in]

    puts "Zynq PS added successfully!"
}

# 验证设计
puts "\nValidating design..."
if {[catch {validate_bd_design} err]} {
    puts "WARNING: Validation issues: $err"
} else {
    puts "Design validation passed!"
}

# 保存设计
puts "\nSaving design..."
save_bd_design

# 生成输出产品
puts "\nGenerating output products..."
generate_target all [get_files $bd_name.bd]

# 创建 HDL Wrapper
puts "\nCreating HDL wrapper..."
make_wrapper -files [get_files $bd_name.bd] -top
set wrapper_file [get_files -quiet ${bd_name}_wrapper.v]
if {$wrapper_file ne ""} {
    add_files -norecurse $wrapper_file
    puts "Wrapper created: $wrapper_file"
}

# 更新编译顺序
update_compile_order -fileset sources_1

close_project
puts "\n============================================"
puts "Block Design '$bd_name' created successfully!"
puts "============================================"
