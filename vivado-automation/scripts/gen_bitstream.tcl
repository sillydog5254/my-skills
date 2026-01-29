# gen_bitstream.tcl - 生成比特流
# 用法: vivado -mode batch -source gen_bitstream.tcl -tclargs <project.xpr> [impl_run]

if {$argc < 1} {
    puts "Usage: vivado -mode batch -source gen_bitstream.tcl -tclargs <project.xpr> \[impl_run\]"
    exit 1
}

set proj_path [lindex $argv 0]
set impl_run [expr {$argc > 1 ? [lindex $argv 1] : "impl_1"}]

puts "Opening project: $proj_path"
open_project $proj_path

# 检查实现是否完成
set impl_status [get_property STATUS [get_runs $impl_run]]
if {![string match "*route_design Complete*" $impl_status] && ![string match "*write_bitstream Complete*" $impl_status]} {
    puts "Implementation run '$impl_run' is not complete: $impl_status"
    puts "Run implementation first."
    close_project
    exit 1
}

puts "Launching bitstream generation..."
launch_runs $impl_run -to_step write_bitstream -jobs 4
wait_on_run $impl_run

set status [get_property STATUS [get_runs $impl_run]]
puts "\n========== Bitstream Generation Complete =========="
puts "Status: $status"

if {[string match "*write_bitstream Complete*" $status]} {
    set run_dir [get_property DIRECTORY [get_runs $impl_run]]
    puts "Bitstream file: $run_dir/*.bit"
} else {
    puts "Bitstream generation failed."
    exit 1
}

close_project
