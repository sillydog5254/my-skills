# create_bsp.tcl - 创建 BSP (Board Support Package)
# 用法: xsct create_bsp.tcl <hdf_file> [workspace] [bsp_name] [processor]
#
# 注意: 使用 D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat 运行

proc find_hdf {} {
    set search_patterns [list "*.hdf" "*.sdk/*.hdf" "project/*.sdk/*.hdf"]
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
        puts "Usage: xsct create_bsp.tcl <hdf_file> \[workspace\] \[bsp_name\] \[processor\]"
        exit 1
    }
    puts "Auto-detected HDF: $hdf_file"
} else {
    set hdf_file [lindex $argv 0]
}

set workspace [expr {[llength $argv] >= 2 ? [lindex $argv 1] : [file dirname $hdf_file]}]
set bsp_name [expr {[llength $argv] >= 3 ? [lindex $argv 2] : "standalone_bsp"}]
set processor [expr {[llength $argv] >= 4 ? [lindex $argv 3] : "ps7_cortexa9_0"}]

# 硬件平台名称
set hw_name "[file rootname [file tail $hdf_file]]_hw_platform"

puts ""
puts "=============================================="
puts "         CREATE BSP"
puts "=============================================="
puts "HDF file:   $hdf_file"
puts "Workspace:  $workspace"
puts "BSP name:   $bsp_name"
puts "Processor:  $processor"
puts "HW platform: $hw_name"
puts ""

# 设置工作区
puts "Setting workspace..."
setws $workspace

# 检查硬件平台是否存在
if {[catch {getprojects} existing_projects]} {
    set existing_projects {}
}

if {[lsearch -exact $existing_projects $hw_name] < 0} {
    puts "Creating hardware platform first..."
    createhw -name $hw_name -hwspec $hdf_file
}

# 检查 BSP 是否已存在
if {[lsearch -exact $existing_projects $bsp_name] >= 0} {
    puts "BSP '$bsp_name' already exists. Deleting and recreating..."
    deleteprojects -name $bsp_name
}

# 创建 BSP
puts "Creating BSP..."
createbsp -name $bsp_name -hwproject $hw_name -proc $processor -os standalone

# 配置 BSP
puts "Configuring BSP..."

# 配置 UART stdin/stdout (尝试常见的 UART 名称)
set uart_names [list "ps7_uart_0" "ps7_uart_1" "axi_uartlite_0"]
foreach uart $uart_names {
    if {[catch {configbsp -bsp $bsp_name stdin $uart} result] == 0} {
        puts "  stdin  -> $uart"
        break
    }
}
foreach uart $uart_names {
    if {[catch {configbsp -bsp $bsp_name stdout $uart} result] == 0} {
        puts "  stdout -> $uart"
        break
    }
}

# 构建 BSP
puts ""
puts "Building BSP..."
projects -build -type bsp -name $bsp_name

puts ""
puts "=============================================="
puts "BSP created successfully!"
puts "=============================================="
puts ""
puts "Available libraries:"
getlibs -bsp $bsp_name

puts ""
puts "Next step - Create application:"
puts "  xsct create_app.tcl $workspace $bsp_name <app_name>"
