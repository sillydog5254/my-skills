# create_hw_platform.tcl - 在 SDK 中创建硬件平台
# 用法: xsct create_hw_platform.tcl <hdf_file> [workspace]
#
# 注意: 使用 D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat 运行

proc find_hdf {} {
    # 搜索 HDF 文件
    set search_patterns [list \
        "*.hdf" \
        "*.sdk/*.hdf" \
        "project/*.sdk/*.hdf" \
    ]

    foreach pattern $search_patterns {
        set files [glob -nocomplain $pattern]
        if {[llength $files] > 0} {
            return [lindex $files 0]
        }
    }
    return ""
}

# 解析参数
if {[llength $argv] < 1} {
    set hdf_file [find_hdf]
    if {$hdf_file eq ""} {
        puts "Usage: xsct create_hw_platform.tcl <hdf_file> \[workspace\]"
        puts "No .hdf file found in current directory."
        exit 1
    }
    puts "Auto-detected HDF: $hdf_file"
} else {
    set hdf_file [lindex $argv 0]
}

# 工作区
if {[llength $argv] >= 2} {
    set workspace [lindex $argv 1]
} else {
    set workspace [file dirname $hdf_file]
}

# 硬件平台名称
set hw_name "[file rootname [file tail $hdf_file]]_hw_platform"

puts ""
puts "=============================================="
puts "      CREATE HARDWARE PLATFORM"
puts "=============================================="
puts "HDF file:  $hdf_file"
puts "Workspace: $workspace"
puts "HW name:   $hw_name"
puts ""

# 设置工作区
puts "Setting workspace..."
setws $workspace

# 检查是否已存在
if {[catch {getprojects} existing_projects]} {
    set existing_projects {}
}

if {[lsearch -exact $existing_projects $hw_name] >= 0} {
    puts "Hardware platform '$hw_name' already exists."
    puts "Updating with new HDF..."
    # 删除旧的并重新创建
    deleteprojects -name $hw_name
}

# 创建硬件平台
puts "Creating hardware platform..."
createhw -name $hw_name -hwspec $hdf_file

# 列出处理器
puts ""
puts "Available processors:"
set hw_design [hsi::open_hw_design $hdf_file]
set procs [hsi::get_cells -filter {IP_TYPE == PROCESSOR}]
foreach p $procs {
    puts "  - $p"
}
hsi::close_hw_design $hw_design

puts ""
puts "=============================================="
puts "Hardware platform created successfully!"
puts "=============================================="
puts ""
puts "Next step - Create BSP:"
puts "  xsct create_bsp.tcl $hdf_file $workspace"
