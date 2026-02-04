# fpga_status.tcl - 检查 FPGA 配置状态
# 用法: xsct fpga_status.tcl
#
# 注意: 使用 D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat 运行

puts ""
puts "=============================================="
puts "         FPGA STATUS CHECK"
puts "=============================================="
puts ""

# 连接
puts "Connecting to hw_server..."
if {[catch {connect} result]} {
    puts "ERROR: Failed to connect to hw_server."
    exit 1
}

puts "Connected."
puts ""

# 列出目标
puts "Available targets:"
targets
puts ""

# 尝试找到 FPGA/PL 目标
puts "----------------------------------------------"
puts "FPGA/PL STATUS"
puts "----------------------------------------------"

set fpga_found 0

# 尝试选择 xc7z 设备
if {[catch {targets -set -filter {name =~ "*xc7z*"}} result]} {
    # 尝试 arm_dap
    if {[catch {targets -set -filter {name =~ "*arm_dap*"}} result]} {
        puts "WARNING: Cannot find FPGA target."
    }
}

# 检查配置状态
puts ""
puts "Checking FPGA configuration..."

# 使用 jtag 命令检查 (如果可用)
if {[catch {
    # 尝试读取 FPGA 状态
    set done_status "Unknown"
    set init_status "Unknown"

    # 对于 Zynq，检查 PCFG_DONE 位
    # 地址 0xF8007014 是 SLCR PCFG_CTRL 寄存器
    targets -set -filter {name =~ "*ARM*#0"}

    if {[catch {set pcfg_done [mrd -value 0xF8007014]} err]} {
        puts "Cannot read FPGA status registers."
        puts "(FPGA may not be configured or processor not accessible)"
    } else {
        # 检查 PCFG_DONE_INT 位 (bit 2)
        if {[expr {$pcfg_done & 0x4}] != 0} {
            set done_status "CONFIGURED"
        } else {
            set done_status "NOT CONFIGURED"
        }
        puts "FPGA Status: $done_status"
    }
} err]} {
    puts "Cannot determine FPGA status: $err"
}

# PS 状态
puts ""
puts "----------------------------------------------"
puts "PS (ARM) STATUS"
puts "----------------------------------------------"

# 选择 ARM 核心
if {[catch {targets -set -filter {name =~ "*ARM*#0"}} result]} {
    puts "Cannot access ARM processor."
} else {
    puts "ARM Cortex-A9 #0:"

    # 读取 PC
    if {[catch {set pc [rrd pc]} err]} {
        puts "  PC: (cannot read - processor may be running)"
    } else {
        puts "  PC: $pc"
    }

    # 尝试获取处理器状态
    if {[catch {targets -status} status]} {
        puts "  State: Unknown"
    }
}

# 检查 ARM #1
if {[catch {targets -set -filter {name =~ "*ARM*#1"}} result] == 0} {
    puts ""
    puts "ARM Cortex-A9 #1:"
    if {[catch {set pc [rrd pc]} err]} {
        puts "  PC: (cannot read)"
    } else {
        puts "  PC: $pc"
    }
}

puts ""
puts "----------------------------------------------"
puts "MEMORY MAP (Key Regions)"
puts "----------------------------------------------"

# 显示关键内存区域
puts "DDR:         0x00000000 - 0x3FFFFFFF"
puts "PL AXI GP0:  0x40000000 - 0x7FFFFFFF"
puts "PL AXI GP1:  0x80000000 - 0xBFFFFFFF"
puts "OCM:         0xFFFC0000 - 0xFFFFFFFF"

puts ""
disconnect
