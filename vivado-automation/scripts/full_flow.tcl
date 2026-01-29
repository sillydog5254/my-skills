# full_flow.tcl - 完整构建流程（综合→实现→比特流）
# 用法: vivado -mode batch -source full_flow.tcl -tclargs <project.xpr> [synth_run] [impl_run] [jobs]

if {$argc < 1} {
    puts "Usage: vivado -mode batch -source full_flow.tcl -tclargs <project.xpr> \[synth_run\] \[impl_run\] \[jobs\]"
    exit 1
}

set proj_path [lindex $argv 0]
set synth_run [expr {$argc > 1 ? [lindex $argv 1] : "synth_1"}]
set impl_run [expr {$argc > 2 ? [lindex $argv 2] : "impl_1"}]
set jobs [expr {$argc > 3 ? [lindex $argv 3] : 4}]

puts "=========================================="
puts "Full Build Flow"
puts "Project: $proj_path"
puts "Synth: $synth_run, Impl: $impl_run, Jobs: $jobs"
puts "==========================================\n"

open_project $proj_path

# 综合
puts ">>> Step 1: Synthesis"
reset_run $synth_run
launch_runs $synth_run -jobs $jobs
wait_on_run $synth_run

set synth_status [get_property STATUS [get_runs $synth_run]]
puts "Synthesis status: $synth_status"
if {![string match "*Complete*" $synth_status]} {
    puts "ERROR: Synthesis failed!"
    close_project
    exit 1
}

# 实现
puts "\n>>> Step 2: Implementation"
reset_run $impl_run
launch_runs $impl_run -jobs $jobs
wait_on_run $impl_run

set impl_status [get_property STATUS [get_runs $impl_run]]
puts "Implementation status: $impl_status"
if {![string match "*Complete*" $impl_status]} {
    puts "ERROR: Implementation failed!"
    close_project
    exit 1
}

# 比特流
puts "\n>>> Step 3: Bitstream"
launch_runs $impl_run -to_step write_bitstream -jobs $jobs
wait_on_run $impl_run

set final_status [get_property STATUS [get_runs $impl_run]]
puts "\n=========================================="
puts "Build Complete!"
puts "Final status: $final_status"

set run_dir [get_property DIRECTORY [get_runs $impl_run]]
puts "Output directory: $run_dir"
puts "==========================================\n"

close_project
