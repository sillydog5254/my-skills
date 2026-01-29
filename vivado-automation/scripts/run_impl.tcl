# run_impl.tcl - 运行实现（布局布线）
# 用法: vivado -mode batch -source run_impl.tcl -tclargs <project.xpr> [run_name] [jobs]

if {$argc < 1} {
    puts "Usage: vivado -mode batch -source run_impl.tcl -tclargs <project.xpr> \[run_name\] \[jobs\]"
    exit 1
}

set proj_path [lindex $argv 0]
set run_name [expr {$argc > 1 ? [lindex $argv 1] : "impl_1"}]
set jobs [expr {$argc > 2 ? [lindex $argv 2] : 4}]

puts "Opening project: $proj_path"
open_project $proj_path

puts "Resetting implementation run: $run_name"
reset_run $run_name

puts "Launching implementation with $jobs jobs..."
launch_runs $run_name -jobs $jobs

puts "Waiting for implementation to complete..."
wait_on_run $run_name

set status [get_property STATUS [get_runs $run_name]]
puts "\n========== Implementation Complete =========="
puts "Status: $status"

if {[string match "*Complete*" $status]} {
    puts "Implementation succeeded!"
    set run_dir [get_property DIRECTORY [get_runs $run_name]]
    puts "Reports in: $run_dir"
} else {
    puts "Implementation failed or incomplete."
    exit 1
}

close_project
