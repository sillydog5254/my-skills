# run_synth.tcl - 运行综合
# 用法: vivado -mode batch -source run_synth.tcl -tclargs <project.xpr> [run_name] [jobs]

if {$argc < 1} {
    puts "Usage: vivado -mode batch -source run_synth.tcl -tclargs <project.xpr> \[run_name\] \[jobs\]"
    exit 1
}

set proj_path [lindex $argv 0]
set run_name [expr {$argc > 1 ? [lindex $argv 1] : "synth_1"}]
set jobs [expr {$argc > 2 ? [lindex $argv 2] : 4}]

puts "Opening project: $proj_path"
open_project $proj_path

puts "Resetting synthesis run: $run_name"
reset_run $run_name

puts "Launching synthesis with $jobs jobs..."
launch_runs $run_name -jobs $jobs

puts "Waiting for synthesis to complete..."
wait_on_run $run_name

set status [get_property STATUS [get_runs $run_name]]
puts "\n========== Synthesis Complete =========="
puts "Status: $status"

if {[string match "*Complete*" $status]} {
    puts "Synthesis succeeded!"
    # 生成利用率报告路径
    set run_dir [get_property DIRECTORY [get_runs $run_name]]
    puts "Reports in: $run_dir"
} else {
    puts "Synthesis failed or incomplete."
    exit 1
}

close_project
