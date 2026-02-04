# run_simulation.tcl - 运行项目仿真（支持 IP 依赖）
# 用法: vivado -mode batch -source run_simulation.tcl -tclargs <project.xpr> [testbench_name] [sim_time]
#
# 这个脚本支持：
# - 依赖 Xilinx IP 核的仿真（BRAM, FIFO, DSP, Block Design 等）
# - 自动处理 IP 仿真模型
# - 行为级仿真 (Behavioral)
#
# 参数:
#   project.xpr    - Vivado 项目文件
#   testbench_name - 可选，testbench 顶层模块名（默认使用项目设置）
#   sim_time       - 可选，仿真时间（如 "1000ns", "10us"）

if {$argc < 1} {
    puts "============================================"
    puts "     RUN SIMULATION WITH IP SUPPORT"
    puts "============================================"
    puts ""
    puts "Usage: vivado -mode batch -source run_simulation.tcl -tclargs <project.xpr> \[testbench\] \[sim_time\]"
    puts ""
    puts "This script supports testbenches that depend on Xilinx IPs."
    puts "It uses Vivado's launch_simulation which handles all IP dependencies."
    puts ""
    puts "Examples:"
    puts "  # Run default simulation"
    puts "  vivado -mode batch -source run_simulation.tcl -tclargs project.xpr"
    puts ""
    puts "  # Run specific testbench"
    puts "  vivado -mode batch -source run_simulation.tcl -tclargs project.xpr tb_MyModule"
    puts ""
    puts "  # Run with specific simulation time"
    puts "  vivado -mode batch -source run_simulation.tcl -tclargs project.xpr tb_MyModule 1000ns"
    exit 1
}

set proj_path [lindex $argv 0]
set tb_name ""
set sim_time ""

if {$argc > 1} {
    set tb_name [lindex $argv 1]
}
if {$argc > 2} {
    set sim_time [lindex $argv 2]
}

puts "============================================"
puts "     RUN SIMULATION WITH IP SUPPORT"
puts "============================================"
puts "Project:   $proj_path"
if {$tb_name ne ""} {
    puts "Testbench: $tb_name"
} else {
    puts "Testbench: (project default)"
}
if {$sim_time ne ""} {
    puts "Sim Time:  $sim_time"
} else {
    puts "Sim Time:  (run all)"
}
puts "============================================"

# 打开项目
puts "\nOpening project..."
open_project $proj_path

# 检查 IP 状态
puts "\n=== IP Status ==="
set ips [get_ips -quiet]
puts "Found [llength $ips] IP(s) in project"
if {[llength $ips] > 0} {
    puts "IPs:"
    foreach ip [lrange $ips 0 9] {
        puts "  - [get_property NAME $ip]"
    }
    if {[llength $ips] > 10} {
        puts "  ... ([expr {[llength $ips] - 10}] more)"
    }
}

# 更新编译顺序
puts "\nUpdating compile order..."
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# 设置 testbench（如果指定）
if {$tb_name ne ""} {
    puts "\nSetting top-level testbench: $tb_name"
    set_property top $tb_name [get_filesets sim_1]
    update_compile_order -fileset sim_1
}

# 显示当前仿真设置
puts "\n=== Simulation Settings ==="
set sim_top [get_property top [get_filesets sim_1]]
puts "Top module: $sim_top"
puts "Simulator:  [get_property target_simulator [current_project]]"

# 获取仿真文件
set sim_files [get_files -quiet -compile_order sources -used_in simulation]
puts "Sim files:  [llength $sim_files] files"

# 设置仿真运行时间
if {$sim_time ne ""} {
    puts "Setting simulation runtime: $sim_time"
    set_property -name {xsim.simulate.runtime} -value $sim_time -objects [get_filesets sim_1]
}

# 运行仿真
puts "\n=== Starting Simulation ==="
puts "Note: This will compile all sources including IP simulation models."
puts "This may take several minutes for designs with many IPs..."
puts ""

set start_time [clock seconds]

if {[catch {
    # launch_simulation 自动处理所有 IP 依赖
    launch_simulation -mode behavioral

    puts "\n=== Simulation Running ==="

    # 如果没有指定时间，运行到完成
    if {$sim_time eq ""} {
        puts "Running simulation to completion (or until \$finish)..."
        run -all
    }

    set end_time [clock seconds]
    set elapsed [expr {$end_time - $start_time}]

    puts "\n=== Simulation Complete ==="
    puts "Elapsed time: ${elapsed} seconds"

    # 关闭仿真
    close_sim

} err]} {
    puts "\n=== SIMULATION FAILED ==="
    puts "Error: $err"
    puts ""
    puts "Common causes and solutions:"
    puts "  1. Testbench syntax errors - check the testbench code"
    puts "  2. Missing module references - ensure all RTL files are in the project"
    puts "  3. IP not generated - right-click IP in Vivado and 'Generate Output Products'"
    puts "  4. Incorrect top module - verify testbench name matches"
    puts ""
    puts "For detailed errors, check:"
    puts "  project/*.sim/sim_1/behav/xsim/xvlog.log"
    puts "  project/*.sim/sim_1/behav/xsim/xelab.log"
    puts "  project/*.sim/sim_1/behav/xsim/xsim.log"

    close_project
    exit 1
}

close_project
puts "\nSimulation completed successfully."
puts "Done."
