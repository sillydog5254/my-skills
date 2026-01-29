# bd_validate.tcl - 验证BD设计并生成输出产品
# 用法: vivado -mode batch -source bd_validate.tcl -tclargs <project.xpr> [bd_name] [generate_wrapper]

if {$argc < 1} {
    puts "Usage: vivado -mode batch -source bd_validate.tcl -tclargs <project.xpr> \[bd_name\] \[generate_wrapper:0|1\]"
    exit 1
}

set proj_path [lindex $argv 0]
set bd_name [expr {$argc > 1 ? [lindex $argv 1] : ""}]
set gen_wrapper [expr {$argc > 2 ? [lindex $argv 2] : 1}]

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

puts "\n=== Validating Design ==="
set validation_result [validate_bd_design -force]
if {$validation_result eq ""} {
    puts "Validation PASSED"
} else {
    puts "Validation issues:"
    puts $validation_result
}

puts "\n=== Generating Targets ==="
generate_target all $bd_file
puts "Targets generated successfully"

if {$gen_wrapper} {
    puts "\n=== Generating HDL Wrapper ==="
    make_wrapper -files $bd_file -top
    puts "Wrapper generated"
}

puts "\n=== Saving Design ==="
save_bd_design

close_bd_design [current_bd_design]
close_project
puts "\nDone."
