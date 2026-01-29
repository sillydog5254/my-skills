# get_status.tcl - 查询Vivado项目状态
# 用法: vivado -mode batch -source get_status.tcl -tclargs <project.xpr>

if {$argc < 1} {
    puts "Usage: vivado -mode batch -source get_status.tcl -tclargs <project.xpr>"
    exit 1
}

set proj_path [lindex $argv 0]

puts "Opening project: $proj_path"
open_project $proj_path

puts "\n========== Project Info =========="
puts "Name: [get_property NAME [current_project]]"
puts "Directory: [get_property DIRECTORY [current_project]]"
puts "Part: [get_property PART [current_project]]"

puts "\n========== Synthesis Runs =========="
foreach run [get_runs -filter {IS_SYNTHESIS == 1}] {
    set status [get_property STATUS $run]
    set progress [get_property PROGRESS $run]
    puts "$run: $status ($progress)"
}

puts "\n========== Implementation Runs =========="
foreach run [get_runs -filter {IS_IMPLEMENTATION == 1}] {
    set status [get_property STATUS $run]
    set progress [get_property PROGRESS $run]
    puts "$run: $status ($progress)"
}

puts "\n========== Source Summary =========="
puts "Verilog/SV files: [llength [get_files -filter {FILE_TYPE =~ *Verilog* || FILE_TYPE == SystemVerilog}]]"
puts "Constraint files: [llength [get_files -filter {FILE_TYPE == XDC}]]"

close_project
