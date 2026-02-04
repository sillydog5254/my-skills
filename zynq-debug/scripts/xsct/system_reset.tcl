# system_reset.tcl - 系统复位
# 用法: xsct system_reset.tcl [--full|--ps|--cores]
#
# 复位模式:
#   --cores (default) - 复位所有 ARM 核心
#   --ps              - 复位 PS 子系统
#   --full            - 完整系统复位 (PS + PL)
#
# 注意: 使用 D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat 运行

set mode "cores"

foreach arg $argv {
    switch -glob $arg {
        --full -
        -f {
            set mode "full"
        }
        --ps {
            set mode "ps"
        }
        --cores -
        -c {
            set mode "cores"
        }
        --help -
        -h {
            puts "Usage: xsct system_reset.tcl \[--full|--ps|--cores\]"
            puts ""
            puts "Reset modes:"
            puts "  --cores  - Reset all ARM cores (default)"
            puts "  --ps     - Reset PS subsystem"
            puts "  --full   - Full system reset (PS + PL)"
            puts ""
            puts "Note: --full mode will clear FPGA configuration!"
            exit 0
        }
    }
}

puts ""
puts "=============================================="
puts "         SYSTEM RESET"
puts "=============================================="
puts "Mode: $mode"
puts ""

# 连接
puts "Connecting..."
if {[catch {connect} result]} {
    puts "ERROR: Failed to connect to hw_server."
    exit 1
}

puts "Connected."
puts ""

switch -exact $mode {
    cores {
        puts "Resetting ARM cores..."

        # 复位 ARM #0
        if {[catch {targets -set -filter {name =~ "*ARM*#0"}} result] == 0} {
            puts "  Resetting ARM Cortex-A9 #0..."
            if {[catch {rst -processor} err]} {
                puts "  WARNING: Could not reset ARM #0: $err"
            } else {
                puts "  ARM #0 reset complete."
            }
        }

        # 复位 ARM #1
        if {[catch {targets -set -filter {name =~ "*ARM*#1"}} result] == 0} {
            puts "  Resetting ARM Cortex-A9 #1..."
            if {[catch {rst -processor} err]} {
                puts "  WARNING: Could not reset ARM #1: $err"
            } else {
                puts "  ARM #1 reset complete."
            }
        }

        puts ""
        puts "Core reset complete."
    }

    ps {
        puts "Resetting PS subsystem..."

        # 选择 ARM 目标
        if {[catch {targets -set -filter {name =~ "*ARM*#0"}} result]} {
            puts "ERROR: Cannot find ARM processor."
            disconnect
            exit 1
        }

        # 使用 rst -cores 复位整个处理器组
        if {[catch {rst -cores} err]} {
            puts "ERROR: PS reset failed: $err"
        } else {
            puts "PS reset complete."
        }
    }

    full {
        puts "WARNING: Full system reset will clear FPGA configuration!"
        puts ""
        puts "Performing full system reset..."

        # 选择 ARM 目标
        if {[catch {targets -set -filter {name =~ "*ARM*#0"}} result]} {
            puts "ERROR: Cannot find ARM processor."
            disconnect
            exit 1
        }

        # 系统复位
        if {[catch {rst -system} err]} {
            puts "ERROR: System reset failed: $err"
            puts ""
            puts "Alternative: Use SLCR reset register"
            puts "  mwr 0xF8000200 1  ; Enable SLCR write"
            puts "  mwr 0xF8000240 1  ; Trigger PS reset"
        } else {
            puts "System reset complete."
            puts ""
            puts "Note: FPGA configuration has been cleared."
            puts "You need to reprogram the FPGA before using PL peripherals."
        }
    }
}

puts ""
puts "----------------------------------------------"
puts "POST-RESET STATUS"
puts "----------------------------------------------"

# 显示当前状态
if {[catch {targets -set -filter {name =~ "*ARM*#0"}} result] == 0} {
    puts "ARM Cortex-A9 #0:"
    if {[catch {set pc [rrd pc]} err]} {
        puts "  PC: (cannot read)"
    } else {
        puts "  PC: $pc"
    }
}

puts ""
disconnect
