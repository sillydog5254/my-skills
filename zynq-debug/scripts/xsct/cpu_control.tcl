# cpu_control.tcl - ARM CPU 控制
# 用法: xsct cpu_control.tcl [stop|run|reset|status] [cpu_id]
#
# 注意: 使用 D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat 运行

set action [expr {[llength $argv] >= 1 ? [lindex $argv 0] : "status"}]
set cpu_id [expr {[llength $argv] >= 2 ? [lindex $argv 1] : "0"}]

puts ""
puts "=============================================="
puts "         CPU CONTROL"
puts "=============================================="
puts "Action: $action"
puts "CPU:    ARM Cortex-A9 #$cpu_id"
puts ""

# 连接
puts "Connecting..."
if {[catch {connect} result]} {
    puts "ERROR: Failed to connect to hw_server."
    exit 1
}

# 选择 CPU
set target_filter "ARM*#$cpu_id"
if {[catch {targets -set -filter "name =~ \"$target_filter\""} result]} {
    puts "ERROR: Cannot find CPU #$cpu_id"
    puts "Available targets:"
    targets
    disconnect
    exit 1
}

puts "Selected: ARM Cortex-A9 #$cpu_id"
puts ""

switch -exact $action {
    stop {
        puts "Stopping CPU..."
        if {[catch {stop} result]} {
            puts "ERROR: Failed to stop CPU: $result"
        } else {
            puts "CPU stopped."

            # 显示当前状态
            puts ""
            puts "Current state:"
            if {[catch {set pc [rrd pc]} err]} {
                puts "  PC: (cannot read)"
            } else {
                puts "  PC: $pc"
            }
        }
    }

    run -
    continue -
    con {
        puts "Resuming CPU execution..."
        if {[catch {con} result]} {
            puts "ERROR: Failed to resume CPU: $result"
        } else {
            puts "CPU running."
        }
    }

    reset {
        puts "Resetting processor..."
        if {[catch {rst -processor} result]} {
            puts "ERROR: Failed to reset CPU: $result"
        } else {
            puts "Processor reset complete."
        }
    }

    status {
        puts "----------------------------------------------"
        puts "CPU STATUS"
        puts "----------------------------------------------"

        # 程序计数器
        if {[catch {set pc_val [rrd pc]} err]} {
            puts "PC:     (cannot read - CPU may be running)"
        } else {
            puts "PC:     $pc_val"
        }

        # 链接寄存器
        if {[catch {set lr_val [rrd lr]} err]} {
            puts "LR:     (cannot read)"
        } else {
            puts "LR:     $lr_val"
        }

        # 栈指针
        if {[catch {set sp_val [rrd sp]} err]} {
            puts "SP:     (cannot read)"
        } else {
            puts "SP:     $sp_val"
        }

        # CPSR
        if {[catch {set cpsr_val [rrd cpsr]} err]} {
            puts "CPSR:   (cannot read)"
        } else {
            puts "CPSR:   $cpsr_val"
        }

        puts ""
        puts "----------------------------------------------"
        puts "GENERAL PURPOSE REGISTERS"
        puts "----------------------------------------------"

        # 读取 R0-R12
        for {set i 0} {$i <= 12} {incr i} {
            if {[catch {set reg_val [rrd r$i]} err]} {
                puts "R$i:  (cannot read)"
            } else {
                puts [format "R%-2d:  %s" $i $reg_val]
            }
        }
    }

    default {
        puts "Usage: xsct cpu_control.tcl \[stop|run|reset|status\] \[cpu_id\]"
        puts ""
        puts "Commands:"
        puts "  stop   - Halt CPU execution"
        puts "  run    - Resume CPU execution"
        puts "  reset  - Reset processor"
        puts "  status - Show CPU registers (default)"
        puts ""
        puts "CPU IDs:"
        puts "  0 - ARM Cortex-A9 #0 (default)"
        puts "  1 - ARM Cortex-A9 #1"
    }
}

puts ""
disconnect
