# export_hardware.tcl - 从 Vivado 项目导出硬件定义 (HDF)
# 用法 (Vivado TCL): vivado -mode batch -source export_hardware.tcl -tclargs <project.xpr> [output_dir]
#
# 注意: 此脚本使用 Vivado (非 XSCT) 因为需要访问项目

if {$argc < 1} {
    # 尝试自动检测 .xpr 文件
    set xpr_files [glob -nocomplain *.xpr]
    if {[llength $xpr_files] > 0} {
        set proj_path [lindex $xpr_files 0]
        puts "Auto-detected project: $proj_path"
    } else {
        set xpr_files [glob -nocomplain project/*.xpr]
        if {[llength $xpr_files] > 0} {
            set proj_path [lindex $xpr_files 0]
            puts "Auto-detected project: $proj_path"
        } else {
            puts "Usage: vivado -mode batch -source export_hardware.tcl -tclargs <project.xpr> \[output_dir\]"
            puts "No .xpr file found in current directory."
            exit 1
        }
    }
} else {
    set proj_path [lindex $argv 0]
}

# 输出目录
if {$argc >= 2} {
    set output_dir [lindex $argv 1]
} else {
    # 默认在项目同级目录创建 .sdk 目录
    set proj_dir [file dirname $proj_path]
    set proj_name [file rootname [file tail $proj_path]]
    set output_dir "${proj_dir}/${proj_name}.sdk"
}

# 确保输出目录存在
file mkdir $output_dir

puts ""
puts "=============================================="
puts "       EXPORT HARDWARE DEFINITION"
puts "=============================================="
puts "Project:    $proj_path"
puts "Output dir: $output_dir"
puts ""

# 打开项目
puts "Opening project..."
open_project $proj_path

# 检查实现是否完成
set impl_runs [get_runs -filter {IS_IMPLEMENTATION}]
set impl_complete 0

foreach run $impl_runs {
    set status [get_property STATUS $run]
    if {[string match "*Complete*" $status] || [string match "*routed*" $status]} {
        set impl_complete 1
        puts "Found completed implementation: $run"
        break
    }
}

if {!$impl_complete} {
    puts "WARNING: No completed implementation found."
    puts "Exporting hardware without bitstream..."
}

# 获取顶层设计名称
set top_name [get_property TOP [current_fileset]]
puts "Top module: $top_name"

# 导出硬件
set hdf_file "${output_dir}/${top_name}.hdf"

puts ""
puts "Exporting hardware definition..."

if {$impl_complete} {
    # 包含比特流
    puts "  Including bitstream..."
    write_hwdef -force -include_bit -file $hdf_file
} else {
    # 不包含比特流
    write_hwdef -force -file $hdf_file
}

puts ""
puts "=============================================="
puts "Hardware exported successfully!"
puts "HDF file: $hdf_file"
puts "=============================================="
puts ""
puts "Next steps:"
puts "  1. Create hardware platform in SDK:"
puts "     xsct create_hw_platform.tcl $hdf_file"
puts "  2. Create BSP:"
puts "     xsct create_bsp.tcl $hdf_file"

close_project
