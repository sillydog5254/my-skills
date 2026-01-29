# bd_list_ips.tcl - 详细列出BD中所有IP实例及其配置
# 用法: vivado -mode batch -source bd_list_ips.tcl -tclargs <project.xpr> [bd_name]

if {$argc < 1} {
    puts "Usage: vivado -mode batch -source bd_list_ips.tcl -tclargs <project.xpr> \[bd_name\]"
    exit 1
}

set proj_path [lindex $argv 0]
set bd_name [expr {$argc > 1 ? [lindex $argv 1] : ""}]

puts "Opening project: $proj_path"
open_project $proj_path

# 获取BD文件
if {$bd_name eq ""} {
    set bd_files [get_files *.bd]
    set bd_file [lindex $bd_files 0]
} else {
    set bd_file [get_files *$bd_name.bd]
}

if {$bd_file eq ""} {
    puts "No Block Design found."
    close_project
    exit 1
}

open_bd_design $bd_file

puts "\n=========================================="
puts "IP Instances in BD"
puts "==========================================\n"

set cells [get_bd_cells -quiet]
set idx 1

foreach cell $cells {
    set vlnv [get_property VLNV $cell]
    set name [get_property NAME $cell]

    puts "[$idx] $name"
    puts "    VLNV: $vlnv"

    # 获取关键CONFIG参数
    set config_props [list_property $cell CONFIG.*]
    if {[llength $config_props] > 0} {
        puts "    Key configs:"
        foreach prop [lrange $config_props 0 9] {
            set value [get_property $prop $cell]
            if {$value ne ""} {
                puts "      $prop = $value"
            }
        }
        if {[llength $config_props] > 10} {
            puts "      ... ([expr {[llength $config_props] - 10}] more)"
        }
    }

    # 获取接口引脚
    set intf_pins [get_bd_intf_pins -of_objects $cell -quiet]
    if {[llength $intf_pins] > 0} {
        puts "    Interfaces: [join $intf_pins {, }]"
    }

    puts ""
    incr idx
}

puts "Total: [llength $cells] IP instances"

close_bd_design [current_bd_design]
close_project
