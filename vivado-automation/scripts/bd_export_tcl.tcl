# bd_export_tcl.tcl - 导出BD为可重建的TCL脚本
# 用法: vivado -mode batch -source bd_export_tcl.tcl -tclargs <project.xpr> <output.tcl> [bd_name]

if {$argc < 2} {
    puts "Usage: vivado -mode batch -source bd_export_tcl.tcl -tclargs <project.xpr> <output.tcl> \[bd_name\]"
    exit 1
}

set proj_path [lindex $argv 0]
set output_file [lindex $argv 1]
set bd_name [expr {$argc > 2 ? [lindex $argv 2] : ""}]

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

puts "Opening BD: $bd_file"
open_bd_design $bd_file

puts "\n=== Exporting to TCL ==="
write_bd_tcl -force $output_file
puts "Exported to: $output_file"

close_bd_design [current_bd_design]
close_project
puts "\nDone."
