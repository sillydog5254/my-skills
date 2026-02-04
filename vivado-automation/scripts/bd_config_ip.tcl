# bd_config_ip.tcl - 配置 Block Design 中 IP 的参数
# 用法: vivado -mode batch -source bd_config_ip.tcl -tclargs <project.xpr> <instance_name> <param1> <value1> [param2] [value2] ... [bd_name]
#
# 参数:
#   project.xpr   - Vivado 项目文件
#   instance_name - IP 实例名称
#   param/value   - 参数名和值的配对 (不需要 CONFIG. 前缀)
#   bd_name       - 可选，最后一个参数如果是 .bd 文件名

if {$argc < 4} {
    puts "Usage: vivado -mode batch -source bd_config_ip.tcl -tclargs <project.xpr> <instance_name> <param1> <value1> \[param2 value2 ...\]"
    puts ""
    puts "Parameters are passed in pairs: PARAM1 VALUE1 PARAM2 VALUE2 ..."
    puts ""
    puts "Examples:"
    puts "  # Configure constant with 8-bit width and value 255"
    puts "  vivado -mode batch -source bd_config_ip.tcl -tclargs project.xpr my_const CONST_WIDTH 8 CONST_VAL 255"
    puts ""
    puts "  # Configure AXI GPIO with 32-bit width"
    puts "  vivado -mode batch -source bd_config_ip.tcl -tclargs project.xpr my_gpio C_GPIO_WIDTH 32"
    exit 1
}

set proj_path [lindex $argv 0]
set instance_name [lindex $argv 1]

# 解析参数对
set config_list [list]
set bd_name ""
for {set i 2} {$i < $argc} {incr i 2} {
    set param [lindex $argv $i]
    set value [lindex $argv [expr {$i + 1}]]

    # 检查是否有值（奇数个参数的最后一个可能是 bd_name）
    if {$value eq "" || $i + 1 >= $argc} {
        # 最后一个单独的参数可能是 BD 名称
        set bd_name $param
        break
    }

    lappend config_list "CONFIG.$param" $value
}
set config_str [join $config_list " "]

puts "============================================"
puts "      CONFIGURE IP IN BLOCK DESIGN"
puts "============================================"
puts "Project:  $proj_path"
puts "Instance: $instance_name"
puts "Config:   $config_str"
puts "============================================"

if {[llength $config_list] == 0} {
    puts "ERROR: No valid configuration parameters found."
    puts "Usage: param1 value1 param2 value2 ..."
    exit 1
}

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

# 获取 IP 实例
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

puts "\n=== Current Configuration ==="
puts "Cell: $cell"
puts "VLNV: [get_property VLNV $cell]"

# 显示要修改的当前值
puts "\nParameters to modify:"
foreach {key val} $config_list {
    set current_val [get_property -quiet $key $cell]
    puts "  $key: $current_val -> $val"
}

# 应用配置
puts "\nApplying configuration..."
if {[catch {set_property -dict $config_list $cell} err]} {
    puts "ERROR: Failed to set properties - $err"
    puts ""
    puts "Available CONFIG parameters:"
    set config_props [list_property $cell CONFIG.*]
    foreach prop [lrange $config_props 0 30] {
        puts "  $prop = [get_property $prop $cell]"
    }
    if {[llength $config_props] > 30} {
        puts "  ... ([llength $config_props] total)"
    }
    close_bd_design [current_bd_design]
    close_project
    exit 1
}

# 验证新配置
puts "\n=== Updated Configuration ==="
foreach {key val} $config_list {
    set new_val [get_property $key $cell]
    puts "  $key = $new_val"
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
puts "Configuration applied successfully!"
puts "============================================"
