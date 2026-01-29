# bd_info.tcl - 查看Block Design设计信息
# 用法: vivado -mode batch -source bd_info.tcl -tclargs <project.xpr> [bd_name]

if {$argc < 1} {
    puts "Usage: vivado -mode batch -source bd_info.tcl -tclargs <project.xpr> \[bd_name\]"
    exit 1
}

set proj_path [lindex $argv 0]
set bd_name [expr {$argc > 1 ? [lindex $argv 1] : ""}]

puts "Opening project: $proj_path"
open_project $proj_path

# 获取BD文件
if {$bd_name eq ""} {
    set bd_files [get_files *.bd]
} else {
    set bd_files [get_files *$bd_name.bd]
}

if {[llength $bd_files] == 0} {
    puts "No Block Design found in project."
    close_project
    exit 1
}

foreach bd_file $bd_files {
    puts "\n=========================================="
    puts "Block Design: $bd_file"
    puts "==========================================\n"

    open_bd_design $bd_file

    puts "=== Design Info ==="
    puts "Name: [get_property NAME [current_bd_design]]"
    puts "Directory: [get_property DIRECTORY [current_bd_design]]"

    puts "\n=== IP Instances (Cells) ==="
    set cells [get_bd_cells -quiet]
    foreach cell $cells {
        set vlnv [get_property VLNV $cell]
        puts "  $cell"
        puts "    VLNV: $vlnv"
    }
    puts "Total cells: [llength $cells]"

    puts "\n=== Interface Ports ==="
    set intf_ports [get_bd_intf_ports -quiet]
    foreach port $intf_ports {
        set mode [get_property MODE $port]
        set vlnv [get_property VLNV $port]
        puts "  $port ($mode) - $vlnv"
    }

    puts "\n=== Regular Ports ==="
    set ports [get_bd_ports -quiet]
    foreach port $ports {
        set dir [get_property DIR $port]
        puts "  $port ($dir)"
    }

    puts "\n=== Interface Nets ==="
    puts "Count: [llength [get_bd_intf_nets -quiet]]"

    puts "\n=== Signal Nets ==="
    puts "Count: [llength [get_bd_nets -quiet]]"

    close_bd_design [current_bd_design]
}

close_project
puts "\nDone."
