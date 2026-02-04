# jtag_detect.tcl - JTAG 设备检测
# 用法: xsct jtag_detect.tcl
#
# 注意: 使用 D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat 运行

puts ""
puts "=============================================="
puts "         JTAG DEVICE DETECTION"
puts "=============================================="
puts ""

# 尝试连接
puts "Connecting to hw_server..."
if {[catch {connect} result]} {
    puts "ERROR: Failed to connect to hw_server."
    puts "       Start hw_server first:"
    puts "       \"D:/Program-Files/Xilinx/SDK/2019.1/bin/hw_server.bat\""
    exit 1
}

puts "Connected successfully."
puts ""

# 列出所有目标
puts "----------------------------------------------"
puts "AVAILABLE TARGETS"
puts "----------------------------------------------"
set target_list [targets]
puts ""

# 获取更详细的目标信息
puts "----------------------------------------------"
puts "TARGET DETAILS"
puts "----------------------------------------------"

# 遍历目标并获取详细信息
set target_count 0
foreach line [split $target_list "\n"] {
    if {[regexp {^\s*(\d+)\s+(.+)} $line -> id name]} {
        incr target_count
        puts ""
        puts "Target #$id: $name"

        # 尝试选择目标并获取更多信息
        if {[catch {targets -set -nocontext $id} err]} {
            puts "  (Cannot select - may require configuration)"
        } else {
            # 尝试获取状态
            if {[catch {targets -status} status]} {
                puts "  Status: Unknown"
            }
        }
    }
}

puts ""
puts "----------------------------------------------"
puts "JTAG CHAIN"
puts "----------------------------------------------"

# 获取 JTAG 设备列表
if {[catch {jtag targets} jtag_result]} {
    puts "No JTAG devices detected or JTAG not accessible."
} else {
    puts $jtag_result
}

puts ""
puts "----------------------------------------------"
puts "SUMMARY"
puts "----------------------------------------------"
puts "Total targets: $target_count"

# 检查 Zynq 设备
set zynq_found 0
foreach line [split $target_list "\n"] {
    if {[string match "*xc7z*" $line] || [string match "*ARM*" $line]} {
        set zynq_found 1
    }
}

if {$zynq_found} {
    puts "Zynq device: DETECTED"
} else {
    puts "Zynq device: NOT DETECTED"
    puts ""
    puts "Troubleshooting:"
    puts "  1. Check JTAG cable connection"
    puts "  2. Ensure board is powered on"
    puts "  3. Check driver installation (Digilent/Xilinx Cable)"
}

puts ""
disconnect
