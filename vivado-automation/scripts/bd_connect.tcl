# bd_connect.tcl - 在 Block Design 中连接信号和接口
# 用法: vivado -mode batch -source bd_connect.tcl -tclargs <project.xpr> <connection_type> <source> <dest> [bd_name]
#
# 参数:
#   project.xpr     - Vivado 项目文件
#   connection_type - 连接类型: "intf" (接口) 或 "net" (信号)
#   source          - 源端口/引脚 (格式: cell_name/pin_name)
#   dest            - 目标端口/引脚 (格式: cell_name/pin_name)
#   bd_name         - 可选，Block Design 名称

if {$argc < 4} {
    puts "Usage: vivado -mode batch -source bd_connect.tcl -tclargs <project.xpr> <type> <source> <dest> \[bd_name\]"
    puts ""
    puts "Connection types:"
    puts "  intf - Connect interface pins (e.g., AXI buses)"
    puts "  net  - Connect signal pins (e.g., clocks, resets)"
    puts ""
    puts "Examples:"
    puts "  # Connect AXI interface"
    puts "  vivado -mode batch -source bd_connect.tcl -tclargs project.xpr intf processing_system7_0/M_AXI_GP0 my_ip/S_AXI"
    puts ""
    puts "  # Connect clock signal"
    puts "  vivado -mode batch -source bd_connect.tcl -tclargs project.xpr net processing_system7_0/FCLK_CLK0 my_ip/clk"
    puts ""
    puts "  # Connect reset signal"
    puts "  vivado -mode batch -source bd_connect.tcl -tclargs project.xpr net rst_ps7_0_100M/peripheral_aresetn my_ip/aresetn"
    exit 1
}

set proj_path [lindex $argv 0]
set conn_type [lindex $argv 1]
set source_pin [lindex $argv 2]
set dest_pin [lindex $argv 3]
set bd_name [expr {$argc > 4 ? [lindex $argv 4] : ""}]

puts "============================================"
puts "      CONNECT PINS IN BLOCK DESIGN"
puts "============================================"
puts "Project: $proj_path"
puts "Type:    $conn_type"
puts "Source:  $source_pin"
puts "Dest:    $dest_pin"
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

# 执行连接
if {$conn_type eq "intf"} {
    # 接口连接
    puts "\nConnecting interface pins..."

    set src [get_bd_intf_pins -quiet $source_pin]
    set dst [get_bd_intf_pins -quiet $dest_pin]

    if {$src eq ""} {
        puts "ERROR: Source interface pin '$source_pin' not found!"
        puts "Available interface pins:"
        foreach cell [get_bd_cells] {
            foreach pin [get_bd_intf_pins -of_objects $cell] {
                puts "  $pin"
            }
        }
        close_bd_design [current_bd_design]
        close_project
        exit 1
    }

    if {$dst eq ""} {
        puts "ERROR: Destination interface pin '$dest_pin' not found!"
        close_bd_design [current_bd_design]
        close_project
        exit 1
    }

    if {[catch {connect_bd_intf_net $src $dst} err]} {
        puts "ERROR: Failed to connect - $err"
        close_bd_design [current_bd_design]
        close_project
        exit 1
    }

    puts "Interface connection created: $source_pin -> $dest_pin"

} elseif {$conn_type eq "net"} {
    # 信号连接
    puts "\nConnecting signal pins..."

    set src [get_bd_pins -quiet $source_pin]
    set dst [get_bd_pins -quiet $dest_pin]

    if {$src eq ""} {
        puts "ERROR: Source pin '$source_pin' not found!"
        close_bd_design [current_bd_design]
        close_project
        exit 1
    }

    if {$dst eq ""} {
        puts "ERROR: Destination pin '$dest_pin' not found!"
        close_bd_design [current_bd_design]
        close_project
        exit 1
    }

    if {[catch {connect_bd_net $src $dst} err]} {
        puts "ERROR: Failed to connect - $err"
        close_bd_design [current_bd_design]
        close_project
        exit 1
    }

    puts "Signal connection created: $source_pin -> $dest_pin"

} else {
    puts "ERROR: Unknown connection type '$conn_type'. Use 'intf' or 'net'."
    close_bd_design [current_bd_design]
    close_project
    exit 1
}

# 验证设计
puts "\nValidating design..."
if {[catch {validate_bd_design} err]} {
    puts "WARNING: Validation issues: $err"
}

# 保存设计
puts "\nSaving design..."
save_bd_design

close_bd_design [current_bd_design]
close_project
puts "\n============================================"
puts "Connection created successfully!"
puts "============================================"
