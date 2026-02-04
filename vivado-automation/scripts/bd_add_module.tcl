# bd_add_module.tcl - 向 Block Design 添加自定义 RTL 模块
# 用法: vivado -mode batch -source bd_add_module.tcl -tclargs <project.xpr> <module_name> <instance_name> [bd_name]
#
# 参数:
#   project.xpr   - Vivado 项目文件
#   module_name   - 项目中已有的 RTL 模块名称
#   instance_name - 实例名称
#   bd_name       - 可选，Block Design 名称

if {$argc < 3} {
    puts "Usage: vivado -mode batch -source bd_add_module.tcl -tclargs <project.xpr> <module_name> <instance_name> \[bd_name\]"
    puts ""
    puts "This adds an existing RTL module from the project sources to the Block Design."
    puts "The module must already be part of the project sources."
    puts ""
    puts "Example:"
    puts "  vivado -mode batch -source bd_add_module.tcl -tclargs project.xpr MyCustomIP my_custom_0"
    exit 1
}

set proj_path [lindex $argv 0]
set module_name [lindex $argv 1]
set instance_name [lindex $argv 2]
set bd_name [expr {$argc > 3 ? [lindex $argv 3] : ""}]

puts "============================================"
puts "    ADD RTL MODULE TO BLOCK DESIGN"
puts "============================================"
puts "Project:  $proj_path"
puts "Module:   $module_name"
puts "Instance: $instance_name"
puts "============================================"

# 打开项目
puts "\nOpening project..."
open_project $proj_path

# 检查模块是否存在
puts "\nChecking if module exists in project..."
update_compile_order -fileset sources_1

# 获取所有模块
set all_modules [get_files -filter {FILE_TYPE == "Verilog" || FILE_TYPE == "SystemVerilog" || FILE_TYPE == "VHDL"}]
puts "Source files in project: [llength $all_modules]"

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

# 添加模块
puts "\nAdding module: $module_name as $instance_name..."
if {[catch {create_bd_cell -type module -reference $module_name $instance_name} result]} {
    puts "ERROR: Failed to add module - $result"
    puts ""
    puts "Make sure the module '$module_name' exists in the project sources."
    puts "You can add source files with: add_files -norecurse <path_to_file>"
    close_bd_design [current_bd_design]
    close_project
    exit 1
}

puts "Module added successfully!"

# 显示模块端口
puts "\n=== Module Ports ==="
set cell [get_bd_cells $instance_name]

puts "\nInterface Pins:"
foreach pin [get_bd_intf_pins -quiet -of_objects $cell] {
    set mode [get_property MODE $pin]
    puts "  $pin ($mode)"
}

puts "\nSignal Pins:"
set pins [get_bd_pins -of_objects $cell]
foreach pin $pins {
    set dir [get_property DIR $pin]
    set left [get_property LEFT $pin]
    set right [get_property RIGHT $pin]
    if {$left ne "" && $left != $right} {
        puts "  $pin \[$left:$right\] ($dir)"
    } else {
        puts "  $pin ($dir)"
    }
}

# 保存设计
puts "\nSaving design..."
save_bd_design

close_bd_design [current_bd_design]
close_project
puts "\n============================================"
puts "Module '$instance_name' added successfully!"
puts "============================================"
