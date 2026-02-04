# run_xsim_direct.tcl - 直接使用 XSim 运行仿真（绕过 launch_simulation 的管道问题）
# 用法: vivado -mode batch -source run_xsim_direct.tcl -tclargs <project.xpr> [testbench_name] [sim_time]
#
# 这个脚本通过以下步骤运行仿真:
# 1. 打开项目，生成仿真脚本
# 2. 关闭 Vivado
# 3. 直接调用 compile.bat, elaborate.bat, simulate.bat
#
# 这种方法避免了 launch_simulation 在批处理模式下的 "Broken pipe" 问题

if {$argc < 1} {
    puts "============================================"
    puts "     XSIM DIRECT SIMULATION"
    puts "============================================"
    puts ""
    puts "Usage: vivado -mode batch -source run_xsim_direct.tcl -tclargs <project.xpr> \[testbench\] \[sim_time\]"
    puts ""
    puts "This script generates simulation scripts and runs XSim directly."
    puts "It avoids the 'Broken pipe' issue with launch_simulation in batch mode."
    puts ""
    puts "Examples:"
    puts "  vivado -mode batch -source run_xsim_direct.tcl -tclargs project.xpr"
    puts "  vivado -mode batch -source run_xsim_direct.tcl -tclargs project.xpr tb_MyModule"
    puts "  vivado -mode batch -source run_xsim_direct.tcl -tclargs project.xpr tb_MyModule 1000ns"
    exit 1
}

set proj_path [lindex $argv 0]
set tb_name ""
set sim_time "all"

if {$argc > 1} {
    set tb_name [lindex $argv 1]
}
if {$argc > 2} {
    set sim_time [lindex $argv 2]
}

puts "============================================"
puts "     XSIM DIRECT SIMULATION"
puts "============================================"
puts "Project:   $proj_path"
if {$tb_name ne ""} {
    puts "Testbench: $tb_name"
} else {
    puts "Testbench: (project default)"
}
puts "Sim Time:  $sim_time"
puts "============================================"

# 打开项目
puts "\nOpening project..."
open_project $proj_path

# 获取项目目录
set proj_dir [get_property DIRECTORY [current_project]]

# 检查 IP 状态
puts "\n=== IP Status ==="
set ips [get_ips -quiet]
puts "Found [llength $ips] IP(s) in project"

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

# 获取实际的 top 模块名
set sim_top [get_property top [get_filesets sim_1]]
puts "Top module: $sim_top"

# 设置仿真运行时间
if {$sim_time ne "" && $sim_time ne "all"} {
    puts "Setting simulation runtime: $sim_time"
    set_property -name {xsim.simulate.runtime} -value $sim_time -objects [get_filesets sim_1]
} else {
    # 对于 "run all"，我们需要设置一个特殊的值或保持默认
    set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]
}

# 生成仿真脚本（但不运行）
puts "\n=== Generating Simulation Scripts ==="
puts "Exporting simulation scripts..."

# 使用 export_simulation 生成脚本
set sim_dir "${proj_dir}/[get_property NAME [current_project]].sim/sim_1/behav/xsim"

# 先确保 IP 的仿真模型已经生成
puts "\nGenerating IP simulation targets..."
foreach ip $ips {
    set ip_name [get_property NAME $ip]
    # 跳过 Block Design 中的 IP
    if {[string match "AlohaHE_*" $ip_name]} {
        continue
    }
    puts "  Checking IP: $ip_name"
    set ip_file [get_files -quiet "${ip_name}.xci"]
    if {$ip_file ne ""} {
        generate_target simulation [get_files $ip_file] -quiet
    }
}

# 使用 export_simulation 来生成脚本文件
puts "\nExporting simulation..."
export_simulation -simulator xsim -directory $sim_dir -force

puts "\n=== Simulation Scripts Generated ==="
puts "Directory: $sim_dir"

# 输出批处理脚本的路径
set compile_bat "${sim_dir}/compile.bat"
set elaborate_bat "${sim_dir}/elaborate.bat"
set simulate_bat "${sim_dir}/simulate.bat"

puts "\nGenerated scripts:"
puts "  Compile:   $compile_bat"
puts "  Elaborate: $elaborate_bat"
puts "  Simulate:  $simulate_bat"

# 关闭项目
close_project

puts "\n============================================"
puts "Simulation scripts have been generated."
puts ""
puts "To run the simulation manually, execute:"
puts "  cd $sim_dir"
puts "  compile.bat && elaborate.bat && simulate.bat"
puts ""
puts "Or use the companion batch script:"
puts "  run_xsim.bat $proj_path $sim_top"
puts "============================================"
