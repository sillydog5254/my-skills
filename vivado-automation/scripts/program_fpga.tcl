# program_fpga.tcl - 通过 JTAG 烧录 FPGA
# 用法: vivado -mode batch -source program_fpga.tcl -tclargs [bitstream.bit] [probe.ltx]
#
# 如果未指定比特流文件，将自动搜索 impl_1 目录下的 .bit 文件

# 自动检测比特流文件
proc find_bitstream {} {
    # 搜索顺序：当前目录 -> project/*/runs/impl_1 -> */runs/impl_1
    set search_patterns [list \
        "*.bit" \
        "project/*.runs/impl_1/*.bit" \
        "*/*.runs/impl_1/*.bit" \
        "*.runs/impl_1/*.bit" \
        "project/*.sdk/*/*.bit" \
    ]

    foreach pattern $search_patterns {
        set files [glob -nocomplain $pattern]
        if {[llength $files] > 0} {
            # 返回最新修改的文件
            set latest ""
            set latest_time 0
            foreach f $files {
                set mtime [file mtime $f]
                if {$mtime > $latest_time} {
                    set latest $f
                    set latest_time $mtime
                }
            }
            return $latest
        }
    }
    return ""
}

# 解析参数
if {$argc >= 1} {
    set bit_file [lindex $argv 0]
} else {
    set bit_file [find_bitstream]
    if {$bit_file eq ""} {
        puts "ERROR: No bitstream file specified and none found automatically."
        puts "Usage: vivado -mode batch -source program_fpga.tcl -tclargs <bitstream.bit> \[probe.ltx\]"
        exit 1
    }
    puts "Auto-detected bitstream: $bit_file"
}

# 可选的探针文件
set ltx_file ""
if {$argc >= 2} {
    set ltx_file [lindex $argv 1]
} else {
    # 尝试在同目录找 .ltx 文件
    set ltx_pattern "[file rootname $bit_file].ltx"
    if {[file exists $ltx_pattern]} {
        set ltx_file $ltx_pattern
        puts "Auto-detected probe file: $ltx_file"
    }
}

# 检查文件存在
if {![file exists $bit_file]} {
    puts "ERROR: Bitstream file not found: $bit_file"
    exit 1
}

puts ""
puts "=============================================="
puts "         FPGA PROGRAMMING"
puts "=============================================="
puts "Bitstream: $bit_file"
if {$ltx_file ne ""} {
    puts "Probe file: $ltx_file"
}
puts ""

# 打开硬件管理器 (Vivado 2019.1 使用 open_hw)
puts "Opening Hardware Manager..."
open_hw

# 连接到硬件服务器
puts "Connecting to hw_server..."
if {[catch {connect_hw_server -allow_non_jtag} result]} {
    puts "WARNING: Could not connect with -allow_non_jtag, trying without..."
    if {[catch {connect_hw_server} result2]} {
        puts "ERROR: Failed to connect to hw_server."
        puts "       Make sure JTAG is connected."
        puts "       Error: $result2"
        close_hw
        exit 1
    }
}

# 获取硬件目标
puts "Scanning for hardware targets..."
set hw_targets [get_hw_targets]
if {[llength $hw_targets] == 0} {
    puts "ERROR: No hardware targets found."
    puts "       Check JTAG connection."
    disconnect_hw_server
    close_hw
    exit 1
}

puts "Found [llength $hw_targets] target(s):"
foreach t $hw_targets {
    puts "  - $t"
}

# 打开第一个目标
set target [lindex $hw_targets 0]
puts ""
puts "Opening target: $target"
open_hw_target $target

# 获取设备
set hw_devices [get_hw_devices]
if {[llength $hw_devices] == 0} {
    puts "ERROR: No devices found on target."
    close_hw_target
    disconnect_hw_server
    close_hw
    exit 1
}

puts "Found [llength $hw_devices] device(s):"
foreach d $hw_devices {
    puts "  - $d"
}

# 选择 FPGA 设备（通常是第一个，或者找 xc7z 开头的）
set fpga_device ""
foreach d $hw_devices {
    if {[string match "*xc7z*" $d] || [string match "*xc7*" $d]} {
        set fpga_device $d
        break
    }
}
if {$fpga_device eq ""} {
    set fpga_device [lindex $hw_devices 0]
}

puts ""
puts "Selected device: $fpga_device"
current_hw_device $fpga_device

# 设置比特流文件
set_property PROGRAM.FILE $bit_file [current_hw_device]

# 设置探针文件（如果有）
if {$ltx_file ne "" && [file exists $ltx_file]} {
    set_property PROBES.FILE $ltx_file [current_hw_device]
}

# 编程设备
puts ""
puts "Programming device..."
if {[catch {program_hw_devices [current_hw_device]} result]} {
    puts "ERROR: Programming failed!"
    puts "       $result"
    close_hw_target
    disconnect_hw_server
    close_hw
    exit 1
}

# 刷新状态
refresh_hw_device [current_hw_device]

puts ""
puts "=============================================="
puts "FPGA programmed successfully!"
puts "=============================================="

# 清理
close_hw_target
disconnect_hw_server
close_hw
