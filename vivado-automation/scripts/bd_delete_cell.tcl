# bd_delete_cell.tcl - 从 Block Design 中删除 IP 实例
# 用法: vivado -mode batch -source bd_delete_cell.tcl -tclargs <project.xpr> <instance_name> [bd_name]
#
# 参数:
#   project.xpr   - Vivado 项目文件
#   instance_name - 要删除的 IP 实例名称
#   bd_name       - 可选，Block Design 名称

if {$argc < 2} {
    puts "Usage: vivado -mode batch -source bd_delete_cell.tcl -tclargs <project.xpr> <instance_name> \[bd_name\]"
    puts ""
    puts "Example:"
    puts "  vivado -mode batch -source bd_delete_cell.tcl -tclargs project.xpr my_gpio_0"
    exit 1
}

set proj_path [lindex $argv 0]
set instance_name [lindex $argv 1]
set bd_name [expr {$argc > 2 ? [lindex $argv 2] : ""}]

puts "============================================"
puts "    DELETE CELL FROM BLOCK DESIGN"
puts "============================================"
puts "Project:  $proj_path"
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

# 获取实例
set cell [get_bd_cells -quiet $instance_name]
if {$cell eq ""} {
    puts "ERROR: Cell '$instance_name' not found!"
    puts "Available cells:"
    foreach c [get_bd_cells] {
        puts "  $c"
    }
    close_bd_design [current_bd_design]
    close_project
    exit 1
}

# 显示将要删除的内容
puts "\n=== Cell to delete ==="
puts "Name: $cell"
puts "VLNV: [get_property VLNV $cell]"

# 获取相关连接
puts "\nConnected nets that will be affected:"
foreach pin [get_bd_pins -of_objects $cell] {
    set net [get_bd_nets -quiet -of_objects $pin]
    if {$net ne ""} {
        puts "  $pin -> $net"
    }
}

foreach pin [get_bd_intf_pins -of_objects $cell] {
    set net [get_bd_intf_nets -quiet -of_objects $pin]
    if {$net ne ""} {
        puts "  $pin -> $net"
    }
}

# 删除实例
puts "\nDeleting cell..."
if {[catch {delete_bd_objs $cell} err]} {
    puts "ERROR: Failed to delete cell - $err"
    close_bd_design [current_bd_design]
    close_project
    exit 1
}

puts "Cell deleted successfully!"

# 验证设计
puts "\nValidating design..."
if {[catch {validate_bd_design} err]} {
    puts "WARNING: Design validation issues (expected after deletion): $err"
}

# 保存设计
puts "\nSaving design..."
save_bd_design

# 显示剩余的 cells
puts "\n=== Remaining cells ==="
foreach c [get_bd_cells] {
    puts "  $c"
}

close_bd_design [current_bd_design]
close_project
puts "\n============================================"
puts "Cell '$instance_name' deleted successfully!"
puts "============================================"
