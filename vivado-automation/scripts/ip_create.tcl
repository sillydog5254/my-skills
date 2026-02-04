# ip_create.tcl - 将 RTL 模块封装为可复用的 IP 核
# 用法: vivado -mode batch -source ip_create.tcl -tclargs <project.xpr> <top_module> <ip_name> [output_dir]
#
# 参数:
#   project.xpr - Vivado 项目文件
#   top_module  - 顶层模块名称
#   ip_name     - IP 核名称
#   output_dir  - 可选，IP 输出目录 (默认: ./ip_repo)

if {$argc < 3} {
    puts "Usage: vivado -mode batch -source ip_create.tcl -tclargs <project.xpr> <top_module> <ip_name> \[output_dir\]"
    puts ""
    puts "This script packages an existing RTL module as a reusable IP core."
    puts ""
    puts "Example:"
    puts "  vivado -mode batch -source ip_create.tcl -tclargs project.xpr MyModule my_ip_v1_0"
    exit 1
}

set proj_path [lindex $argv 0]
set top_module [lindex $argv 1]
set ip_name [lindex $argv 2]
set output_dir [expr {$argc > 3 ? [lindex $argv 3] : "./ip_repo"}]

puts "============================================"
puts "         CREATE IP FROM RTL MODULE"
puts "============================================"
puts "Project:    $proj_path"
puts "Top Module: $top_module"
puts "IP Name:    $ip_name"
puts "Output:     $output_dir"
puts "============================================"

# 打开项目
puts "\nOpening project..."
open_project $proj_path

# 更新编译顺序
update_compile_order -fileset sources_1

# 创建输出目录
file mkdir $output_dir
set ip_dir "$output_dir/$ip_name"

# 开始 IP 打包
puts "\nStarting IP packaging..."
ipx::package_project -root_dir $ip_dir -vendor xilinx.com -library user -taxonomy /UserIP -module $top_module -import_files -force

# 设置 IP 属性
puts "\nSetting IP properties..."
set core [ipx::current_core]

set_property NAME $ip_name $core
set_property DISPLAY_NAME $ip_name $core
set_property DESCRIPTION "Custom IP: $ip_name" $core
set_property VENDOR xilinx.com $core
set_property LIBRARY user $core
set_property VERSION 1.0 $core
set_property CORE_REVISION 1 $core

# 自动推断接口
puts "\nInferring interfaces..."

# 尝试推断 AXI 接口
if {[catch {ipx::infer_bus_interface -quiet clk xilinx.com:signal:clock_rtl:1.0 $core}]} {}
if {[catch {ipx::infer_bus_interface -quiet rst xilinx.com:signal:reset_rtl:1.0 $core}]} {}
if {[catch {ipx::infer_bus_interface -quiet resetn xilinx.com:signal:reset_rtl:1.0 $core}]} {}

# 显示端口
puts "\n=== IP Ports ==="
foreach port [ipx::get_ports -of_objects $core] {
    set name [get_property NAME $port]
    set dir [get_property DIRECTION $port]
    set left [get_property LEFT $port]
    set right [get_property RIGHT $port]
    if {$left ne "" && $left != $right} {
        puts "  $name \[$left:$right\] ($dir)"
    } else {
        puts "  $name ($dir)"
    }
}

# 显示接口
puts "\n=== IP Interfaces ==="
foreach intf [ipx::get_bus_interfaces -of_objects $core] {
    set name [get_property NAME $intf]
    set type [get_property ABSTRACTION_TYPE_VLNV $intf]
    puts "  $name: $type"
}

# 生成文件
puts "\nGenerating IP files..."
ipx::create_xgui_files $core
ipx::update_checksums $core
ipx::save_core $core

puts "\n=== IP Created ==="
puts "Location: $ip_dir"
puts "VLNV: [get_property VLNV $core]"

# 添加到项目的 IP 仓库
puts "\nAdding to project IP repository..."
set current_repo [get_property IP_REPO_PATHS [current_project]]
if {[lsearch -exact $current_repo $output_dir] == -1} {
    set_property IP_REPO_PATHS [concat $current_repo $output_dir] [current_project]
}
update_ip_catalog

close_project
puts "\n============================================"
puts "IP '$ip_name' created successfully!"
puts "============================================"
puts ""
puts "To use this IP in Block Design:"
puts "  1. The IP repository is automatically added to the project"
puts "  2. Use bd_add_ip.tcl with VLNV: xilinx.com:user:${ip_name}:1.0"
